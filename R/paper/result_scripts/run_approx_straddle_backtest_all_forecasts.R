library(data.table)

source(file.path("R", "functions", "framework", "00_config.R"))
source(file.path("R", "functions", "framework", "UTILS", "helpers.R"))
source(file.path("R", "functions", "framework", "01_load_data.R"))
source(file.path("R", "functions", "framework", "RESULTS", "save_results.R"))
source(file.path("R", "functions", "framework", "EVALUATION", "cvrp_backtest.R"))
source(file.path("R", "functions", "framework", "EVALUATION", "approx_straddle_backtest.R"))

config <- create_config(base_dir = getwd())
master_data <- load_master_data(config)
all_forecasts <- clean_forecast_table(readRDS(file.path(config$paths$results_dir, "all_forecasts.rds")))
options_data <- fread(file.path(config$paths$data_dir, "Options_data_SPX.csv"))
straddle_panel <- build_approx_monthly_straddle_panel(options_data)

candidate_models <- unique(
  all_forecasts[
    model_type != "har_ols",
    .(model_forecast_id = forecast_id, target_type, window_type)
  ]
)
setorder(candidate_models, target_type, window_type, model_forecast_id)

batch_results <- vector("list", nrow(candidate_models))

for (i in seq_len(nrow(candidate_models))) {
  spec <- candidate_models[i]
  har_id <- paste("har_ols", "HAR", spec$target_type, spec$window_type, sep = "__")
  message(
    "[", i, "/", nrow(candidate_models), "] Approx straddle: ",
    spec$model_forecast_id
  )

  batch_results[[i]] <- run_approx_straddle_backtest_batch(
    master_data = master_data,
    forecast_df = all_forecasts,
    straddle_panel = straddle_panel,
    model_forecast_ids = spec$model_forecast_id,
    har_forecast_ids = har_id,
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
}

performance_dt <- rbindlist(lapply(batch_results, `[[`, "performance"), fill = TRUE)
trade_summary_dt <- rbindlist(lapply(batch_results, `[[`, "trade_summary"), fill = TRUE)
details_dt <- rbindlist(lapply(batch_results, `[[`, "details"), fill = TRUE)

performance_dt[, `:=`(
  annualized_payoff_dollars = 100 * annualized_mean_payoff,
  cumulative_payoff_dollars = 100 * cumulative_payoff_final,
  max_drawdown_dollars = 100 * max_drawdown,
  avg_entry_premium_dollars = 100 * avg_entry_premium,
  avg_intrinsic_exit_dollars = 100 * avg_intrinsic_exit,
  avg_monthly_payoff_dollars = 100 * mean_payoff
)]

always_short_dt <- performance_dt[
  strategy_name == "always_short_vol",
  .(
    model_forecast_id,
    always_short_annualized_payoff_dollars = annualized_payoff_dollars,
    always_short_annualized_sharpe = annualized_sharpe,
    always_short_cumulative_payoff_dollars = cumulative_payoff_dollars,
    always_short_max_drawdown_dollars = max_drawdown_dollars
  )
]

comparison_dt <- merge(
  performance_dt[strategy_name != "always_short_vol"],
  always_short_dt,
  by = "model_forecast_id",
  all.x = TRUE
)

comparison_dt[, `:=`(
  payoff_improvement_vs_always_short_dollars = annualized_payoff_dollars - always_short_annualized_payoff_dollars,
  sharpe_improvement_vs_always_short = annualized_sharpe - always_short_annualized_sharpe,
  beats_always_short_payoff = annualized_payoff_dollars > always_short_annualized_payoff_dollars,
  beats_always_short_sharpe = annualized_sharpe > always_short_annualized_sharpe,
  beats_always_short_both = annualized_payoff_dollars > always_short_annualized_payoff_dollars &
    annualized_sharpe > always_short_annualized_sharpe
)]

best_by_model_dt <- comparison_dt[
  order(model_forecast_id, -sharpe_improvement_vs_always_short, -payoff_improvement_vs_always_short_dollars)
][
  ,
  .SD[1],
  by = model_forecast_id
]

leaderboard_dt <- comparison_dt[
  order(-sharpe_improvement_vs_always_short, -payoff_improvement_vs_always_short_dollars)
]

save_results(straddle_panel, "approx_monthly_atm_straddle_panel", config)
save_results(performance_dt, "approx_straddle_all_forecasts_performance", config)
save_results(trade_summary_dt, "approx_straddle_all_forecasts_trade_summary", config)
save_results(details_dt, "approx_straddle_all_forecasts_details", config)
save_results(comparison_dt, "approx_straddle_all_forecasts_vs_always_short", config)
save_results(best_by_model_dt, "approx_straddle_all_forecasts_best_rule_by_model", config)
save_results(leaderboard_dt, "approx_straddle_all_forecasts_leaderboard", config)

message("Saved all-forecast approximate straddle outputs in ", config$paths$results_dir)
