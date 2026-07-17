source(file.path("R", "functions", "framework", "00_config.R"))
source(file.path("R", "functions", "framework", "UTILS", "helpers.R"))
source(file.path("R", "functions", "framework", "FORECASTS", "combine_forecasts.R"))
source(file.path("R", "functions", "framework", "EVALUATION", "dm_test.R"))

config <- create_config(base_dir = getwd())

base_forecasts_path <- file.path(config$paths$results_dir, "combo_equal_weight_ml_h_o_m_log_rolling_forecasts.csv")
har_losses_path <- file.path(config$paths$results_dir, "forecast_loss_series.csv")

if (!file.exists(base_forecasts_path)) {
  stop("Missing base forecast file: ", base_forecasts_path)
}

if (!file.exists(har_losses_path)) {
  stop("Missing HAR loss file: ", har_losses_path)
}

base_forecasts <- data.table::fread(base_forecasts_path)
base_forecasts <- data.table::as.data.table(base_forecasts)
base_forecasts <- base_forecasts[target_type == "log" & window_type == "rolling"]

har_dt <- data.table::fread(har_losses_path)
har_dt <- data.table::as.data.table(har_dt)
har_dt <- har_dt[
  forecast_id == "har_ols__HAR__log__rolling",
  .(target_date, har_forecast = forecast_level)
]

combo_specs <- list(
  combo_equal_weight_ml_h_o_m_log_rolling = sort(unique(base_forecasts$forecast_id)),
  combo_equal_weight_ml_h_o_log_rolling = sort(unique(base_forecasts[feature_set %in% c("HAR", "O"), forecast_id])),
  combo_equal_weight_family_winners_log_rolling = c(
    "enet__HAR__log__rolling", "enet__O__log__rolling", "enet__M__log__rolling",
    "pca__HAR__log__rolling", "pca__M__log__rolling",
    "pls__HAR__log__rolling", "pls__O__log__rolling", "pls__M__log__rolling",
    "nn__HAR__log__rolling", "nn__O__log__rolling", "nn__M__log__rolling"
  ),
  combo_equal_weight_blocks_h_o_m_log_rolling = NULL,
  combo_equal_weight_all_har_log_rolling = sort(unique(base_forecasts[feature_set == "HAR", forecast_id])),
  combo_equal_weight_pls_h_o_m_log_rolling = c(
    "pls__HAR__log__rolling", "pls__O__log__rolling", "pls__M__log__rolling"
  )
)

block_h <- combine_forecasts(
  forecast_df = base_forecasts,
  method = "equal_weight",
  selected_models = sort(unique(base_forecasts[feature_set == "HAR", forecast_id])),
  combination_name = "combo_equal_weight_all_har_log_rolling"
)

block_o <- combine_forecasts(
  forecast_df = base_forecasts,
  method = "equal_weight",
  selected_models = sort(unique(base_forecasts[feature_set == "O", forecast_id])),
  combination_name = "combo_equal_weight_all_o_log_rolling"
)

block_m <- combine_forecasts(
  forecast_df = base_forecasts,
  method = "equal_weight",
  selected_models = sort(unique(base_forecasts[feature_set == "M", forecast_id])),
  combination_name = "combo_equal_weight_all_m_log_rolling"
)

blocks_combo_input <- data.table::rbindlist(list(block_h, block_o, block_m), fill = TRUE)
blocks_combo <- combine_forecasts(
  forecast_df = blocks_combo_input,
  method = "equal_weight",
  selected_models = unique(blocks_combo_input$forecast_id),
  combination_name = "combo_equal_weight_blocks_h_o_m_log_rolling"
)

build_combo <- function(combo_name, members) {
  if (identical(combo_name, "combo_equal_weight_blocks_h_o_m_log_rolling")) {
    return(blocks_combo)
  }

  combine_forecasts(
    forecast_df = base_forecasts,
    method = "equal_weight",
    selected_models = members,
    combination_name = combo_name
  )
}

