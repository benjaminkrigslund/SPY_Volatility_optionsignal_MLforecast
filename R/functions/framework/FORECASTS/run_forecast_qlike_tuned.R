build_qlike_candidate_grid <- function(model_type, base_config, n_features) {
  model_type <- match.arg(model_type, c("har_ols", "enet", "pca", "pls", "rf", "nn"))

  if (model_type == "har_ols") {
    return(list(base_config))
  }

  if (model_type == "enet") {
    alphas <- c(0.1, 0.5, 0.9)
    return(lapply(alphas, function(alpha) utils::modifyList(base_config, list(alpha = alpha))))
  }

  if (model_type == "pca") {
    explained_vals <- c(0.5, 0.7, 0.9)
    return(lapply(explained_vals, function(ev) utils::modifyList(base_config, list(explained_variance = ev))))
  }

  if (model_type == "pls") {
    max_components_grid <- unique(pmax(1L, pmin(n_features, c(3L, 6L, 12L))))
    return(lapply(max_components_grid, function(k) utils::modifyList(base_config, list(max_components = k))))
  }

  if (model_type == "rf") {
    mtry_grid <- unique(pmax(1L, pmin(n_features, c(floor(sqrt(n_features)), floor(n_features / 3), floor(n_features / 2)))))
    node_grid <- c(5L, 10L)
    candidates <- vector("list", length(mtry_grid) * length(node_grid))
    idx <- 0L
    for (mtry in mtry_grid) {
      for (node in node_grid) {
        idx <- idx + 1L
        candidates[[idx]] <- utils::modifyList(base_config, list(mtry = mtry, min_node_size = node))
      }
    }
    return(candidates)
  }

  if (model_type == "nn") {
    size_grid <- c(3L, 5L, 8L)
    decay_grid <- c(0.001, 0.01, 0.1)
    candidates <- vector("list", length(size_grid) * length(decay_grid))
    idx <- 0L
    for (size in size_grid) {
      for (decay in decay_grid) {
        idx <- idx + 1L
        candidates[[idx]] <- utils::modifyList(base_config, list(size = size, decay = decay))
      }
    }
    return(candidates)
  }

  list(base_config)
}

get_validation_size <- function(n_train, min_validation = 24L, validation_fraction = 0.2) {
  val_n <- max(min_validation, floor(n_train * validation_fraction))
  min(val_n, n_train - 5L)
}

score_candidate_by_qlike <- function(model_type,
                                     candidate_config,
                                     train_dt,
                                     predictor_cols,
                                     target_type,
                                     config) {
  n_train <- nrow(train_dt)
  val_n <- get_validation_size(n_train)

  if (is.na(val_n) || val_n < 5L || n_train - val_n < get_min_train_rows(model_type)) {
    return(list(score = Inf, fitted_model = NULL))
  }

  subtrain_dt <- train_dt[seq_len(n_train - val_n)]
  val_dt <- train_dt[seq.int(n_train - val_n + 1L, n_train)]

  X_subtrain <- as.matrix(subtrain_dt[, ..predictor_cols])
  y_subtrain <- subtrain_dt[["target_transformed"]]

  fitted_model <- tryCatch(
    fit_model(
      model_type = model_type,
      X_train = X_subtrain,
      y_train = y_subtrain,
      config = candidate_config,
      feature_names = predictor_cols
    ),
    error = function(e) NULL
  )

  if (is.null(fitted_model)) {
    return(list(score = Inf, fitted_model = NULL))
  }

  if (target_type == "log") {
    train_pred <- predict_model(fitted_model, X_test = X_subtrain, config = candidate_config)
    log_resid <- y_subtrain - train_pred
    log_resid_var <- stats::var(log_resid, na.rm = TRUE)
    if (is.na(log_resid_var) || log_resid_var < 0) {
      log_resid_var <- 0
    }
  } else {
    log_resid_var <- 0
  }

  X_val <- as.matrix(val_dt[, ..predictor_cols])
  pred_transformed <- predict_model(fitted_model, X_test = X_val, config = candidate_config)
  pred_level <- inverse_target_transform(pred_transformed, target_type = target_type, log_resid_var = log_resid_var)
  pred_level <- enforce_positive_forecast(pred_level, floor_value = get_level_forecast_floor(subtrain_dt$target_level, config))

  score <- mean(
    qlike_loss_from_volatility(
      actual_vol = val_dt$target_level,
      forecast_vol = pred_level,
      eps = config$evaluation$qlike_epsilon
    ),
    na.rm = TRUE
  )

  list(score = score, fitted_model = fitted_model)
}

select_qlike_config <- function(model_type,
                                train_dt,
                                predictor_cols,
                                target_type,
                                config) {
  base_config <- get_model_config(model_type, config)
  candidate_grid <- build_qlike_candidate_grid(model_type, base_config, n_features = length(predictor_cols))

  scores <- lapply(candidate_grid, function(candidate) {
    score_candidate_by_qlike(
      model_type = model_type,
      candidate_config = candidate,
      train_dt = train_dt,
      predictor_cols = predictor_cols,
      target_type = target_type,
      config = config
    )
  })

  score_vals <- vapply(scores, function(x) x$score, numeric(1))
  best_idx <- which.min(score_vals)

  list(
    config = candidate_grid[[best_idx]],
    validation_qlike = score_vals[[best_idx]]
  )
}

