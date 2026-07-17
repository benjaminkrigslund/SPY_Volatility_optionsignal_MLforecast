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

spec_grid <- data.table::CJ(
  model_type = c("enet", "pca", "pls", "nn"),
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

family_target_lists <- lapply(
  split(all_forecasts, by = "model_type", keep.by = FALSE),
  function(dt) unique(dt$target_date)
)

common_targets <- Reduce(intersect, family_target_lists)

if (length(common_targets) == 0L) {
  stop("No common out-of-sample target dates across family winner candidate models.")
}

aligned_forecasts <- all_forecasts[target_date %in% common_targets]

family_members <- list(
  enet = list(
    combo_equal_weight_enet_h_o_m_log_rolling = c("enet__HAR__log__rolling", "enet__O__log__rolling", "enet__M__log__rolling")
  ),
  pca = list(
    combo_equal_weight_pca_h_m_log_rolling = c("pca__HAR__log__rolling", "pca__M__log__rolling")
  ),
  pls = list(
    combo_equal_weight_pls_h_o_m_log_rolling = c("pls__HAR__log__rolling", "pls__O__log__rolling", "pls__M__log__rolling")
  ),
  nn = list(
    combo_equal_weight_nn_h_o_m_log_rolling = c("nn__HAR__log__rolling", "nn__O__log__rolling", "nn__M__log__rolling")
  )
)

family_winner_forecasts <- data.table::rbindlist(
  lapply(
    names(family_members),
    function(family) {
      combo_name <- names(family_members[[family]])[1]
      members <- family_members[[family]][[1]]

      combine_forecasts(
        forecast_df = aligned_forecasts,
        method = "equal_weight",
        selected_models = members,
        combination_name = combo_name
      )
    }
  ),
  fill = TRUE
)

family_winner_eval <- evaluate_forecasts(forecast_df = family_winner_forecasts, config = config)$summary
family_winner_eval[, specification := data.table::fcase(
  forecast_id == "combo_equal_weight_enet_h_o_m_log_rolling", "Family winner: ENET HAR + options + macro",
  forecast_id == "combo_equal_weight_pca_h_m_log_rolling", "Family winner: PCA HAR + macro",
  forecast_id == "combo_equal_weight_pls_h_o_m_log_rolling", "Family winner: PLS HAR + options + macro",
  forecast_id == "combo_equal_weight_nn_h_o_m_log_rolling", "Family winner: NN HAR + options + macro",
  default = forecast_id
)]

meta_combo <- combine_forecasts(
  forecast_df = family_winner_forecasts,
  method = "equal_weight",
  selected_models = unique(family_winner_forecasts$forecast_id),
  combination_name = "combo_equal_weight_family_winners_log_rolling"
)

meta_eval <- evaluate_forecasts(forecast_df = meta_combo, config = config)$summary
meta_eval[, specification := "Equal weight of family winners"]

all_ml_hom <- combine_forecasts(
  forecast_df = aligned_forecasts,
  method = "equal_weight",
  selected_models = unique(aligned_forecasts$forecast_id),
  combination_name = "combo_equal_weight_all_ml_h_o_m_log_rolling"
)

all_ml_eval <- evaluate_forecasts(forecast_df = all_ml_hom, config = config)$summary
all_ml_eval[, specification := "Equal weight all ML families: HAR + options + macro"]

final_eval <- data.table::rbindlist(
  list(family_winner_eval, meta_eval, all_ml_eval),
  fill = TRUE
)

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

eval_output <- file.path(config$paths$results_dir, "combo_of_family_winners_log_rolling_evaluation.csv")
data.table::fwrite(final_eval, eval_output)

message("Saved evaluation table to: ", eval_output)
print(final_eval)
