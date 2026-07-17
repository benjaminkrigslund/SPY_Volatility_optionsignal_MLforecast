library(data.table)

source(file.path("R", "functions", "framework", "00_config.R"))
source(file.path("R", "functions", "framework", "UTILS", "helpers.R"))

config <- create_config(base_dir = getwd())
config$paths$output_dir <- config$paths$robustness_output_dir

all_forecasts <- as.data.table(
  readRDS(file.path(config$paths$results_dir, "all_forecasts.rds"))
)
all_forecasts <- clean_forecast_table(all_forecasts)

clean_forecasts <- fread(
  file.path(config$paths$results_dir, "ml_clean_feature_sets_log_rolling_forecasts.csv")
)
clean_forecasts <- clean_forecast_table(clean_forecasts)

equal_weight_forecasts <- fread(
  file.path(config$paths$results_dir, "equal_weight_extended_ml_combos_log_rolling_forecasts.csv")
)
equal_weight_forecasts <- clean_forecast_table(equal_weight_forecasts)

ml_methods <- c("enet", "pca", "pls", "rf", "nn")
base_feature_sets <- c("HAR", "O", "M", "OM")
har_augmented_feature_sets <- c("HAR_O", "HAR_M", "HAR_OM")

individual_forecasts <- rbindlist(
  list(
    clean_forecasts[
      target_type == "log" &
        window_type == "rolling" &
        model_type %in% ml_methods &
        feature_set %in% base_feature_sets
    ],
    all_forecasts[
      target_type == "log" &
        window_type == "rolling" &
        model_type %in% ml_methods &
        feature_set %in% har_augmented_feature_sets
    ]
  ),
  fill = TRUE
)
individual_forecasts <- unique(individual_forecasts, by = c("target_date", "forecast_id"))

har_benchmark <- all_forecasts[
  target_type == "log" &
    window_type == "rolling" &
    forecast_id == "har_ols__HAR__log__rolling",
  .(
    target_date,
    har_forecast_level = forecast_level
  )
]

evaluate_vs_har <- function(forecast_dt, type_label) {
  comparison_dt <- merge(
    forecast_dt,
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

  comparison_dt[
    ,
    .(
      type = type_label,
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
    by = .(forecast_id, model_type, feature_set, target_type, window_type)
  ]
}

combined_eval <- rbindlist(
  list(
    evaluate_vs_har(individual_forecasts, "individual_35"),
    evaluate_vs_har(equal_weight_forecasts, "equal_weight_combo")
  ),
  fill = TRUE
)[order(-r2oos_vs_har, qlike_model)]

combined_eval[, rank := .I]
setcolorder(combined_eval, c("rank", setdiff(names(combined_eval), "rank")))

output_path <- file.path(
  config$paths$results_dir,
  "individual_35_and_equal_weight_extended_log_rolling_vs_har.csv"
)

fwrite(combined_eval, output_path)

message("Saved individual 35 + equal-weight combo evaluation to: ", output_path)
print(
  combined_eval[
    ,
    .(
      rank,
      type,
      forecast_id,
      model_type,
      feature_set,
      n_oos,
      r2oos_vs_har,
      qlike_gain_vs_har,
      qlike_model
    )
  ]
)
