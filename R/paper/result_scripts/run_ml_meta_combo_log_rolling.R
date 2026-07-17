library(data.table)

source(file.path("R", "functions", "framework", "00_config.R"))
source(file.path("R", "functions", "framework", "UTILS", "helpers.R"))
source(file.path("R", "functions", "framework", "MODELS", "model_enet.R"))
source(file.path("R", "functions", "framework", "MODELS", "model_rf.R"))
source(file.path("R", "functions", "framework", "EVALUATION", "dm_test.R"))
source(file.path("R", "functions", "framework", "EVALUATION", "encompassing_test.R"))
source(file.path("R", "functions", "framework", "EVALUATION", "evaluate_forecasts.R"))

required_packages <- c("data.table", "glmnet", "ranger")
missing_packages <- required_packages[!vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)]

if (length(missing_packages) > 0L) {
  stop(
    "Install required packages before running this script: ",
    paste(missing_packages, collapse = ", ")
  )
}

config <- create_config(base_dir = getwd())

all_forecasts_path <- file.path(config$paths$results_dir, "all_forecasts.rds")
if (!file.exists(all_forecasts_path)) {
  stop("Missing base forecast file: ", all_forecasts_path)
}

all_forecasts <- as.data.table(readRDS(all_forecasts_path))
all_forecasts <- clean_forecast_table(all_forecasts)

base_forecasts <- all_forecasts[
  target_type == "log" &
    window_type == "rolling" &
    model_type != "har_ols" &
    model_type %in% c("enet", "pca", "pls", "rf", "nn")
]

har_forecasts <- all_forecasts[
  target_type == "log" &
    window_type == "rolling" &
    forecast_id == "har_ols__HAR__log__rolling"
]

if (nrow(base_forecasts) == 0L) {
  stop("No log/rolling ML base forecasts found in all_forecasts.rds.")
}

if (nrow(har_forecasts) == 0L) {
  stop("No log/rolling HAR benchmark forecast found in all_forecasts.rds.")
}

build_meta_frame <- function(forecast_dt) {
  transformed_wide <- dcast(
    forecast_dt,
    target_date ~ forecast_id,
    value.var = "forecast_transformed"
  )

  level_wide <- dcast(
    forecast_dt,
    target_date ~ forecast_id,
    value.var = "forecast_level"
  )

  actual_dt <- forecast_dt[
    ,
    .(
      origin_date = first(origin_date),
      actual_transformed = first(actual_transformed),
      actual_level = first(actual_level),
      benchmark_forecast = first(benchmark_forecast)
    ),
    by = target_date
  ]

  list(
    transformed = merge(actual_dt, transformed_wide, by = "target_date", all = FALSE),
    level = level_wide
  )
}