run_forecast_qlike_tuned <- function(data,
                                     model_type,
                                     feature_set,
                                     window_type = c("rolling", "expanding"),
                                     initial_window,
                                     refit_every,
                                     target_type = c("level", "log"),
                                     config) {
  window_type <- match.arg(window_type)
  target_type <- match.arg(target_type)

  feature_data <- get_feature_set(data, feature_set = feature_set, config = config)
  model_data <- make_model_frame(feature_data, config = config, target_type = target_type)

  predictor_cols <- attr(model_data, "predictor_cols")
  if (length(predictor_cols) == 0L) {
    stop("No predictor columns were found for feature set ", feature_set, ".")
  }

  n_obs <- nrow(model_data)
  first_oos <- initial_window + 1L

  if (n_obs < first_oos) {
    stop("Not enough observations after target alignment for ", model_type, " / ", feature_set, ".")
  }

  cached_model <- NULL
  cached_model_config <- NULL
  min_train_rows <- get_min_train_rows(model_type)
  forecast_rows <- vector("list", length = n_obs - initial_window)

  for (i in seq.int(first_oos, n_obs)) {
    if (window_type == "rolling") {
      train_start <- i - initial_window
    } else {
      train_start <- 1L
    }
    train_end <- i - 1L
    train_idx <- seq.int(train_start, train_end)

    train_dt <- model_data[train_idx]
    train_cc <- stats::complete.cases(train_dt[, c("target_transformed", predictor_cols), with = FALSE])
    train_dt <- train_dt[train_cc]

    if (nrow(train_dt) < min_train_rows) {
      next
    }

    if (is.null(cached_model) || ((i - first_oos) %% refit_every == 0L)) {
      qlike_selection <- select_qlike_config(
        model_type = model_type,
        train_dt = train_dt,
        predictor_cols = predictor_cols,
        target_type = target_type,
        config = config
      )
      cached_model_config <- qlike_selection$config

      X_train <- as.matrix(train_dt[, ..predictor_cols])
      y_train <- train_dt[["target_transformed"]]

      cached_model <- tryCatch(
        fit_model(
          model_type = model_type,
          X_train = X_train,
          y_train = y_train,
          config = cached_model_config,
          feature_names = predictor_cols
        ),
        error = function(e) NULL
      )

      if (is.null(cached_model)) {
        next
      }

      if (target_type == "log") {
        train_pred <- predict_model(cached_model, X_test = X_train, config = cached_model_config)
        log_resid <- y_train - train_pred
        cached_model$log_resid_var <- stats::var(log_resid, na.rm = TRUE)
        if (is.na(cached_model$log_resid_var) || cached_model$log_resid_var < 0) {
          cached_model$log_resid_var <- 0
        }
      } else {
        cached_model$log_resid_var <- 0
      }

      cached_model$validation_qlike <- qlike_selection$validation_qlike
    }

    test_dt <- model_data[i]
    if (!all(stats::complete.cases(test_dt[, ..predictor_cols]))) {
      next
    }

    X_test <- as.matrix(test_dt[, ..predictor_cols])
    pred_transformed <- predict_model(cached_model, X_test = X_test, config = cached_model_config)
    train_actual_level <- train_dt$target_level
    forecast_floor <- get_level_forecast_floor(train_actual_level, config)
    pred_level <- inverse_target_transform(
      pred_transformed,
      target_type = target_type,
      log_resid_var = cached_model$log_resid_var %||% 0
    )
    pred_level <- enforce_positive_forecast(pred_level, floor_value = forecast_floor)

    benchmark_forecast <- enforce_positive_forecast(mean(train_actual_level, na.rm = TRUE), floor_value = forecast_floor)

    forecast_rows[[i - initial_window]] <- data.table::data.table(
      origin_date = test_dt$date,
      target_date = test_dt$target_date,
      model_type = model_type,
      feature_set = feature_set,
      window_type = window_type,
      target_type = target_type,
      forecast_transformed = pred_transformed,
      forecast_level = pred_level,
      benchmark_forecast = benchmark_forecast,
      actual_transformed = test_dt$target_transformed,
      actual_level = test_dt$target_level,
      refit_every = refit_every,
      initial_window = initial_window,
      tuning_objective = "validation_qlike",
      validation_qlike = cached_model$validation_qlike %||% NA_real_
    )
  }

  forecast_dt <- data.table::rbindlist(forecast_rows, fill = TRUE)
  if (nrow(forecast_dt) > 0L) {
    forecast_dt[, forecast_id := build_forecast_id(model_type, feature_set, target_type, window_type)]
    forecast_dt <- clean_forecast_table(forecast_dt)
  } else {
    forecast_dt <- data.table::data.table()
  }

  list(
    forecasts = forecast_dt[],
    meta = list(
      model_type = model_type,
      feature_set = feature_set,
      window_type = window_type,
      target_type = target_type,
      initial_window = initial_window,
      refit_every = refit_every,
      tuning_objective = "validation_qlike"
    )
  )
}

