library(data.table)

source(file.path("R", "functions", "framework", "00_config.R"))
source(file.path("R", "functions", "framework", "UTILS", "helpers.R"))

config <- create_config(base_dir = getwd())

all_forecasts <- as.data.table(
  readRDS(file.path(config$paths$results_dir, "all_forecasts.rds"))
)
all_forecasts <- clean_forecast_table(all_forecasts)

ml_forecasts <- all_forecasts[
  target_type == "log" &
    window_type == "rolling" &
    model_type %in% c("enet", "pca", "pls", "rf", "nn")
]

har_forecasts <- all_forecasts[
  target_type == "log" &
    window_type == "rolling" &
    forecast_id == "har_ols__HAR__log__rolling",
  .(
    target_date,
    har_forecast_level = forecast_level
  )
]

comparison_dt <- merge(
  ml_forecasts,
  har_forecasts,
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
][order(-r2oos_vs_har, qlike_model)]

output_path <- file.path(
  config$paths$results_dir,
  "ml_x_dataset_log_rolling_vs_har_evaluation.csv"
)

fwrite(evaluation_dt, output_path)

message("Saved ML x dataset rolling-log evaluation vs HAR to: ", output_path)
print(evaluation_dt)
