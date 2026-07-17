source(file.path("R", "functions", "framework", "00_config.R"))
source(file.path("R", "functions", "framework", "UTILS", "helpers.R"))
source(file.path("R", "functions", "framework", "01_load_data.R"))
source(file.path("R", "functions", "framework", "FEATURES", "feature_sets.R"))
source(file.path("R", "functions", "framework", "MODELS", "model_rf.R"))
source(file.path("R", "functions", "framework", "MODELS", "model_registry.R"))
source(file.path("R", "functions", "framework", "FORECASTS", "run_forecast.R"))
source(file.path("R", "functions", "framework", "FORECASTS", "combine_forecasts.R"))
source(file.path("R", "functions", "framework", "EVALUATION", "dm_test.R"))
source(file.path("R", "functions", "framework", "EVALUATION", "encompassing_test.R"))
source(file.path("R", "functions", "framework", "EVALUATION", "evaluate_forecasts.R"))

required_packages <- c("data.table", "ranger")
missing_packages <- required_packages[!vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)]

if (length(missing_packages) > 0L) {
  stop(
    "Install required packages before running this script: ",
    paste(missing_packages, collapse = ", ")
  )
}

config <- create_config(base_dir = getwd())
master_data <- load_master_data(config)

feature_sets <- c("HAR", "O", "M")

forecast_runs <- lapply(
  feature_sets,
  function(feature_set) {
    message("Running rf | ", feature_set, " | log | rolling")
    run_forecast(
      data = master_data,
      model_type = "rf",
      feature_set = feature_set,
      window_type = "rolling",
      initial_window = config$forecasting$initial_window,
      refit_every = config$forecasting$refit_every,
      target_type = "log",
      config = config
    )
  }
)

names(forecast_runs) <- feature_sets

all_forecasts <- data.table::rbindlist(lapply(forecast_runs, `[[`, "forecasts"), fill = TRUE)
all_forecasts <- clean_forecast_table(all_forecasts)

common_targets <- Reduce(
  intersect,
  lapply(
    split(all_forecasts, by = "feature_set", keep.by = FALSE),
    function(dt) unique(dt$target_date)
  )
)

if (length(common_targets) == 0L) {
  stop("No common out-of-sample target dates across HAR, O, and M RF forecasts.")
}

aligned_forecasts <- all_forecasts[target_date %in% common_targets]

individual_eval <- evaluate_forecasts(forecast_df = aligned_forecasts, config = config)$summary

combination_specs <- list(
  combo_rf_log_rolling_har_o = c("rf__HAR__log__rolling", "rf__O__log__rolling"),
  combo_rf_log_rolling_har_m = c("rf__HAR__log__rolling", "rf__M__log__rolling"),
  combo_rf_log_rolling_o_m = c("rf__O__log__rolling", "rf__M__log__rolling"),
  combo_rf_log_rolling_har_o_m = c("rf__HAR__log__rolling", "rf__O__log__rolling", "rf__M__log__rolling")
)

combination_forecasts <- data.table::rbindlist(
  lapply(
    names(combination_specs),
    function(combo_name) {
      combine_forecasts(
        forecast_df = aligned_forecasts,
        method = "equal_weight",
        selected_models = combination_specs[[combo_name]],
        combination_name = combo_name
      )
    }
  ),
  fill = TRUE
)

combination_eval <- evaluate_forecasts(forecast_df = combination_forecasts, config = config)$summary

final_eval <- data.table::rbindlist(
  list(individual_eval, combination_eval),
  fill = TRUE
)

final_eval[, specification := data.table::fcase(
  forecast_id == "rf__HAR__log__rolling", "RF: HAR",
  forecast_id == "rf__O__log__rolling", "RF: options-only",
  forecast_id == "rf__M__log__rolling", "RF: macro-only",
  forecast_id == "combo_rf_log_rolling_har_o", "Equal weight: HAR + options",
  forecast_id == "combo_rf_log_rolling_har_m", "Equal weight: HAR + macro",
  forecast_id == "combo_rf_log_rolling_o_m", "Equal weight: options + macro",
  forecast_id == "combo_rf_log_rolling_har_o_m", "Equal weight: HAR + options + macro",
  default = forecast_id
)]

data.table::setcolorder(
  final_eval,
  c(
    "specification", "forecast_id", "model_type", "feature_set", "target_type", "window_type",
    "n_oos", "mse_model", "mse_benchmark", "oos_r2", "qlike", "qlike_benchmark",
    "dm_se_stat", "dm_se_p", "dm_qlike_stat", "dm_qlike_p",
    "encompassing_coef", "encompassing_stat", "encompassing_p"
  )
)

data.table::setorder(final_eval, -oos_r2, qlike)

forecast_output <- file.path(config$paths$results_dir, "rf_log_rolling_har_o_m_forecasts.csv")
eval_output <- file.path(config$paths$results_dir, "rf_log_rolling_har_o_m_evaluation.csv")

data.table::fwrite(aligned_forecasts, forecast_output)
data.table::fwrite(final_eval, eval_output)

message("Saved aligned forecasts to: ", forecast_output)
message("Saved evaluation table to: ", eval_output)

print(final_eval)
