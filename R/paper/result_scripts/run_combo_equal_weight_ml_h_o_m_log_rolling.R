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
source(file.path("R", "functions", "framework", "FORECASTS", "combine_forecasts.R"))
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
master_data <- load_master_data(config)

spec_grid <- data.table::CJ(
  model_type = c("enet", "pca", "pls", "rf", "nn"),
  feature_set = c("HAR", "O", "M"),
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

all_forecasts <- data.table::rbindlist(lapply(forecast_runs, `[[`, "forecasts"), fill = TRUE)
all_forecasts <- clean_forecast_table(all_forecasts)

feature_target_lists <- lapply(
  split(all_forecasts, by = "feature_set", keep.by = FALSE),
  function(dt) unique(dt$target_date)
)

common_targets <- Reduce(intersect, feature_target_lists)

if (length(common_targets) == 0L) {
  stop("No common out-of-sample target dates across HAR, O, and M model forecasts.")
}

aligned_forecasts <- all_forecasts[target_date %in% common_targets]
individual_eval <- evaluate_forecasts(forecast_df = aligned_forecasts, config = config)$summary

feature_model_ids <- lapply(
  c("HAR", "O", "M"),
  function(feature_set_value) {
    sort(unique(aligned_forecasts[aligned_forecasts$feature_set == feature_set_value, forecast_id]))
  }
)
names(feature_model_ids) <- c("HAR", "O", "M")

combo_specs <- list(
  combo_equal_weight_ml_h_log_rolling = feature_model_ids$HAR,
  combo_equal_weight_ml_o_log_rolling = feature_model_ids$O,
  combo_equal_weight_ml_m_log_rolling = feature_model_ids$M,
  combo_equal_weight_ml_h_o_log_rolling = sort(c(feature_model_ids$HAR, feature_model_ids$O)),
  combo_equal_weight_ml_h_m_log_rolling = sort(c(feature_model_ids$HAR, feature_model_ids$M)),
  combo_equal_weight_ml_o_m_log_rolling = sort(c(feature_model_ids$O, feature_model_ids$M)),
  combo_equal_weight_ml_h_o_m_log_rolling = sort(unique(aligned_forecasts$forecast_id))
)

combo_forecasts <- data.table::rbindlist(
  lapply(
    names(combo_specs),
    function(combo_name) {
      combine_forecasts(
        forecast_df = aligned_forecasts,
        method = "equal_weight",
        selected_models = combo_specs[[combo_name]],
        combination_name = combo_name
      )
    }
  ),
  fill = TRUE
)

combo_eval <- evaluate_forecasts(forecast_df = combo_forecasts, config = config)$summary

final_eval <- data.table::rbindlist(
  list(individual_eval, combo_eval),
  fill = TRUE
)

final_eval[, specification := data.table::fcase(
  forecast_id == "enet__HAR__log__rolling", "Elastic Net: HAR",
  forecast_id == "pca__HAR__log__rolling", "PCA: HAR",
  forecast_id == "pls__HAR__log__rolling", "PLS: HAR",
  forecast_id == "rf__HAR__log__rolling", "RF: HAR",
  forecast_id == "nn__HAR__log__rolling", "NN: HAR",
  forecast_id == "enet__O__log__rolling", "Elastic Net: options-only",
  forecast_id == "pca__O__log__rolling", "PCA: options-only",
  forecast_id == "pls__O__log__rolling", "PLS: options-only",
  forecast_id == "rf__O__log__rolling", "RF: options-only",
  forecast_id == "nn__O__log__rolling", "NN: options-only",
  forecast_id == "enet__M__log__rolling", "Elastic Net: macro-only",
  forecast_id == "pca__M__log__rolling", "PCA: macro-only",
  forecast_id == "pls__M__log__rolling", "PLS: macro-only",
  forecast_id == "rf__M__log__rolling", "RF: macro-only",
  forecast_id == "nn__M__log__rolling", "NN: macro-only",
  forecast_id == "combo_equal_weight_ml_h_log_rolling", "Equal weight ML: HAR",
  forecast_id == "combo_equal_weight_ml_o_log_rolling", "Equal weight ML: options-only",
  forecast_id == "combo_equal_weight_ml_m_log_rolling", "Equal weight ML: macro-only",
  forecast_id == "combo_equal_weight_ml_h_o_log_rolling", "Equal weight ML: HAR + options",
  forecast_id == "combo_equal_weight_ml_h_m_log_rolling", "Equal weight ML: HAR + macro",
  forecast_id == "combo_equal_weight_ml_o_m_log_rolling", "Equal weight ML: options + macro",
  forecast_id == "combo_equal_weight_ml_h_o_m_log_rolling", "Equal weight ML: HAR + options + macro",
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

forecast_output <- file.path(config$paths$results_dir, "combo_equal_weight_ml_h_o_m_log_rolling_forecasts.csv")
eval_output <- file.path(config$paths$results_dir, "combo_equal_weight_ml_h_o_m_log_rolling_evaluation.csv")

data.table::fwrite(aligned_forecasts, forecast_output)
data.table::fwrite(final_eval, eval_output)

message("Saved aligned forecasts to: ", forecast_output)
message("Saved evaluation table to: ", eval_output)

print(final_eval)
