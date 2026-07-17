library(data.table)

source(file.path("R", "functions", "framework", "00_config.R"))
source(file.path("R", "functions", "framework", "UTILS", "helpers.R"))
source(file.path("R", "functions", "framework", "01_load_data.R"))
source(file.path("R", "functions", "framework", "FEATURES", "feature_sets.R"))
source(file.path("R", "functions", "framework", "MODELS", "model_enet.R"))
source(file.path("R", "functions", "framework", "MODELS", "model_pca.R"))
source(file.path("R", "functions", "framework", "MODELS", "model_pls.R"))
source(file.path("R", "functions", "framework", "MODELS", "model_rf.R"))
source(file.path("R", "functions", "framework", "MODELS", "model_nn.R"))
source(file.path("R", "functions", "framework", "MODELS", "model_registry.R"))
source(file.path("R", "functions", "framework", "FORECASTS", "run_forecast.R"))

required_packages <- c("data.table", "glmnet", "pls", "ranger", "nnet")
missing_packages <- required_packages[!vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)]

if (length(missing_packages) > 0L) {
  stop(
    "Install required packages before running this script: ",
    paste(missing_packages, collapse = ", ")
  )
}

config <- create_config(base_dir = getwd())
config$paths$output_dir <- config$paths$robustness_output_dir
master_data <- load_master_data(config)

all_forecasts <- as.data.table(
  readRDS(file.path(config$paths$results_dir, "all_forecasts.rds"))
)
all_forecasts <- clean_forecast_table(all_forecasts)

existing_har_ml <- all_forecasts[
  target_type == "log" &
    window_type == "rolling" &
    model_type %in% c("enet", "pca", "pls", "rf", "nn") &
    feature_set == "HAR"
]

spec_grid <- CJ(
  model_type = c("enet", "pca", "pls", "rf", "nn"),
  feature_set = c("O", "M", "OM"),
  sorted = FALSE
)

forecast_runs <- vector("list", nrow(spec_grid))

for (i in seq_len(nrow(spec_grid))) {
  spec <- spec_grid[i]
  message(
    "[", i, "/", nrow(spec_grid), "] Running ",
    spec$model_type, " | ", spec$feature_set, " | log | rolling"
  )

  forecast_runs[[i]] <- run_forecast(
    data = master_data,
    model_type = spec$model_type,
    feature_set = spec$feature_set,
    window_type = "rolling",
    initial_window = config$forecasting$initial_window,
    refit_every = config$forecasting$refit_every,
    target_type = "log",
    config = config
  )
}

new_forecasts <- rbindlist(lapply(forecast_runs, `[[`, "forecasts"), fill = TRUE)
new_forecasts <- clean_forecast_table(new_forecasts)

clean_feature_forecasts <- rbindlist(
  list(existing_har_ml, new_forecasts),
  fill = TRUE
)

har_benchmark <- all_forecasts[
  target_type == "log" &
    window_type == "rolling" &
    forecast_id == "har_ols__HAR__log__rolling",
  .(
    target_date,
    har_forecast_level = forecast_level
  )
]

comparison_dt <- merge(
  clean_feature_forecasts,
  har_benchmark,
  by = "target_date",
  all = FALSE
)

comparison_dt <- comparison_dt[
  is.finite(actual_level) &
    is.finite(forecast_level) &
    is.finite(har_forecast_level)
]

comparison_dt[, `:=`(
  se_model = (actual_level - forecast_level) ^ 2,
  se_har = (actual_level - har_forecast_level) ^ 2,
  qlike_model = qlike_loss_from_volatility(
    actual_level,
    forecast_level,
    eps = config$evaluation$qlike_epsilon
  ),
  qlike_har = qlike_loss_from_volatility(
    actual_level,
    har_forecast_level,
    eps = config$evaluation$qlike_epsilon
  )
)]

evaluation_dt <- comparison_dt[
  ,
  .(
    n_oos = .N,
    first_date = min(target_date),
    last_date = max(target_date),
    mse_model = mean(se_model),
    mse_har = mean(se_har),
    r2oos_vs_har = 1 - sum(se_model) / sum(se_har),
    qlike_model = mean(qlike_model),
    qlike_har = mean(qlike_har),
    qlike_gain_vs_har = mean(qlike_har) - mean(qlike_model),
    qlike_pct_improvement_vs_har = 100 * (1 - mean(qlike_model) / mean(qlike_har))
  ),
  by = .(forecast_id, model_type, feature_set)
][order(feature_set, model_type)]

ranked_dt <- copy(evaluation_dt)[order(-r2oos_vs_har, qlike_model)]

forecast_output <- file.path(
  config$paths$results_dir,
  "ml_clean_feature_sets_log_rolling_forecasts.csv"
)
eval_output <- file.path(
  config$paths$results_dir,
  "ml_clean_feature_sets_log_rolling_vs_har_evaluation.csv"
)

fwrite(clean_feature_forecasts, forecast_output)
fwrite(ranked_dt, eval_output)

message("Saved clean feature-set forecasts to: ", forecast_output)
message("Saved clean feature-set evaluation vs HAR to: ", eval_output)
print(ranked_dt)
