library(data.table)
library(ggplot2)

source(file.path("R", "functions", "framework", "00_config.R"))
source(file.path("R", "functions", "framework", "UTILS", "helpers.R"))
source(file.path("R", "functions", "framework", "01_load_data.R"))
source(file.path("R", "functions", "framework", "EVALUATION", "cvrp_backtest.R"))
source(file.path("R", "functions", "framework", "EVALUATION", "approx_straddle_backtest.R"))

config <- create_config(base_dir = getwd())
master_data <- load_master_data(config)

forecast_path <- file.path(
  config$paths$results_dir,
  "har_augmented_common155_monthly_refit_forecasts.csv"
)
if (!file.exists(forecast_path)) {
  stop("Missing saved monthly-refit forecast panel: ", forecast_path)
}

forecast_df <- fread(forecast_path)
forecast_df <- clean_forecast_table(forecast_df)

options_data <- fread(file.path(config$paths$data_dir, "Options_data_SPX.csv"))
straddle_panel <- build_approx_monthly_straddle_panel(options_data)

selected_models <- data.table(
  forecast_id = c(
    "har_ols__HAR__log__rolling",
    "enet__HAR_O__log__rolling",
    "rf__HAR_O__log__rolling",
    "combo_equal_weight_har_o_across_ml_har_augmented_log_rolling",
    "combo_equal_weight_nn_across_har_augmented_datasets_log_rolling",
    "stacked_enet_on_har_augmented_forecasts_log_rolling"
  ),
  model_label = c(
    "HAR OLS",
    "ENET HAR + Option",
    "RF HAR + Option",
    "EW Across ML HAR + Option",
    "EW Neural Net Across Sets",
    "Stacked ENET"
  )
)

plot_forecasts <- merge(
  forecast_df[
    ,
    .(forecast_id, target_date, actual_level, forecast_level)
  ],
  selected_models,
  by = "forecast_id",
  all = FALSE
)

har_dt <- plot_forecasts[
  model_label == "HAR OLS",
  .(target_date, har_forecast = forecast_level, actual_level)
]

comparison_dt <- merge(
  plot_forecasts[model_label != "HAR OLS", .(forecast_id, model_label, target_date, model_forecast = forecast_level)],
  har_dt,
  by = "target_date",
  all = FALSE
)

comparison_dt[, `:=`(
  sq_error_model = (actual_level - model_forecast) ^ 2,
  sq_error_har = (actual_level - har_forecast) ^ 2
)]
comparison_dt[, cumulative_sq_error_gain_vs_har := cumsum(sq_error_har - sq_error_model), by = model_label]

cumulative_error_plot <- ggplot(
  comparison_dt,
  aes(x = target_date, y = cumulative_sq_error_gain_vs_har, color = model_label)
) +
  geom_hline(yintercept = 0, color = "grey70", linewidth = 0.4) +
  geom_line(linewidth = 0.8, alpha = 0.9) +
  scale_color_manual(
    values = c(
      "ENET HAR + Option" = "#D95F02",
      "RF HAR + Option" = "#1B9E77",
      "EW Across ML HAR + Option" = "#7570B3",
      "EW Neural Net Across Sets" = "#E7298A",
      "Stacked ENET" = "#E6AB02"
    )
  ) +
  labs(
    title = "Cumulative Squared-Error Gain vs HAR",
    subtitle = "Positive values mean the model has cumulatively beaten HAR on the common 155-date monthly-refit sample",
    x = NULL,
    y = "Cumulative gain in squared error",
    color = NULL
  ) +
  theme_minimal(base_size = 12) +
  theme(
    legend.position = "bottom",
    panel.grid.minor = element_blank(),
    plot.title = element_text(face = "bold")
  )

cumulative_error_path <- file.path(
  config$paths$output_dir,
  "har_augmented_common155_monthly_refit_cumulative_sq_error_gain_vs_har.png"
)
ggsave(cumulative_error_path, cumulative_error_plot, width = 11, height = 6, dpi = 300)

selected_model_ids <- selected_models$forecast_id
har_ids <- rep("har_ols__HAR__log__rolling", length(selected_model_ids))