run_rolling_meta_combination <- function(forecast_dt,
                                         meta_model = c("enet", "rf"),
                                         config,
                                         combination_window = 120L,
                                         min_history = 36L,
                                         min_features = 2L,
                                         combination_name = NULL) {
  meta_model <- match.arg(meta_model)
  combination_name <- combination_name %||% paste0("combo_meta_", meta_model, "_ml_log_rolling")

  meta_frames <- build_meta_frame(forecast_dt)
  meta_dt <- copy(meta_frames$transformed)
  feature_cols <- setdiff(
    names(meta_dt),
    c("target_date", "origin_date", "actual_transformed", "actual_level", "benchmark_forecast")
  )

  setorder(meta_dt, target_date)
  model_config <- if (meta_model == "enet") {
    config$models$enet
  } else {
    config$models$rf
  }

  rows <- vector("list", nrow(meta_dt))
  importance_rows <- list()
  out_i <- 0L
  imp_i <- 0L

  for (i in seq_len(nrow(meta_dt))) {
    current_date <- meta_dt$target_date[i]
    history_dt <- meta_dt[target_date < current_date]

    if (nrow(history_dt) > combination_window) {
      history_dt <- tail(history_dt, combination_window)
    }

    current_row <- meta_dt[i]
    available_now <- feature_cols[vapply(
      feature_cols,
      function(col) is.finite(current_row[[col]]),
      logical(1)
    )]

    if (length(available_now) < min_features) {
      next
    }

    history_counts <- vapply(
      available_now,
      function(col) sum(is.finite(history_dt[[col]]) & is.finite(history_dt$actual_transformed)),
      integer(1)
    )
    candidate_features <- available_now[history_counts >= min_history]

    if (length(candidate_features) < min_features) {
      next
    }

    train_dt <- history_dt[
      ,
      c("actual_transformed", candidate_features),
      with = FALSE
    ]
    train_dt <- train_dt[complete.cases(train_dt)]

    if (nrow(train_dt) < min_history) {
      next
    }

    X_train <- as.matrix(train_dt[, ..candidate_features])
    y_train <- train_dt$actual_transformed
    X_test <- as.matrix(current_row[, ..candidate_features])

    fitted_model <- tryCatch(
      {
        if (meta_model == "enet") {
          fit_enet_model(
            X_train = X_train,
            y_train = y_train,
            config = model_config,
            feature_names = candidate_features
          )
        } else {
          fit_rf_model(
            X_train = X_train,
            y_train = y_train,
            config = model_config,
            feature_names = candidate_features
          )
        }
      },
      error = function(e) {
        message(
          "Skipping ", meta_model, " meta-combo for ",
          as.character(current_date), " because fitting failed: ",
          conditionMessage(e)
        )
        NULL
      }
    )

    if (is.null(fitted_model)) {
      next
    }

    pred_transformed <- if (meta_model == "enet") {
      predict_enet_model(fitted_model, X_test = X_test, config = model_config)
    } else {
      predict_rf_model(fitted_model, X_test = X_test, config = model_config)
    }

    fitted_train <- if (meta_model == "enet") {
      predict_enet_model(fitted_model, X_test = X_train, config = model_config)
    } else {
      predict_rf_model(fitted_model, X_test = X_train, config = model_config)
    }

    log_resid_var <- stats::var(y_train - fitted_train, na.rm = TRUE)
    if (!is.finite(log_resid_var) || log_resid_var < 0) {
      log_resid_var <- 0
    }

    forecast_level <- inverse_target_transform(
      pred_transformed,
      target_type = "log",
      log_resid_var = log_resid_var
    )

    forecast_floor <- get_level_forecast_floor(
      inverse_target_transform(y_train, target_type = "log", log_resid_var = 0),
      config
    )
    forecast_level <- enforce_positive_forecast(forecast_level, floor_value = forecast_floor)

    out_i <- out_i + 1L
    rows[[out_i]] <- data.table(
      origin_date = current_row$origin_date,
      target_date = current_date,
      model_type = paste0("combo_meta_", meta_model),
      feature_set = "ML_X_DATASET",
      window_type = "rolling",
      target_type = "log",
      forecast_transformed = as.numeric(pred_transformed),
      forecast_level = as.numeric(forecast_level),
      benchmark_forecast = current_row$benchmark_forecast,
      actual_transformed = current_row$actual_transformed,
      actual_level = current_row$actual_level,
      refit_every = 1L,
      initial_window = min_history,
      forecast_id = combination_name,
      combination_window = combination_window,
      meta_train_rows = nrow(train_dt),
      n_members = length(candidate_features),
      members = paste(candidate_features, collapse = " | "),
      log_resid_var = log_resid_var
    )

    importance_dt <- if (meta_model == "enet") {
      extract_enet_importance(fitted_model)
    } else {
      extract_rf_importance(fitted_model)
    }

    if (nrow(importance_dt) > 0L) {
      imp_i <- imp_i + 1L
      importance_dt[, `:=`(
        target_date = current_date,
        meta_model = meta_model,
        forecast_id = combination_name,
        combination_window = combination_window,
        meta_train_rows = nrow(train_dt)
      )]
      importance_rows[[imp_i]] <- importance_dt
    }
  }

  list(
    forecasts = rbindlist(rows[seq_len(out_i)], fill = TRUE),
    importance = rbindlist(importance_rows, fill = TRUE)
  )
}

combination_window <- config$forecasting$initial_window
min_history <- 36L

enet_combo <- run_rolling_meta_combination(
  forecast_dt = base_forecasts,
  meta_model = "enet",
  config = config,
  combination_window = combination_window,
  min_history = min_history,
  combination_name = "combo_meta_enet_ml_x_dataset_log_rolling"
)

