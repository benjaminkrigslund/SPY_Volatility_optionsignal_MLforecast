library(data.table)
library(ggplot2)

source(file.path("R", "functions", "framework", "00_config.R"))
source(file.path("R", "functions", "framework", "UTILS", "helpers.R"))
source(file.path("R", "functions", "framework", "01_load_data.R"))
source(file.path("R", "functions", "framework", "RESULTS", "save_results.R"))
source(file.path("R", "functions", "framework", "EVALUATION", "cvrp_backtest.R"))

config <- create_config(base_dir = getwd())
master_data <- load_master_data(config)
all_forecasts <- readRDS(file.path(config$paths$results_dir, "all_forecasts.rds"))
all_forecasts <- clean_forecast_table(all_forecasts)

candidate_models <- unique(
  all_forecasts[
    model_type != "har_ols" &
      target_type == "log" &
      window_type == "rolling",
    .(model_forecast_id = forecast_id, model_type, feature_set)
  ]
)

selected_model_ids <- candidate_models[
  feature_set %in% c("HAR_O", "HAR_M", "HAR_OM")
][["model_forecast_id"]]

backtest_results <- run_cvrp_backtest_batch(
  master_data = master_data,
  forecast_df = all_forecasts,
  model_forecast_ids = selected_model_ids,
  implied_var_col = "implied_var_eom",
  realized_var_col = "rv_var",
  forecast_scale = "auto",
  thresholds = list(
    cvrp_har = 0,
    cvrp_model = 0,
    delta_cvrp = 0,
    long_cvrp_model = 0
  ),
  position_modes = c("binary", "signal_scaled"),
  scaled_signal = "cvrp_model",
  high_variance_filter = list(
    method = "expanding_quantile",
    quantile_level = 0.8,
    threshold_value = NULL,
    min_history = 24L,
    forecast_source = "model"
  ),
  include_long_vol = TRUE,
  max_abs_position = 1,
  scaling_method = "zscore"
)

performance_ranked <- backtest_results$performance[order(-annualized_sharpe, -cumulative_payoff_final)]

top_models <- unique(
  performance_ranked[
    strategy_name == "short_when_har_and_delta_positive_filtered" &
      position_mode == "binary",
    model_label
  ][seq_len(min(6L, .N))]
)

cumulative_plot <- plot_cvrp_cumulative(
  backtest_results$details,
  strategy_names = c(
    "always_short_vol",
    "short_when_cvrp_model_positive",
    "short_when_har_and_delta_positive",
    "short_when_har_and_delta_positive_filtered",
    "long_when_cvrp_model_negative"
  ),
  position_modes = c("binary", "signal_scaled"),
  top_n_models = length(top_models)
)

drawdown_plot <- plot_cvrp_drawdown(
  backtest_results$details,
  strategy_names = c(
    "always_short_vol",
    "short_when_cvrp_model_positive",
    "short_when_har_and_delta_positive",
    "short_when_har_and_delta_positive_filtered",
    "long_when_cvrp_model_negative"
  ),
  position_modes = c("binary", "signal_scaled"),
  top_n_models = length(top_models)
)

save_results(backtest_results$performance, "cvrp_backtest_performance", config)
save_results(backtest_results$trade_summary, "cvrp_backtest_trade_summary", config)
save_results(backtest_results$details, "cvrp_backtest_details", config)

ggplot2::ggsave(
  filename = file.path(config$paths$results_dir, "cvrp_backtest_cumulative.png"),
  plot = cumulative_plot,
  width = 16,
  height = 10,
  dpi = 300
)

ggplot2::ggsave(
  filename = file.path(config$paths$results_dir, "cvrp_backtest_drawdown.png"),
  plot = drawdown_plot,
  width = 16,
  height = 10,
  dpi = 300
)

message("Saved CVRP backtest outputs in ", config$paths$results_dir)
