library(data.table)

source(file.path("R", "functions", "framework", "00_config.R"))
source(file.path("R", "functions", "framework", "UTILS", "helpers.R"))
source(file.path("R", "functions", "framework", "FORECASTS", "combine_forecasts.R"))
source(file.path("R", "functions", "framework", "EVALUATION", "dm_test.R"))
source(file.path("R", "functions", "framework", "EVALUATION", "encompassing_test.R"))
source(file.path("R", "functions", "framework", "EVALUATION", "evaluate_forecasts.R"))

config <- create_config(base_dir = getwd())

clean_forecast_path <- file.path(
  config$paths$results_dir,
  "ml_clean_feature_sets_log_rolling_forecasts.csv"
)

all_forecasts_path <- file.path(config$paths$results_dir, "all_forecasts.rds")

if (!file.exists(clean_forecast_path)) {
  stop(
    "Missing clean ML forecast panel: ", clean_forecast_path,
    "\nRun data/processed/model_artifacts/run_ml_clean_feature_sets_log_rolling_vs_har_eval.R first."
  )
}

if (!file.exists(all_forecasts_path)) {
  stop("Missing base forecast file: ", all_forecasts_path)
}

clean_forecasts <- fread(clean_forecast_path)
clean_forecasts <- clean_forecast_table(clean_forecasts)

all_forecasts <- as.data.table(readRDS(all_forecasts_path))
all_forecasts <- clean_forecast_table(all_forecasts)

har_benchmark <- all_forecasts[
  target_type == "log" &
    window_type == "rolling" &
    forecast_id == "har_ols__HAR__log__rolling"
]

ml_methods <- c("enet", "pca", "pls", "rf", "nn")
feature_sets <- c("HAR", "O", "M", "OM")

clean_forecasts <- clean_forecasts[
  target_type == "log" &
    window_type == "rolling" &
    model_type %in% ml_methods &
    feature_set %in% feature_sets
]

if (nrow(clean_forecasts) == 0L) {
  stop("No clean ML forecasts found for log/rolling HAR, O, M, OM feature sets.")
}

make_equal_weight_combo <- function(forecast_dt, selected_ids, combo_name, combo_group, combo_family) {
  combo_dt <- combine_forecasts(
    forecast_df = forecast_dt,
    method = "equal_weight",
    selected_models = selected_ids,
    combination_name = combo_name
  )

  combo_dt[, `:=`(
    model_type = combo_name,
    feature_set = combo_family,
    combo_group = combo_group,
    combo_family = combo_family,
    n_members = length(selected_ids),
    members = paste(sort(selected_ids), collapse = " | ")
  )]

  combo_dt[]
}

combo_specs <- list()

for (method in ml_methods) {
  member_ids <- clean_forecasts[model_type == method, sort(unique(forecast_id))]
  combo_specs[[paste0("combo_equal_weight_", method, "_across_datasets_log_rolling")]] <- list(
    ids = member_ids,
    group = "within_ml_method_across_datasets",
    family = method
  )
}

for (feature_set_value in feature_sets) {
  member_ids <- clean_forecasts[feature_set == feature_set_value, sort(unique(forecast_id))]
  combo_specs[[paste0("combo_equal_weight_", tolower(feature_set_value), "_across_ml_log_rolling")]] <- list(
    ids = member_ids,
    group = "within_dataset_across_ml_methods",
    family = feature_set_value
  )
}

combo_specs[["combo_equal_weight_all_ml_x_dataset_log_rolling"]] <- list(
  ids = clean_forecasts[, sort(unique(forecast_id))],
  group = "all_ml_x_dataset",
  family = "ALL"
)

combo_forecasts <- rbindlist(
  lapply(
    names(combo_specs),
    function(combo_name) {
      spec <- combo_specs[[combo_name]]
      if (length(spec$ids) == 0L) {
        return(data.table())
      }

      make_equal_weight_combo(
        forecast_dt = clean_forecasts,
        selected_ids = spec$ids,
        combo_name = combo_name,
        combo_group = spec$group,
        combo_family = spec$family
      )
    }
  ),
  fill = TRUE
)

common_dates <- intersect(combo_forecasts$target_date, har_benchmark$target_date)
combo_forecasts <- combo_forecasts[target_date %in% common_dates]
har_benchmark <- har_benchmark[target_date %in% common_dates]
individual_forecasts <- clean_forecasts[target_date %in% common_dates]

standard_eval <- evaluate_forecasts(
  forecast_df = rbindlist(list(individual_forecasts, combo_forecasts), fill = TRUE),
  config = config
)$summary

combo_har_compare <- merge(
  combo_forecasts[
    ,
    .(
      target_date,
      forecast_id,
      model_type,
      feature_set,
      target_type,
      window_type,
      combo_group,
      combo_family,
      n_members,
      members,
      actual_level,
      forecast_level
    )
  ],
  har_benchmark[
    ,
    .(
      target_date,
      har_forecast_level = forecast_level
    )
  ],
  by = "target_date",
  all = FALSE
)

combo_har_compare[, `:=`(
  se_combo = (actual_level - forecast_level) ^ 2,
  se_har = (actual_level - har_forecast_level) ^ 2,
  qlike_combo = qlike_loss_from_volatility(
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

combo_vs_har_eval <- combo_har_compare[
  ,
  .(
    n_oos = .N,
    first_date = min(target_date),
    last_date = max(target_date),
    n_members = first(n_members),
    members = first(members),
    mse_combo = mean(se_combo),
    mse_har = mean(se_har),
    r2oos_vs_har = 1 - sum(se_combo) / sum(se_har),
    qlike_combo = mean(qlike_combo),
    qlike_har = mean(qlike_har),
    qlike_gain_vs_har = mean(qlike_har) - mean(qlike_combo),
    qlike_pct_improvement_vs_har = 100 * (1 - mean(qlike_combo) / mean(qlike_har))
  ),
  by = .(forecast_id, combo_group, combo_family, target_type, window_type)
][order(-r2oos_vs_har, qlike_combo)]

combo_forecast_output <- file.path(
  config$paths$results_dir,
  "equal_weight_clean_ml_combos_log_rolling_forecasts.csv"
)
combo_eval_output <- file.path(
  config$paths$results_dir,
  "equal_weight_clean_ml_combos_log_rolling_vs_har_evaluation.csv"
)
standard_eval_output <- file.path(
  config$paths$results_dir,
  "equal_weight_clean_ml_combos_log_rolling_standard_evaluation.csv"
)

fwrite(combo_forecasts, combo_forecast_output)
fwrite(combo_vs_har_eval, combo_eval_output)
fwrite(standard_eval, standard_eval_output)

message("Saved equal-weight combo forecasts to: ", combo_forecast_output)
message("Saved equal-weight combo evaluation vs HAR to: ", combo_eval_output)
message("Saved standard evaluation to: ", standard_eval_output)

cat("\nEQUAL-WEIGHT COMBINATIONS VS HAR\n")
print(combo_vs_har_eval)