rf_combo <- run_rolling_meta_combination(
  forecast_dt = base_forecasts,
  meta_model = "rf",
  config = config,
  combination_window = combination_window,
  min_history = min_history,
  combination_name = "combo_meta_rf_ml_x_dataset_log_rolling"
)

combo_forecasts <- rbindlist(
  list(enet_combo$forecasts, rf_combo$forecasts),
  fill = TRUE
)

combo_importance <- rbindlist(
  list(enet_combo$importance, rf_combo$importance),
  fill = TRUE
)

common_dates <- Reduce(
  intersect,
  list(
    unique(combo_forecasts$target_date),
    unique(har_forecasts$target_date)
  )
)

combo_forecasts <- combo_forecasts[target_date %in% common_dates]
base_eval_forecasts <- base_forecasts[target_date %in% common_dates]
har_eval_forecasts <- har_forecasts[target_date %in% common_dates]

standard_eval <- evaluate_forecasts(
  forecast_df = rbindlist(list(har_eval_forecasts, base_eval_forecasts, combo_forecasts), fill = TRUE),
  config = config
)$summary

har_compare <- merge(
  combo_forecasts[
    ,
    .(
      target_date,
      forecast_id,
      model_type,
      feature_set,
      target_type,
      window_type,
      actual_level,
      forecast_level,
      n_members
    )
  ],
  har_eval_forecasts[
    ,
    .(
      target_date,
      har_forecast_level = forecast_level
    )
  ],
  by = "target_date",
  all = FALSE
)

har_compare[, `:=`(
  se_combo = (actual_level - forecast_level) ^ 2,
  se_har = (actual_level - har_forecast_level) ^ 2,
  qlike_combo = qlike_loss_from_volatility(actual_level, forecast_level, eps = config$evaluation$qlike_epsilon),
  qlike_har = qlike_loss_from_volatility(actual_level, har_forecast_level, eps = config$evaluation$qlike_epsilon)
)]

har_eval <- har_compare[
  ,
  .(
    n_oos = .N,
    oos_r2_vs_har = 1 - sum(se_combo, na.rm = TRUE) / sum(se_har, na.rm = TRUE),
    qlike_combo = mean(qlike_combo, na.rm = TRUE),
    qlike_har = mean(qlike_har, na.rm = TRUE),
    qlike_gain_vs_har = mean(qlike_har, na.rm = TRUE) - mean(qlike_combo, na.rm = TRUE),
    qlike_pct_improvement_vs_har = 100 * (1 - mean(qlike_combo, na.rm = TRUE) / mean(qlike_har, na.rm = TRUE)),
    avg_n_members = mean(n_members, na.rm = TRUE),
    median_n_members = stats::median(n_members, na.rm = TRUE)
  ),
  by = .(forecast_id, model_type, feature_set, target_type, window_type)
]

out_forecasts <- file.path(config$paths$results_dir, "combo_meta_ml_x_dataset_log_rolling_forecasts.csv")
out_standard_eval <- file.path(config$paths$results_dir, "combo_meta_ml_x_dataset_log_rolling_evaluation.csv")
out_har_eval <- file.path(config$paths$results_dir, "combo_meta_ml_x_dataset_log_rolling_vs_har.csv")
out_importance <- file.path(config$paths$results_dir, "combo_meta_ml_x_dataset_log_rolling_importance.csv")

fwrite(combo_forecasts, out_forecasts)
fwrite(standard_eval, out_standard_eval)
fwrite(har_eval, out_har_eval)
fwrite(combo_importance, out_importance)

message("Saved meta-combo forecasts to: ", out_forecasts)
message("Saved standard evaluation to: ", out_standard_eval)
message("Saved HAR comparison to: ", out_har_eval)
message("Saved meta-combo importance to: ", out_importance)

cat("\nROLLING META-COMBO VS HAR\n")
print(har_eval[order(-oos_r2_vs_har)])

cat("\nSTANDARD EVALUATION TOP 12\n")
print(standard_eval[order(-oos_r2, qlike)][1:min(.N, 12L)])

cat("\nLATEST META-COMBO MEMBERS\n")
print(
  combo_forecasts[
    order(target_date),
    .SD[.N],
    by = forecast_id
  ][
    ,
    .(forecast_id, target_date, meta_train_rows, n_members, members)
  ]
)
