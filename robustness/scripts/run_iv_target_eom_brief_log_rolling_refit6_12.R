source(file.path("R", "functions", "framework", "00_config.R"))
source(file.path("R", "functions", "framework", "UTILS", "helpers.R"))
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
source(file.path("R", "functions", "framework", "EVALUATION", "evaluate_forecasts.R"))
source(file.path("R", "functions", "framework", "RESULTS", "save_results.R"))

required_packages <- c("data.table", "glmnet", "pls", "ranger", "nnet")
missing_packages <- required_packages[!vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)]

if (length(missing_packages) > 0L) {
  stop(
    "Install required packages before running the brief IV-target framework: ",
    paste(missing_packages, collapse = ", ")
  )
}

build_iv_target_dataset <- function(master_data,
                                    target_col = "implied_var_eom",
                                    har_cols = c("har_iv_1m", "har_iv_3m", "har_iv_12m")) {
  target_data <- data.table::copy(data.table::as.data.table(master_data))

  if (!target_col %in% names(target_data)) {
    stop("Target column not found in master dataset: ", target_col)
  }

  target_data[, (har_cols[1L]) := get(target_col)]
  target_data[, (har_cols[2L]) := data.table::frollmean(get(target_col), n = 3L, align = "right")]
  target_data[, (har_cols[3L]) := data.table::frollmean(get(target_col), n = 12L, align = "right")]

  target_data[]
}

summarise_accuracy <- function(forecast_df) {
  forecast_dt <- clean_forecast_table(forecast_df)
  forecast_dt[, ae_model := abs(actual_level - forecast_level)]
  forecast_dt[, ae_benchmark := abs(actual_level - benchmark_forecast)]
  forecast_dt[, se_model := (actual_level - forecast_level) ^ 2]
  forecast_dt[, se_benchmark := (actual_level - benchmark_forecast) ^ 2]

  forecast_dt[
    ,
    .(
      n_oos = .N,
      mae_model = mean(ae_model, na.rm = TRUE),
      mae_benchmark = mean(ae_benchmark, na.rm = TRUE),
      rmse_model = sqrt(mean(se_model, na.rm = TRUE)),
      rmse_benchmark = sqrt(mean(se_benchmark, na.rm = TRUE)),
      oos_r2 = 1 - sum(se_model, na.rm = TRUE) / sum(se_benchmark, na.rm = TRUE)
    ),
    by = .(refit_every, forecast_id, model_type, feature_set, target_type, window_type)
  ]
}

config <- create_config(base_dir = getwd())
config$paths$output_dir <- config$paths$robustness_output_dir
results_subdir <- "iv_target_eom_brief"
target_col <- "implied_var_eom"
har_cols <- c("har_iv_1m", "har_iv_3m", "har_iv_12m")
refit_grid <- c(1L, 6L, 12L)

master_data <- load_master_data(config)
iv_target_data <- build_iv_target_dataset(
  master_data = master_data,
  target_col = target_col,
  har_cols = har_cols
)

iv_config <- config
iv_config$columns$target <- target_col
iv_config$columns$har <- har_cols
iv_config$columns$option <- setdiff(config$columns$option, target_col)

spec_grid <- data.table::rbindlist(list(
  data.table::data.table(
    model_type = "har_ols",
    feature_set = "HAR",
    window_type = "rolling",
    target_type = "log"
  ),
  data.table::CJ(
    model_type = c("enet", "pca", "pls", "rf", "nn"),
    feature_set = c("HAR", "HAR_O", "HAR_M", "HAR_OM"),
    window_type = "rolling",
    target_type = "log",
    sorted = FALSE
  )
), fill = TRUE)

all_forecasts_by_refit <- vector("list", length(refit_grid))
all_importance_by_refit <- vector("list", length(refit_grid))
all_eval_by_refit <- vector("list", length(refit_grid))

for (r in seq_along(refit_grid)) {
  refit_value <- refit_grid[r]
  forecast_runs <- vector("list", nrow(spec_grid))

  for (i in seq_len(nrow(spec_grid))) {
    spec <- spec_grid[i]
    message(
      "[refit=", refit_value, "] [", i, "/", nrow(spec_grid), "] ",
      spec$model_type, " | ", spec$feature_set, " | ",
      spec$target_type, " | ", spec$window_type
    )

    run_out <- run_forecast(
      data = iv_target_data,
      model_type = spec$model_type,
      feature_set = spec$feature_set,
      window_type = spec$window_type,
      initial_window = iv_config$forecasting$initial_window,
      refit_every = refit_value,
      target_type = spec$target_type,
      config = iv_config
    )

    if (nrow(run_out$forecasts) > 0L) {
      run_out$forecasts[, refit_every := refit_value]
      run_out$forecasts[, forecast_id := paste0(forecast_id, "__refit", refit_value)]
    }

    if (nrow(run_out$importance) > 0L) {
      run_out$importance[, refit_every := refit_value]
    }

    forecast_runs[[i]] <- run_out
  }

  refit_forecasts <- data.table::rbindlist(lapply(forecast_runs, `[[`, "forecasts"), fill = TRUE)
  refit_forecasts <- clean_forecast_table(refit_forecasts)
  refit_importance <- data.table::rbindlist(lapply(forecast_runs, `[[`, "importance"), fill = TRUE)

  refit_eval <- evaluate_forecasts(forecast_df = refit_forecasts, config = iv_config)
  refit_eval$summary[, refit_every := refit_value]
  refit_eval$losses[, refit_every := refit_value]

  all_forecasts_by_refit[[r]] <- refit_forecasts
  all_importance_by_refit[[r]] <- refit_importance
  all_eval_by_refit[[r]] <- refit_eval
}

all_forecasts <- data.table::rbindlist(all_forecasts_by_refit, fill = TRUE)
all_importance <- data.table::rbindlist(all_importance_by_refit, fill = TRUE)
evaluation_summary <- data.table::rbindlist(lapply(all_eval_by_refit, `[[`, "summary"), fill = TRUE)
loss_series <- data.table::rbindlist(lapply(all_eval_by_refit, `[[`, "losses"), fill = TRUE)
accuracy_summary <- summarise_accuracy(all_forecasts)

save_results(all_forecasts, "all_forecasts", iv_config, subdir = results_subdir)
save_results(all_importance, "all_variable_importance", iv_config, subdir = results_subdir)
save_results(evaluation_summary, "forecast_evaluation_summary", iv_config, subdir = results_subdir)
save_results(loss_series, "forecast_loss_series", iv_config, subdir = results_subdir)
save_results(accuracy_summary, "forecast_accuracy_summary", iv_config, subdir = results_subdir)

message("Brief IV-target experiment complete.")
message("Results saved in data/processed/model_artifacts/", results_subdir)
message("Target = ", target_col, " | window_type = rolling | target_type = log")
message("Refit grid = ", paste(refit_grid, collapse = ", "))
