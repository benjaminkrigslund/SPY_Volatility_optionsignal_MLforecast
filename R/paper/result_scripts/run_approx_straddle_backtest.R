library(data.table)
library(ggplot2)

source(file.path("R", "functions", "framework", "00_config.R"))
source(file.path("R", "functions", "framework", "UTILS", "helpers.R"))
source(file.path("R", "functions", "framework", "01_load_data.R"))
source(file.path("R", "functions", "framework", "RESULTS", "save_results.R"))
source(file.path("R", "functions", "framework", "EVALUATION", "cvrp_backtest.R"))
source(file.path("R", "functions", "framework", "EVALUATION", "approx_straddle_backtest.R"))

config <- create_config(base_dir = getwd())
master_data <- load_master_data(config)
all_forecasts <- clean_forecast_table(readRDS(file.path(config$paths$results_dir, "all_forecasts.rds")))
options_data <- data.table::fread(file.path(config$paths$data_dir, "Options_data_SPX.csv"))

straddle_panel <- build_approx_monthly_straddle_panel(options_data)

selected_model_ids <- c(
  "har_ols__HAR__log__rolling",
  "pca__HAR_O__log__rolling",
  "pls__HAR_O__log__rolling",
  "rf__HAR_OM__log__rolling"
)
selected_har_ids <- c(
  "har_ols__HAR__log__rolling",
  "har_ols__HAR__log__rolling",
  "har_ols__HAR__log__rolling",
  "har_ols__HAR__log__rolling"
)

results <- run_approx_straddle_backtest_batch(
  master_data = master_data,
  forecast_df = all_forecasts,
  straddle_panel = straddle_panel,
  model_forecast_ids = selected_model_ids,
  har_forecast_ids = selected_har_ids,
  implied_var_col = "implied_var_eom",
  forecast_scale = "auto",
  thresholds = list(
    cvrp_har = 0,
    cvrp_model = 0,
    delta_cvrp = 0,
    long_cvrp_model = 0
  ),
  position_modes = c("binary"),
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

save_results(straddle_panel, "approx_monthly_atm_straddle_panel", config)
save_results(results$performance, "approx_straddle_backtest_performance", config)
save_results(results$trade_summary, "approx_straddle_backtest_trade_summary", config)
save_results(results$details, "approx_straddle_backtest_details", config)

cum_plot <- ggplot(
  results$details[strategy_name %in% c(
    "always_short_vol",
    "short_when_cvrp_model_positive",
    "short_when_har_and_delta_positive",
    "short_when_har_and_delta_positive_filtered",
    "long_when_cvrp_model_negative"
  )],
  aes(x = target_date, y = cumulative_payoff, color = strategy_name)
) +
  geom_line(linewidth = 0.7) +
  facet_wrap(~ model_label, scales = "free_y") +
  labs(
    title = "Approximate ATM 30-Day Straddle Backtest",
    subtitle = "Entry premium from +/-50 delta month-end SPX options; exit payoff uses next month proxy spot",
    x = NULL,
    y = "Cumulative approximate payoff"
  ) +
  theme_minimal(base_size = 11) +
  theme(legend.position = "bottom")

dd_plot <- ggplot(
  results$details[strategy_name %in% c(
    "always_short_vol",
    "short_when_cvrp_model_positive",
    "short_when_har_and_delta_positive",
    "short_when_har_and_delta_positive_filtered",
    "long_when_cvrp_model_negative"
  )],
  aes(x = target_date, y = drawdown, color = strategy_name)
) +
  geom_line(linewidth = 0.7) +
  facet_wrap(~ model_label, scales = "free_y") +
  labs(
    title = "Approximate ATM 30-Day Straddle Drawdown",
    x = NULL,
    y = "Drawdown"
  ) +
  theme_minimal(base_size = 11) +
  theme(legend.position = "bottom")

ggsave(
  filename = file.path(config$paths$results_dir, "approx_straddle_backtest_cumulative.png"),
  plot = cum_plot,
  width = 15,
  height = 10,
  dpi = 300
)

ggsave(
  filename = file.path(config$paths$results_dir, "approx_straddle_backtest_drawdown.png"),
  plot = dd_plot,
  width = 15,
  height = 10,
  dpi = 300
)

message("Saved approximate straddle backtest outputs in ", config$paths$results_dir)