approx_results <- run_approx_straddle_backtest_batch(
  master_data = master_data,
  forecast_df = forecast_df,
  straddle_panel = straddle_panel,
  model_forecast_ids = selected_model_ids,
  har_forecast_ids = har_ids,
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

performance_dt <- merge(
  approx_results$performance[, !c("model_label")],
  selected_models[, .(forecast_id, model_label)],
  by.x = "model_forecast_id",
  by.y = "forecast_id",
  all.x = TRUE
)
details_dt <- merge(
  approx_results$details[, !c("model_label")],
  selected_models[, .(forecast_id, model_label)],
  by.x = "model_forecast_id",
  by.y = "forecast_id",
  all.x = TRUE
)

payoff_plot_dt <- details_dt[
  strategy_name %in% c("always_short_vol", "short_when_cvrp_model_positive_filtered")
]
payoff_plot_dt[, strategy_label := fifelse(
  strategy_name == "always_short_vol",
  "Always short vol",
  "Short when model CVRP > 0 and high-vol filter passes"
)]

payoff_plot <- ggplot(
  payoff_plot_dt,
  aes(x = target_date, y = cumulative_payoff, color = strategy_label)
) +
  geom_line(linewidth = 0.75, alpha = 0.9) +
  facet_wrap(~ model_label, scales = "free_y", ncol = 2) +
  scale_color_manual(
    values = c(
      "Always short vol" = "#4D4D4D",
      "Short when model CVRP > 0 and high-vol filter passes" = "#D95F02"
    )
  ) +
  labs(
    title = "Approximate Straddle Backtest: Cumulative Payoff",
    subtitle = "Binary strategy using the monthly-refit common-155 forecast panel",
    x = NULL,
    y = "Cumulative payoff",
    color = NULL
  ) +
  theme_minimal(base_size = 12) +
  theme(
    legend.position = "bottom",
    panel.grid.minor = element_blank(),
    plot.title = element_text(face = "bold")
  )

payoff_plot_path <- file.path(
  config$paths$output_dir,
  "har_augmented_common155_monthly_refit_straddle_cumulative_payoff.png"
)
ggsave(payoff_plot_path, payoff_plot, width = 12, height = 10, dpi = 300)

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
        by = .(model_label, model_forecast_id, strategy_name, position_mode)
      ][, gamma := gamma]
    }
  ),
  fill = TRUE
)

baseline_ce <- utility_dt[
  model_label == "HAR OLS",
  .(strategy_name, position_mode, gamma, har_annualized_ce = annualized_ce)
]

utility_dt <- merge(
  utility_dt,
  baseline_ce,
  by = c("strategy_name", "position_mode", "gamma"),
  all.x = TRUE
)
utility_dt[, ce_gain_vs_har := annualized_ce - har_annualized_ce]

best_utility_dt <- utility_dt[
  model_label != "HAR OLS"
][
  order(model_label, gamma, -ce_gain_vs_har, -annualized_ce)
][
  ,
  .SD[1],
  by = .(model_label, gamma)
]

utility_plot_dt <- utility_dt[
  strategy_name == "short_when_cvrp_model_positive_filtered" &
    position_mode == "binary" &
    model_label != "HAR OLS"
]

utility_plot <- ggplot(
  utility_plot_dt,
  aes(x = gamma, y = ce_gain_vs_har, color = model_label)
) +
  geom_hline(yintercept = 0, color = "grey70", linewidth = 0.4) +
  geom_line(linewidth = 0.85, alpha = 0.9) +
  geom_point(size = 1.8) +
  scale_x_continuous(breaks = gamma_grid) +
  scale_color_manual(
    values = c(
      "ENET HAR + Option" = "#D95F02",
      "RF HAR + Option" = "#1B9E77",
      "EW Across ML HAR + Option" = "#7570B3",
      "EW Neural Net Across Sets" = "#E7298A",
      "Stacked ENET" = "#E6AB02"
    )
  ) +
  labs(
    title = "Investor Utility Gain vs HAR Benchmark",
    subtitle = "Annualized certainty-equivalent gain from the filtered short-vol rule across risk aversion levels",
    x = "Risk aversion gamma",
    y = "CE gain vs HAR OLS"
  ) +
  theme_minimal(base_size = 12) +
  theme(
    legend.position = "bottom",
    panel.grid.minor = element_blank(),
    plot.title = element_text(face = "bold")
  )

utility_plot_path <- file.path(
  config$paths$output_dir,
  "har_augmented_common155_monthly_refit_ce_gain_by_gamma.png"
)
ggsave(utility_plot_path, utility_plot, width = 10, height = 6, dpi = 300)

performance_output <- file.path(
  config$paths$results_dir,
  "har_augmented_common155_monthly_refit_straddle_performance.csv"
)
utility_output <- file.path(
  config$paths$results_dir,
  "har_augmented_common155_monthly_refit_utility_summary.csv"
)
best_utility_output <- file.path(
  config$paths$results_dir,
  "har_augmented_common155_monthly_refit_best_utility_by_model.csv"
)

fwrite(performance_dt, performance_output)
fwrite(utility_dt, utility_output)
fwrite(best_utility_dt, best_utility_output)

message("Saved cumulative error-gain plot to: ", cumulative_error_path)
message("Saved straddle cumulative-payoff plot to: ", payoff_plot_path)
message("Saved CE-gain plot to: ", utility_plot_path)
message("Saved straddle performance table to: ", performance_output)
message("Saved utility summary to: ", utility_output)
message("Saved best utility-by-model table to: ", best_utility_output)
print(
  utility_dt[
    strategy_name == "short_when_cvrp_model_positive_filtered" &
      position_mode == "binary",
    .(model_label, gamma, annualized_ce, har_annualized_ce, ce_gain_vs_har)
  ][order(gamma, -ce_gain_vs_har)]
)
