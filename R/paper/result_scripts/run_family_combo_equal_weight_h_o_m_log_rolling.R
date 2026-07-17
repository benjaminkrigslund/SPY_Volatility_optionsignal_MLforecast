source(file.path("R", "functions", "framework", "00_config.R"))
source(file.path("R", "functions", "framework", "UTILS", "helpers.R"))
source(file.path("R", "functions", "framework", "01_load_data.R"))
source(file.path("R", "functions", "framework", "FEATURES", "feature_sets.R"))
source(file.path("R", "functions", "framework", "MODELS", "model_enet.R"))
source(file.path("R", "functions", "framework", "MODELS", "model_pca.R"))
source(file.path("R", "functions", "framework", "MODELS", "model_pls.R"))
source(file.path("R", "functions", "framework", "MODELS", "model_nn.R"))
source(file.path("R", "functions", "framework", "MODELS", "model_registry.R"))
source(file.path("R", "functions", "framework", "FORECASTS", "run_forecast.R"))
source(file.path("R", "functions", "framework", "FORECASTS", "combine_forecasts.R"))
source(file.path("R", "functions", "framework", "EVALUATION", "dm_test.R"))
source(file.path("R", "functions", "framework", "EVALUATION", "encompassing_test.R"))
source(file.path("R", "functions", "framework", "EVALUATION", "evaluate_forecasts.R"))

required_packages <- c("data.table", "glmnet", "pls", "nnet")
missing_packages <- required_packages[!vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)]

if (length(missing_packages) > 0L) {
  stop(
    "Install required packages before running this script: ",
    paste(missing_packages, collapse = ", ")
  )
}

config <- create_config(base_dir = getwd())
master_data <- load_master_data(config)

model_families <- c("enet", "pca", "pls", "nn")
feature_sets <- c("HAR", "O", "M")

