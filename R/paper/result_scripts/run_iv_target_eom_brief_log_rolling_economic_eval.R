library(data.table)

source(file.path("R", "functions", "framework", "00_config.R"))
source(file.path("R", "functions", "framework", "UTILS", "helpers.R"))
source(file.path("R", "functions", "framework", "01_load_data.R"))
source(file.path("R", "functions", "framework", "RESULTS", "save_results.R"))
source(file.path("R", "functions", "framework", "EVALUATION", "cvrp_backtest.R"))
source(file.path("R", "functions", "framework", "EVALUATION", "approx_straddle_backtest.R"))

config <- create_config(base_dir = getwd())
results_subdir <- "iv_target_eom_brief"

forecast_path <- file.path(
  config$paths$results_dir,
  results_subdir,
  "all_forecasts.rds"
)

if (!file.exists(forecast_path)) {
  stop(
    "Missing IV-target forecast file: ", forecast_path,
    "\nRun data/processed/model_artifacts/run_iv_target_eom_brief_log_rolling_refit6_12.R first."
  )
}

master_data <- load_master_data(config)
forecast_df <- clean_forecast_table(readRDS(forecast_path))
options_data <- fread(file.path(config$paths$data_dir, "Options_data_SPX.csv"))
straddle_panel <- build_approx_monthly_straddle_panel(options_data)

har_map <- unique(
  forecast_df[
    model_type == "har_ols" &
      feature_set == "HAR" &
      target_type == "log" &
      window_type == "rolling",
    .(
      refit_every,
      target_type,
      window_type,
      har_forecast_id = forecast_id
    )
  ]
)

candidate_models <- unique(
  forecast_df[
    model_type != "har_ols" &
      target_type == "log" &
      window_type == "rolling",
    .(
      model_forecast_id = forecast_id,
      refit_every,
      model_type,
      feature_set,
      target_type,
      window_type
    )
  ]
)

candidate_models <- merge(
  candidate_models,
  har_map,
  by = c("refit_every", "target_type", "window_type"),
  all.x = TRUE
)

candidate_models <- candidate_models[!is.na(har_forecast_id)]
setorder(candidate_models, refit_every, model_type, feature_set, model_forecast_id)

batch_results <- vector("list", nrow(candidate_models))

for (i in seq_len(nrow(candidate_models))) {
  spec <- candidate_models[i]
  message(
    "[", i, "/", nrow(candidate_models), "] Approx straddle: ",
    spec$model_forecast_id
  )

  batch_results[[i]] <- run_approx_straddle_backtest_batch(
    master_data = master_data,
    forecast_df = forecast_df,
    straddle_panel = straddle_panel,
    model_forecast_ids = spec$model_forecast_id,
    har_forecast_ids = spec$har_forecast_id,
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

model_meta <- unique(
  candidate_models[
    ,
    .(
      model_forecast_id,
      refit_every,
      model_type,
      feature_set
    )
  ]
)

performance_dt <- merge(performance_dt, model_meta, by = "model_forecast_id", all.x = TRUE)
trade_summary_dt <- merge(trade_summary_dt, model_meta, by = "model_forecast_id", all.x = TRUE)
details_dt <- merge(details_dt, model_meta, by = "model_forecast_id", all.x = TRUE)

performance_dt[, `:=`(
  annualized_payoff_dollars = 100 * annualized_mean_payoff,
  cumulative_payoff_dollars = 100 * cumulative_payoff_final,
  max_drawdown_dollars = 100 * max_drawdown,
  avg_monthly_payoff_dollars = 100 * mean_payoff,
  avg_entry_premium_dollars = 100 * avg_entry_premium
)]

always_short_dt <- performance_dt[
  strategy_name == "always_short_vol",
  .(
    model_forecast_id,
    always_short_annualized_payoff_dollars = annualized_payoff_dollars,
    always_short_annualized_sharpe = annualized_sharpe,
    always_short_cumulative_payoff_dollars = cumulative_payoff_dollars
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
  sharpe_improvement_vs_always_short = annualized_sharpe - always_short_annualized_sharpe
)]

details_dt[, strategy_return := fifelse(
  is.finite(straddle_premium) & abs(straddle_premium) > 1e-8,
  strategy_payoff / abs(straddle_premium),
  0
)]

gamma_grid <- 1:10

utility_dt <- rbindlist(
  lapply(
    gamma_grid,
    function(gamma) {
      details_dt[
        ,
        .(
          mean_return = mean(strategy_return, na.rm = TRUE),
          sd_return = sd(strategy_return, na.rm = TRUE),
          annualized_ce = 12 * (
            mean(strategy_return, na.rm = TRUE) -
              0.5 * gamma * stats::var(strategy_return, na.rm = TRUE)
          )
        ),
        by = .(
          refit_every,
          model_forecast_id,
          model_type,
          feature_set,
          strategy_name,
          direction,
          position_mode,
          filter_name
        )
      ][, gamma := gamma]
    }
  ),
  fill = TRUE
)

selected_strategy <- comparison_dt[
  strategy_name == "short_when_cvrp_model_positive_filtered" &
    position_mode == "binary"
][
  order(refit_every, model_forecast_id, -annualized_sharpe, -annualized_payoff_dollars)
][
  ,
  .SD[1],
  by = .(refit_every, model_forecast_id)
]

selected_utility_dt <- merge(
  utility_dt,
  selected_strategy[, .(
    refit_every,
    model_forecast_id,
    strategy_name,
    direction,
    position_mode,
    filter_name
  )],
  by = c(
    "refit_every",
    "model_forecast_id",
    "strategy_name",
    "direction",
    "position_mode",
    "filter_name"
  ),
  all = FALSE
)

best_ce_by_refit_dt <- selected_utility_dt[
  order(refit_every, gamma, -annualized_ce, model_forecast_id)
][
  ,
  .SD[1],
  by = .(refit_every, gamma)
]

save_results(straddle_panel, "approx_monthly_atm_straddle_panel", config, subdir = results_subdir)
save_results(performance_dt, "iv_target_approx_straddle_performance", config, subdir = results_subdir)
save_results(trade_summary_dt, "iv_target_approx_straddle_trade_summary", config, subdir = results_subdir)
save_results(details_dt, "iv_target_approx_straddle_details", config, subdir = results_subdir)
save_results(comparison_dt, "iv_target_approx_straddle_vs_always_short", config, subdir = results_subdir)
save_results(selected_strategy, "iv_target_approx_straddle_selected_strategy", config, subdir = results_subdir)
save_results(utility_dt, "iv_target_certainty_equivalent_grid", config, subdir = results_subdir)
save_results(best_ce_by_refit_dt, "iv_target_best_certainty_equivalent_by_refit", config, subdir = results_subdir)

message("Saved IV-target economic evaluation outputs in data/processed/model_artifacts/", results_subdir)
