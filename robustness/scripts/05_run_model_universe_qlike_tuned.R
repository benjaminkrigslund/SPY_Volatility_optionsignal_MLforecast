# QLIKE-oriented experiment:
# models are selected using validation QLIKE inside each training window,
# then evaluated fully out-of-sample.

source(file.path("R", "functions", "framework", "00_config.R"))
source(file.path("R", "functions", "framework", "UTILS", "helpers.R"))
source(file.path("R", "functions", "framework", "DATA", "build_master_dataset.R"))
source(file.path("R", "functions", "framework", "01_load_data.R"))
source(file.path("R", "functions", "framework", "FEATURES", "feature_sets.R"))
source(file.path("R", "functions", "framework", "MODELS", "model_har.R"))
source(file.path("R", "functions", "framework", "MODELS", "model_enet.R"))
source(file.path("R", "functions", "framework", "MODELS", "model_pca.R"))
source(file.path("R", "functions", "framework", "MODELS", "model_pls.R"))
source(file.path("R", "functions", "framework", "MODELS", "model_rf.R"))
source(file.path("R", "functions", "framework", "MODELS", "model_nn.R"))
source(file.path("R", "functions", "framework", "MODELS", "model_registry.R"))
source(file.path("R", "functions", "framework", "FORECASTS", "run_forecast_qlike_tuned.R"))
source(file.path("R", "functions", "framework", "EVALUATION", "dm_test.R"))
source(file.path("R", "functions", "framework", "EVALUATION", "encompassing_test.R"))
source(file.path("R", "functions", "framework", "EVALUATION", "evaluate_forecasts.R"))
source(file.path("R", "functions", "framework", "RESULTS", "save_results.R"))

required_packages <- c("data.table", "dplyr", "tidyr", "lubridate", "glmnet", "pls", "ranger", "nnet")
missing_packages <- required_packages[!vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing_packages) > 0L) {
  stop("Install required packages before running the QLIKE-tuned framework: ", paste(missing_packages, collapse = ", "))
}

config <- create_config(base_dir = getwd())
config$paths$output_dir <- config$paths$robustness_output_dir
ensure_dir(config$paths$results_dir)
ensure_dir(config$paths$framework_data_dir)

if (!file.exists(config$paths$master_data)) {
  build_master_dataset(
    data_path = config$paths$data_dir,
    output_path = config$paths$master_data,
    framework_copy_path = file.path(config$paths$framework_data_dir, "master_dataset.csv"),
    feature_dictionary_path = file.path(config$paths$framework_data_dir, "master_feature_dictionary.csv"),
    start_date = as.Date("1972-01-31"),
    save_outputs = TRUE
  )
}

master_data <- load_master_data(config)

spec_grid <- data.table::rbindlist(list(
  data.table::CJ(
    model_type = "har_ols",
    feature_set = "HAR",
    window_type = config$forecasting$window_types,
    target_type = config$forecasting$target_types,
    sorted = FALSE
  ),
  data.table::CJ(
    model_type = c("enet", "pca", "pls", "rf", "nn"),
    feature_set = c("HAR", "HAR_O", "HAR_M", "HAR_OM"),
    window_type = config$forecasting$window_types,
    target_type = config$forecasting$target_types,
    sorted = FALSE
  )
), fill = TRUE)

forecast_runs <- vector("list", nrow(spec_grid))
for (i in seq_len(nrow(spec_grid))) {
  spec <- spec_grid[i]
  message(
    "[", i, "/", nrow(spec_grid), "] Running QLIKE-tuned ",
    spec$model_type, " | ", spec$feature_set, " | ",
    spec$target_type, " | ", spec$window_type
  )

  forecast_runs[[i]] <- run_forecast_qlike_tuned(
    data = master_data,
    model_type = spec$model_type,
    feature_set = spec$feature_set,
    window_type = spec$window_type,
    initial_window = config$forecasting$initial_window,
    refit_every = config$forecasting$refit_every,
    target_type = spec$target_type,
    config = config
  )
}

all_forecasts <- data.table::rbindlist(lapply(forecast_runs, `[[`, "forecasts"), fill = TRUE)
all_forecasts <- clean_forecast_table(all_forecasts)
evaluation <- evaluate_forecasts(forecast_df = all_forecasts, config = config)

save_results(all_forecasts, "qlike_tuned_all_forecasts", config)
save_results(evaluation$summary, "qlike_tuned_forecast_evaluation_summary", config)
save_results(evaluation$losses, "qlike_tuned_forecast_loss_series", config)

message("QLIKE-tuned framework run complete. Results saved in data/processed/model_artifacts.")