spec_grid <- data.table::CJ(
  model_type = model_families,
  feature_set = feature_sets,
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

family_results <- vector("list", length(model_families))
names(family_results) <- model_families

for (family in model_families) {
  family_forecasts <- all_forecasts[model_type == family]

  feature_target_lists <- lapply(
    split(family_forecasts, by = "feature_set", keep.by = FALSE),
    function(dt) unique(dt$target_date)
  )

  common_targets <- Reduce(intersect, feature_target_lists)

  if (length(common_targets) == 0L) {
    next
  }

  aligned_forecasts <- family_forecasts[target_date %in% common_targets]
  individual_eval <- evaluate_forecasts(forecast_df = aligned_forecasts, config = config)$summary

  feature_model_ids <- lapply(
    feature_sets,
    function(feature_set_value) {
      sort(unique(aligned_forecasts[aligned_forecasts$feature_set == feature_set_value, forecast_id]))
    }
  )
  names(feature_model_ids) <- feature_sets

  combo_specs <- setNames(
    list(
      feature_model_ids$HAR,
      feature_model_ids$O,
      feature_model_ids$M,
      sort(c(feature_model_ids$HAR, feature_model_ids$O)),
      sort(c(feature_model_ids$HAR, feature_model_ids$M)),
      sort(c(feature_model_ids$O, feature_model_ids$M)),
      sort(unique(aligned_forecasts$forecast_id))
    ),
    c(
      paste0("combo_equal_weight_", family, "_h_log_rolling"),
      paste0("combo_equal_weight_", family, "_o_log_rolling"),
      paste0("combo_equal_weight_", family, "_m_log_rolling"),
      paste0("combo_equal_weight_", family, "_h_o_log_rolling"),
      paste0("combo_equal_weight_", family, "_h_m_log_rolling"),
      paste0("combo_equal_weight_", family, "_o_m_log_rolling"),
      paste0("combo_equal_weight_", family, "_h_o_m_log_rolling")
    )
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

  family_eval <- data.table::rbindlist(list(individual_eval, combo_eval), fill = TRUE)
  family_eval[, family := family]
  family_results[[family]] <- family_eval
}

final_eval <- data.table::rbindlist(family_results, fill = TRUE)

final_eval[, specification := data.table::fcase(
  forecast_id == "enet__HAR__log__rolling", "ENET: HAR",
  forecast_id == "enet__O__log__rolling", "ENET: options-only",
  forecast_id == "enet__M__log__rolling", "ENET: macro-only",
  forecast_id == "combo_equal_weight_enet_h_log_rolling", "Equal weight ENET: HAR",
  forecast_id == "combo_equal_weight_enet_o_log_rolling", "Equal weight ENET: options-only",
  forecast_id == "combo_equal_weight_enet_m_log_rolling", "Equal weight ENET: macro-only",
  forecast_id == "combo_equal_weight_enet_h_o_log_rolling", "Equal weight ENET: HAR + options",
  forecast_id == "combo_equal_weight_enet_h_m_log_rolling", "Equal weight ENET: HAR + macro",
  forecast_id == "combo_equal_weight_enet_o_m_log_rolling", "Equal weight ENET: options + macro",
  forecast_id == "combo_equal_weight_enet_h_o_m_log_rolling", "Equal weight ENET: HAR + options + macro",
  forecast_id == "pca__HAR__log__rolling", "PCA: HAR",
  forecast_id == "pca__O__log__rolling", "PCA: options-only",
  forecast_id == "pca__M__log__rolling", "PCA: macro-only",
  forecast_id == "combo_equal_weight_pca_h_log_rolling", "Equal weight PCA: HAR",
  forecast_id == "combo_equal_weight_pca_o_log_rolling", "Equal weight PCA: options-only",
  forecast_id == "combo_equal_weight_pca_m_log_rolling", "Equal weight PCA: macro-only",
  forecast_id == "combo_equal_weight_pca_h_o_log_rolling", "Equal weight PCA: HAR + options",
  forecast_id == "combo_equal_weight_pca_h_m_log_rolling", "Equal weight PCA: HAR + macro",
  forecast_id == "combo_equal_weight_pca_o_m_log_rolling", "Equal weight PCA: options + macro",
  forecast_id == "combo_equal_weight_pca_h_o_m_log_rolling", "Equal weight PCA: HAR + options + macro",
  forecast_id == "pls__HAR__log__rolling", "PLS: HAR",
  forecast_id == "pls__O__log__rolling", "PLS: options-only",
  forecast_id == "pls__M__log__rolling", "PLS: macro-only",
  forecast_id == "combo_equal_weight_pls_h_log_rolling", "Equal weight PLS: HAR",
  forecast_id == "combo_equal_weight_pls_o_log_rolling", "Equal weight PLS: options-only",
  forecast_id == "combo_equal_weight_pls_m_log_rolling", "Equal weight PLS: macro-only",
  forecast_id == "combo_equal_weight_pls_h_o_log_rolling", "Equal weight PLS: HAR + options",
  forecast_id == "combo_equal_weight_pls_h_m_log_rolling", "Equal weight PLS: HAR + macro",
  forecast_id == "combo_equal_weight_pls_o_m_log_rolling", "Equal weight PLS: options + macro",
  forecast_id == "combo_equal_weight_pls_h_o_m_log_rolling", "Equal weight PLS: HAR + options + macro",
  forecast_id == "nn__HAR__log__rolling", "NN: HAR",
  forecast_id == "nn__O__log__rolling", "NN: options-only",
  forecast_id == "nn__M__log__rolling", "NN: macro-only",
  forecast_id == "combo_equal_weight_nn_h_log_rolling", "Equal weight NN: HAR",
  forecast_id == "combo_equal_weight_nn_o_log_rolling", "Equal weight NN: options-only",
  forecast_id == "combo_equal_weight_nn_m_log_rolling", "Equal weight NN: macro-only",
  forecast_id == "combo_equal_weight_nn_h_o_log_rolling", "Equal weight NN: HAR + options",
  forecast_id == "combo_equal_weight_nn_h_m_log_rolling", "Equal weight NN: HAR + macro",
  forecast_id == "combo_equal_weight_nn_o_m_log_rolling", "Equal weight NN: options + macro",
  forecast_id == "combo_equal_weight_nn_h_o_m_log_rolling", "Equal weight NN: HAR + options + macro",
  default = forecast_id
)]

data.table::setcolorder(
  final_eval,
  c(
    "family", "specification", "forecast_id", "model_type", "feature_set", "target_type", "window_type",
    "n_oos", "mse_model", "mse_benchmark", "oos_r2", "qlike", "qlike_benchmark",
    "dm_se_stat", "dm_se_p", "dm_qlike_stat", "dm_qlike_p",
    "encompassing_coef", "encompassing_stat", "encompassing_p"
  )
)

data.table::setorder(final_eval, family, -oos_r2, qlike)

eval_output <- file.path(config$paths$results_dir, "family_combo_equal_weight_h_o_m_log_rolling_evaluation.csv")
data.table::fwrite(final_eval, eval_output)

message("Saved evaluation table to: ", eval_output)
print(final_eval)
