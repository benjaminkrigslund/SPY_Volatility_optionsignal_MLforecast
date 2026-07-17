run_forecast <- function(data,
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
  feature_blocks <- attr(feature_data, "feature_blocks")
  model_data <- make_model_frame(feature_data, config = config, target_type = target_type)

  predictor_cols <- attr(model_data, "predictor_cols")
  if (length(predictor_cols) == 0L) {
    stop("No predictor columns were found for feature set ", feature_set, ".")
  }

  n_obs <- nrow(model_data)
  first_oos <- initial_window + 1L

  if (n_obs < first_oos) {
    stop(
      "Not enough observations after target alignment. ",
      "Need more than ", initial_window, " usable monthly rows, got ", n_obs, "."
    )
  }

  model_config <- get_model_config(model_type, config)
  min_train_rows <- get_min_train_rows(model_type)
  cached_model <- NULL
  forecast_rows <- vector("list", length = n_obs - initial_window)
  importance_rows <- vector("list", length = n_obs - initial_window)
  importance_counter <- 0L

  for (i in seq.int(first_oos, n_obs)) {
    if (window_type == "rolling") {
      train_start <- i - initial_window
    } else {
      train_start <- 1L
    }
    train_end <- i - 1L
    train_idx <- seq.int(train_start, train_end)

    if (is.null(cached_model) || ((i - first_oos) %% refit_every == 0L)) {
      train_dt <- model_data[train_idx]
      train_cc <- stats::complete.cases(train_dt[, c("target_transformed", predictor_cols), with = FALSE])
      train_dt <- train_dt[train_cc]

      if (nrow(train_dt) < min_train_rows) {
        cached_model <- NULL
        next
      }

      X_train <- as.matrix(train_dt[, ..predictor_cols])
      y_train <- train_dt[["target_transformed"]]

      cached_model <- tryCatch(
        fit_model(
          model_type = model_type,
          X_train = X_train,
          y_train = y_train,
          config = model_config,
          feature_names = predictor_cols,
          feature_blocks = feature_blocks
        ),
        error = function(e) {
          message(
            "Skipping refit for ", model_type, " / ", feature_set, " / ",
            target_type, " / ", window_type, " at ", as.character(model_data$date[i]),
            " because training failed: ", conditionMessage(e)
          )
          NULL
        }
      )

      if (is.null(cached_model)) {
        next
      }

      if (target_type == "log") {
        train_pred_transformed <- predict_model(
          cached_model,
          X_test = X_train,
          config = model_config
        )
        log_resid <- y_train - train_pred_transformed
        cached_model$log_resid_var <- stats::var(log_resid, na.rm = TRUE)
        if (is.na(cached_model$log_resid_var) || cached_model$log_resid_var < 0) {
          cached_model$log_resid_var <- 0
        }
      } else {
        cached_model$log_resid_var <- 0
      }

      importance_dt <- extract_model_importance(cached_model)
      if (nrow(importance_dt) > 0L) {
        importance_counter <- importance_counter + 1L
        importance_dt[, `:=`(
          model_type = model_type,
          feature_set = feature_set,
          target_type = target_type,
          window_type = window_type,
          refit_origin = model_data$date[i],
          train_end_date = model_data$date[train_end]
        )]
        importance_rows[[importance_counter]] <- importance_dt
      }
    }

    test_dt <- model_data[i]
    test_cc <- stats::complete.cases(test_dt[, ..predictor_cols])
    if (!all(test_cc)) {
      next
    }

    if (is.null(cached_model)) {
      next
    }

    X_test <- as.matrix(test_dt[, ..predictor_cols])
    pred_transformed <- predict_model(cached_model, X_test = X_test, config = model_config)
    pred_level <- inverse_target_transform(
      pred_transformed,
      target_type = target_type,
      log_resid_var = cached_model$log_resid_var %||% 0
    )
    train_actual_level <- model_data[train_idx][["target_level"]]
    forecast_floor <- get_level_forecast_floor(train_actual_level, config)
    pred_level <- enforce_positive_forecast(
      pred_level,
      floor_value = forecast_floor
    )

    benchmark_forecast <- mean(train_actual_level, na.rm = TRUE)
    benchmark_forecast <- enforce_positive_forecast(
      benchmark_forecast,
      floor_value = forecast_floor
    )

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
      initial_window = initial_window
    )
  }

  forecast_dt <- data.table::rbindlist(forecast_rows, fill = TRUE)
  importance_dt <- data.table::rbindlist(importance_rows[seq_len(importance_counter)], fill = TRUE)

  if (nrow(forecast_dt) > 0L) {
    forecast_dt[, forecast_id := build_forecast_id(model_type, feature_set, target_type, window_type)]
    forecast_dt <- clean_forecast_table(forecast_dt)
  } else {
    forecast_dt <- data.table::data.table()
  }

  list(
    forecasts = forecast_dt[],
    importance = importance_dt[],
    meta = list(
      model_type = model_type,
      feature_set = feature_set,
      window_type = window_type,
      target_type = target_type,
      initial_window = initial_window,
      refit_every = refit_every
    )
  )
}
