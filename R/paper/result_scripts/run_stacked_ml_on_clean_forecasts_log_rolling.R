library(data.table)

source(file.path("R", "functions", "framework", "00_config.R"))
source(file.path("R", "functions", "framework", "UTILS", "helpers.R"))
source(file.path("R", "functions", "framework", "MODELS", "model_enet.R"))
source(file.path("R", "functions", "framework", "MODELS", "model_pca.R"))
source(file.path("R", "functions", "framework", "MODELS", "model_pls.R"))
source(file.path("R", "functions", "framework", "MODELS", "model_rf.R"))
source(file.path("R", "functions", "framework", "MODELS", "model_nn.R"))
source(file.path("R", "functions", "framework", "MODELS", "model_registry.R"))
source(file.path("R", "functions", "framework", "EVALUATION", "dm_test.R"))
source(file.path("R", "functions", "framework", "EVALUATION", "encompassing_test.R"))
source(file.path("R", "functions", "framework", "EVALUATION", "evaluate_forecasts.R"))

required_packages <- c("data.table", "glmnet", "pls", "ranger", "nnet")
missing_packages <- required_packages[!vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)]

if (length(missing_packages) > 0L) {
  stop(
    "Install required packages before running this script: ",
    paste(missing_packages, collapse = ", ")
  )
}

config <- create_config(base_dir = getwd())

clean_forecast_path <- file.path(
  config$paths$results_dir,
  "ml_clean_feature_sets_log_rolling_forecasts.csv"
)
all_forecasts_path <- file.path(config$paths$results_dir, "all_forecasts.rds")

if (!file.exists(clean_forecast_path)) {
  stop(
    "Missing clean 5 ML x 4 dataset forecast panel: ", clean_forecast_path,
    "\nRun data/processed/model_artifacts/run_ml_clean_feature_sets_log_rolling_vs_har_eval.R first."
  )
}

if (!file.exists(all_forecasts_path)) {
  stop("Missing base forecast file: ", all_forecasts_path)
}

base_forecasts <- fread(clean_forecast_path)
base_forecasts <- clean_forecast_table(base_forecasts)

base_forecasts <- base_forecasts[
  target_type == "log" &
    window_type == "rolling" &
    model_type %in% c("enet", "pca", "pls", "rf", "nn") &
    feature_set %in% c("HAR", "O", "M", "OM")
]

all_forecasts <- as.data.table(readRDS(all_forecasts_path))
all_forecasts <- clean_forecast_table(all_forecasts)

har_benchmark <- all_forecasts[
  target_type == "log" &
    window_type == "rolling" &
    forecast_id == "har_ols__HAR__log__rolling"
]

if (nrow(base_forecasts) == 0L) {
  stop("No clean log/rolling base forecasts found.")
}

build_stacking_frame <- function(forecast_dt) {
  forecast_wide <- dcast(
    forecast_dt,
    target_date ~ forecast_id,
    value.var = "forecast_transformed"
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

  stacking_dt <- merge(actual_dt, forecast_wide, by = "target_date", all = FALSE)
  setorder(stacking_dt, target_date)
  stacking_dt[]
}

run_stacked_forecasts <- function(stacking_dt,
                                  meta_model,
                                  config,
                                  combination_window = 120L,
                                  min_history = 36L,
                                  min_features = 2L) {
  feature_cols <- setdiff(
    names(stacking_dt),
    c("target_date", "origin_date", "actual_transformed", "actual_level", "benchmark_forecast")
  )

  model_config <- get_model_config(meta_model, config)
  forecast_rows <- vector("list", nrow(stacking_dt))
  importance_rows <- list()
  out_i <- 0L
  imp_i <- 0L

  for (i in seq_len(nrow(stacking_dt))) {
    current_date <- stacking_dt$target_date[i]
    history_dt <- stacking_dt[target_date < current_date]

    if (nrow(history_dt) > combination_window) {
      history_dt <- tail(history_dt, combination_window)
    }

    current_row <- stacking_dt[i]
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
      function(col) {
        sum(is.finite(history_dt[[col]]) & is.finite(history_dt$actual_transformed))
      },
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
      fit_model(
        model_type = meta_model,
        X_train = X_train,
        y_train = y_train,
        config = model_config,
        feature_names = candidate_features
      ),
      error = function(e) {
        message(
          "Skipping stacked ", meta_model, " forecast for ",
          as.character(current_date), " because fitting failed: ",
          conditionMessage(e)
        )
        NULL
      }
    )

    if (is.null(fitted_model)) {
      next
    }

    pred_transformed <- predict_model(
      fitted_model,
      X_test = X_test,
      config = model_config
    )
    fitted_train <- predict_model(
      fitted_model,
      X_test = X_train,
      config = model_config
    )

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

    forecast_id <- paste0("stacked_", meta_model, "_on_20_clean_ml_forecasts_log_rolling")

    out_i <- out_i + 1L
    forecast_rows[[out_i]] <- data.table(
      origin_date = current_row$origin_date,
      target_date = current_date,
      model_type = paste0("stacked_", meta_model),
      feature_set = "FORECAST_STACK_20",
      window_type = "rolling",
      target_type = "log",
      forecast_transformed = as.numeric(pred_transformed),
      forecast_level = as.numeric(forecast_level),
      benchmark_forecast = current_row$benchmark_forecast,
      actual_transformed = current_row$actual_transformed,
      actual_level = current_row$actual_level,
      refit_every = 1L,
      initial_window = min_history,
      forecast_id = forecast_id,
      combination_window = combination_window,
      meta_train_rows = nrow(train_dt),
      n_members = length(candidate_features),
      members = paste(candidate_features, collapse = " | "),
      log_resid_var = log_resid_var
    )

    importance_dt <- extract_model_importance(fitted_model)
    if (nrow(importance_dt) > 0L) {
      imp_i <- imp_i + 1L
      importance_dt[, `:=`(
        target_date = current_date,
        meta_model = meta_model,
        forecast_id = forecast_id,
        combination_window = combination_window,
        meta_train_rows = nrow(train_dt)
      )]
      importance_rows[[imp_i]] <- importance_dt
    }
  }

  list(
    forecasts = rbindlist(forecast_rows[seq_len(out_i)], fill = TRUE),
    importance = rbindlist(importance_rows, fill = TRUE)
  )
}