candidate_models <- data.table::rbindlist(
  c(
    list(
      data.table::data.table(
        target_date = har_dt$target_date,
        actual_level = har_dt$actual_level,
        forecast_level = har_dt$har_forecast,
        forecast_id = "har_ols__HAR__log__rolling",
        specification = "HAR OLS"
      )
    ),
    lapply(
      names(combo_specs),
      function(combo_name) {
        combo_dt <- build_combo(combo_name, combo_specs[[combo_name]])
        combo_dt[, specification := data.table::fcase(
          forecast_id == "combo_equal_weight_ml_h_o_m_log_rolling", "Equal weight all ML: HAR + options + macro",
          forecast_id == "combo_equal_weight_ml_h_o_log_rolling", "Equal weight all ML: HAR + options",
          forecast_id == "combo_equal_weight_family_winners_log_rolling", "Equal weight of family winners",
          forecast_id == "combo_equal_weight_blocks_h_o_m_log_rolling", "Equal weight of HAR, options-only, macro-only blocks",
          forecast_id == "combo_equal_weight_all_har_log_rolling", "Equal weight of all HAR models",
          forecast_id == "combo_equal_weight_pls_h_o_m_log_rolling", "Equal weight PLS: HAR + options + macro",
          default = forecast_id
        )]
        combo_dt[, .(target_date, actual_level, forecast_level, forecast_id, specification)]
      }
    )
  ),
  fill = TRUE
)

target_ids <- unique(candidate_models$forecast_id)
common_targets <- Reduce(
  intersect,
  lapply(
    split(candidate_models, by = "forecast_id", keep.by = FALSE),
    function(dt) unique(dt$target_date)
  )
)

aligned_models <- candidate_models[target_date %in% common_targets]
aligned_har <- har_dt[target_date %in% common_targets]

qlike_from_vol <- function(actual_vol, forecast_vol, eps = 1e-8) {
  actual_safe <- pmax(actual_vol, eps)
  forecast_safe <- pmax(forecast_vol, eps)
  ratio <- (actual_safe ^ 2) / (forecast_safe ^ 2)
  ratio - log(ratio) - 1
}

results <- data.table::rbindlist(
  lapply(
    target_ids,
    function(model_id) {
      model_dt <- aligned_models[forecast_id == model_id]
      merged <- merge(
        model_dt[, .(target_date, actual_level, model_forecast = forecast_level, specification)],
        aligned_har,
        by = "target_date",
        all = FALSE
      )

      se_model <- (merged$actual_level - merged$model_forecast) ^ 2
      se_har <- (merged$actual_level - merged$har_forecast) ^ 2
      qlike_model <- qlike_from_vol(merged$actual_level, merged$model_forecast, eps = config$evaluation$qlike_epsilon)
      qlike_har <- qlike_from_vol(merged$actual_level, merged$har_forecast, eps = config$evaluation$qlike_epsilon)
      dm <- dm_test(qlike_model, qlike_har, horizon = config$evaluation$dm_horizon)

      data.table::data.table(
        specification = merged$specification[[1]],
        forecast_id = model_id,
        n_common = nrow(merged),
        mean_qlike = mean(qlike_model),
        mean_qlike_har = mean(qlike_har),
        qlike_gain_vs_har = mean(qlike_har) - mean(qlike_model),
        oos_r2_vs_har = 1 - sum(se_model) / sum(se_har),
        dm_qlike_stat_vs_har = dm$statistic,
        dm_qlike_p_vs_har = dm$p_value
      )
    }
  ),
  fill = TRUE
)

data.table::setorder(results, -qlike_gain_vs_har, -oos_r2_vs_har)

out_path <- file.path(config$paths$results_dir, "unified_har_benchmark_table_log_rolling.csv")
data.table::fwrite(results, out_path)

message("Saved unified HAR benchmark table to: ", out_path)
print(results)
