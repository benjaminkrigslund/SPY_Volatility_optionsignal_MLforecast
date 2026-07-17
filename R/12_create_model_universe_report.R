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
source(file.path("R", "functions", "framework", "FORECASTS", "run_forecast.R"))
source(file.path("R", "functions", "framework", "EVALUATION", "dm_test.R"))
source(file.path("R", "functions", "framework", "EVALUATION", "encompassing_test.R"))
source(file.path("R", "functions", "framework", "EVALUATION", "model_universe_reporting.R"))

required_packages <- c("data.table", "glmnet", "pls", "ranger", "nnet", "MCS", "openxlsx")
missing_packages <- required_packages[!vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing_packages) > 0L) {
  stop("Install required packages before running the model universe report: ", paste(missing_packages, collapse = ", "))
}

config <- create_config(base_dir = getwd())
ensure_dir(config$paths$framework_data_dir)
ensure_dir(config$paths$results_dir)
ensure_dir(config$paths$output_dir)

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
spec_dt <- get_model_universe_specifications(config, master_data)
scenario_specs <- spec_dt[, .(
  specification_name,
  model_type,
  feature_set,
  model_family,
  information_set,
  n_predictors,
  target_type = config$reporting$main_target_type,
  window_type = config$reporting$main_window_type
)]

forecast_runs <- vector("list", nrow(scenario_specs))

for (i in seq_len(nrow(scenario_specs))) {
  spec <- scenario_specs[i]
  message("[", i, "/", nrow(scenario_specs), "] ", spec$specification_name)
  forecast_runs[[i]] <- run_forecast(
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
all_forecasts <- merge(
  all_forecasts,
  scenario_specs[, .(model_type, feature_set, specification_name, model_family, information_set, n_predictors)],
  by = c("model_type", "feature_set"),
  all.x = TRUE
)

forecast_output <- build_model_universe_forecast_output(all_forecasts, scenario_specs)
report_dt <- compute_model_universe_report(all_forecasts, scenario_specs, config)
main_dt <- build_main_paper_table(report_dt)
qc_dt <- run_model_universe_quality_checks(master_data, all_forecasts, forecast_output, scenario_specs, config)

data.table::fwrite(forecast_output, file.path(config$paths$output_dir, "model_universe_tidy_forecasts.csv"))
data.table::fwrite(report_dt, file.path(config$paths$output_dir, "model_universe_final_report.csv"))
data.table::fwrite(main_dt, file.path(config$paths$output_dir, "model_universe_main_paper_table.csv"))
data.table::fwrite(qc_dt, file.path(config$paths$output_dir, "model_universe_quality_checks.csv"))

write_model_universe_excel(
  report_dt = report_dt,
  main_dt = main_dt,
  forecast_dt = forecast_output,
  qc_dt = qc_dt,
  output_path = file.path(config$paths$output_dir, "model_universe_report.xlsx")
)

summary_dt <- report_dt[, .(
  number_of_model_specifications_run = .N,
  min_oos_forecasts_per_model = min(n_oos, na.rm = TRUE),
  max_oos_forecasts_per_model = max(n_oos, na.rm = TRUE)
)]

best_oos <- report_dt[which.max(oos_r2), .(specification_name, oos_r2)]
best_qlike <- report_dt[which.min(qlike), .(specification_name, qlike)]

message("Model universe run complete.")
print(summary_dt)
print(best_oos)
print(best_qlike)