stacking_dt <- build_stacking_frame(base_forecasts)
meta_models <- c("enet", "pca", "pls", "rf", "nn")

stacked_runs <- lapply(
  meta_models,
  function(meta_model) {
    message("Running stacked meta-model: ", meta_model)
    run_stacked_forecasts(
      stacking_dt = stacking_dt,
      meta_model = meta_model,
      config = config,
      combination_window = config$forecasting$initial_window,
      min_history = 36L,
      min_features = 2L
    )
  }
)
names(stacked_runs) <- meta_models

stacked_forecasts <- rbindlist(lapply(stacked_runs, `[[`, "forecasts"), fill = TRUE)
stacked_importance <- rbindlist(lapply(stacked_runs, `[[`, "importance"), fill = TRUE)

common_dates <- intersect(stacked_forecasts$target_date, har_benchmark$target_date)
stacked_forecasts <- stacked_forecasts[target_date %in% common_dates]
har_eval <- har_benchmark[target_date %in% common_dates]
base_eval <- base_forecasts[target_date %in% common_dates]

standard_eval <- evaluate_forecasts(
  forecast_df = rbindlist(list(har_eval, base_eval, stacked_forecasts), fill = TRUE),
  config = config
)$summary

har_compare <- merge(
  stacked_forecasts[
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
  har_eval[
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
  se_model = (actual_level - forecast_level) ^ 2,
  se_har = (actual_level - har_forecast_level) ^ 2,
  qlike_model = qlike_loss_from_volatility(actual_level, forecast_level, eps = config$evaluation$qlike_epsilon),
  qlike_har = qlike_loss_from_volatility(actual_level, har_forecast_level, eps = config$evaluation$qlike_epsilon)
)]

vs_har_eval <- har_compare[
  ,
  .(
    n_oos = .N,
    first_date = min(target_date),
    last_date = max(target_date),
    avg_n_members = mean(n_members, na.rm = TRUE),
    median_n_members = median(n_members, na.rm = TRUE),
    mse_model = mean(se_model, na.rm = TRUE),
    mse_har = mean(se_har, na.rm = TRUE),
    r2oos_vs_har = 1 - sum(se_model, na.rm = TRUE) / sum(se_har, na.rm = TRUE),
    qlike_model = mean(qlike_model, na.rm = TRUE),
    qlike_har = mean(qlike_har, na.rm = TRUE),
    qlike_gain_vs_har = mean(qlike_har, na.rm = TRUE) - mean(qlike_model, na.rm = TRUE),
    qlike_pct_improvement_vs_har = 100 * (1 - mean(qlike_model, na.rm = TRUE) / mean(qlike_har, na.rm = TRUE))
  ),
  by = .(forecast_id, model_type, feature_set, target_type, window_type)
][order(-r2oos_vs_har, qlike_model)]

forecast_output <- file.path(
  config$paths$results_dir,
  "stacked_ml_on_20_clean_forecasts_log_rolling_forecasts.csv"
)
importance_output <- file.path(
  config$paths$results_dir,
  "stacked_ml_on_20_clean_forecasts_log_rolling_importance.csv"
)
eval_output <- file.path(
  config$paths$results_dir,
  "stacked_ml_on_20_clean_forecasts_log_rolling_vs_har_evaluation.csv"
)
standard_eval_output <- file.path(
  config$paths$results_dir,
  "stacked_ml_on_20_clean_forecasts_log_rolling_standard_evaluation.csv"
)

fwrite(stacked_forecasts, forecast_output)
fwrite(stacked_importance, importance_output)
fwrite(vs_har_eval, eval_output)
fwrite(standard_eval, standard_eval_output)

message("Saved stacked forecasts to: ", forecast_output)
message("Saved stacked importance to: ", importance_output)
message("Saved stacked evaluation vs HAR to: ", eval_output)
message("Saved standard evaluation to: ", standard_eval_output)

cat("\nSTACKED ML ON 20 CLEAN FORECASTS VS HAR\n")
print(vs_har_eval)

cat("\nLATEST STACK MEMBERS\n")
print(
  stacked_forecasts[
    order(target_date),
    .SD[.N],
    by = forecast_id
  ][
    ,
    .(forecast_id, target_date, meta_train_rows, n_members, members)
  ]
)
