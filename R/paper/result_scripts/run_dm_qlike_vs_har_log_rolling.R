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
source(file.path("R", "functions", "framework", "FORECASTS", "combine_forecasts.R"))
source(file.path("R", "functions", "framework", "EVALUATION", "dm_test.R"))

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
  model_type = c("har_ols", "enet", "pca", "pls", "rf", "nn"),
  feature_set = c("HAR", "O", "M"),
  sorted = FALSE
)

spec_grid <- spec_grid[!(model_type == "har_ols" & feature_set != "HAR")]

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
  split(all_forecasts[feature_set %in% c("HAR", "O", "M") & model_type != "har_ols"], by = "feature_set", keep.by = FALSE),
  function(dt) unique(dt$target_date)
)

common_targets <- Reduce(intersect, feature_target_lists)
aligned_base <- all_forecasts[target_date %in% common_targets]

block_specs <- list(
  combo_equal_weight_all_har_log_rolling = sort(unique(aligned_base[feature_set == "HAR" & model_type != "har_ols", forecast_id])),
  combo_equal_weight_all_o_log_rolling = sort(unique(aligned_base[feature_set == "O", forecast_id])),
  combo_equal_weight_all_m_log_rolling = sort(unique(aligned_base[feature_set == "M", forecast_id]))
)

block_forecasts <- data.table::rbindlist(
  lapply(
    names(block_specs),
    function(combo_name) {
      combine_forecasts(
        forecast_df = aligned_base,
        method = "equal_weight",
        selected_models = block_specs[[combo_name]],
        combination_name = combo_name
      )
    }
  ),
  fill = TRUE
)

meta_combo <- combine_forecasts(
  forecast_df = block_forecasts,
  method = "equal_weight",
  selected_models = unique(block_forecasts$forecast_id),
  combination_name = "combo_equal_weight_blocks_h_o_m_log_rolling"
)

target_models <- data.table::rbindlist(list(block_forecasts, meta_combo), fill = TRUE)
har_forecasts <- all_forecasts[forecast_id == "har_ols__HAR__log__rolling"]

qlike_from_vol <- function(actual_vol, forecast_vol, eps = 1e-8) {
  actual_safe <- pmax(actual_vol, eps)
  forecast_safe <- pmax(forecast_vol, eps)
  ratio <- (actual_safe ^ 2) / (forecast_safe ^ 2)
  ratio - log(ratio) - 1
}

comparison_ids <- c(
  "combo_equal_weight_blocks_h_o_m_log_rolling",
  "combo_equal_weight_all_har_log_rolling",
  "combo_equal_weight_all_m_log_rolling",
  "combo_equal_weight_all_o_log_rolling"
)

results <- data.table::rbindlist(
  lapply(
    comparison_ids,
    function(model_id) {
      model_dt <- target_models[forecast_id == model_id, .(target_date, actual_level, forecast_level)]
      har_dt <- har_forecasts[, .(target_date, har_forecast = forecast_level)]

      merged <- merge(model_dt, har_dt, by = "target_date", all = FALSE)
      merged <- merged[is.finite(actual_level) & is.finite(forecast_level) & is.finite(har_forecast)]

      model_loss <- qlike_from_vol(merged$actual_level, merged$forecast_level, eps = config$evaluation$qlike_epsilon)
      har_loss <- qlike_from_vol(merged$actual_level, merged$har_forecast, eps = config$evaluation$qlike_epsilon)
      dm <- dm_test(model_loss, har_loss, horizon = config$evaluation$dm_horizon)

      data.table::data.table(
        forecast_id = model_id,
        n_common = nrow(merged),
        mean_qlike_model = mean(model_loss),
        mean_qlike_har = mean(har_loss),
        qlike_gain_vs_har = mean(har_loss) - mean(model_loss),
        mean_loss_diff = dm$mean_loss_diff,
        dm_stat = dm$statistic,
        dm_p_value = dm$p_value
      )
    }
  ),
  fill = TRUE
)

results[, specification := data.table::fcase(
  forecast_id == "combo_equal_weight_blocks_h_o_m_log_rolling", "Equal weight of HAR, options-only, macro-only blocks",
  forecast_id == "combo_equal_weight_all_har_log_rolling", "Equal weight of all HAR models",
  forecast_id == "combo_equal_weight_all_m_log_rolling", "Equal weight of all macro-only models",
  forecast_id == "combo_equal_weight_all_o_log_rolling", "Equal weight of all options-only models",
  default = forecast_id
)]

data.table::setcolorder(
  results,
  c(
    "specification", "forecast_id", "n_common",
    "mean_qlike_model", "mean_qlike_har", "qlike_gain_vs_har",
    "mean_loss_diff", "dm_stat", "dm_p_value"
  )
)

data.table::setorder(results, -qlike_gain_vs_har)

out_path <- file.path(config$paths$results_dir, "dm_qlike_vs_har_log_rolling.csv")
data.table::fwrite(results, out_path)

message("Saved DM comparison table to: ", out_path)
print(results)
