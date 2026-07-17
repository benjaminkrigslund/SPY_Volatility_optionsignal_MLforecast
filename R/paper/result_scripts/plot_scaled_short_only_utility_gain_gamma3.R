#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(data.table)
  library(ggplot2)
})

base_dir <- getwd()
table_dir <- file.path(base_dir, "output", "tables")
figure_dir <- file.path(base_dir, "output", "figures")
dir.create(table_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(figure_dir, recursive = TRUE, showWarnings = FALSE)

source(file.path(base_dir, "R", "functions", "framework", "EVALUATION", "economic_value_vrp_strategy.R"))

gamma_value <- 3
cost_value <- 0.001
min_expanding_months <- 12L

forecast_path <- file.path(base_dir, "data", "processed", "forecast_panels", "main_forecast_forecast_panel.csv")
master_path <- file.path(base_dir, "data", "processed", "master_dataset.csv")
ranking_candidates <- c(
  file.path(table_dir, "economic_value_vrp_scaled_short_only_all_models_and_combos_main_rolling120.csv"),
  file.path(table_dir, "economic_value_vrp_scaled_short_only_forecast_combinations_main_rolling120.csv")
)
ranking_path <- ranking_candidates[file.exists(ranking_candidates)][1]

if (!file.exists(forecast_path)) {
  stop("Missing forecast panel: ", forecast_path)
}
if (!file.exists(master_path)) {
  stop("Missing master dataset: ", master_path)
}
if (is.na(ranking_path)) {
  stop("Missing ranked strategy table. Expected one of: ", paste(ranking_candidates, collapse = ", "))
}

forecast_panel <- fread(forecast_path)
forecast_panel <- forecast_panel[
  target_scale == "log_rv" &
    window_type == "rolling" &
    rolling_window_months == 120L &
    refit_frequency == 1L
]

master_data <- fread(master_path)
ranking_dt <- fread(ranking_path)
if (!"sharpe_rank" %in% names(ranking_dt)) {
  ranking_dt[, sharpe_rank := frank(-sharpe_net, ties.method = "min", na.last = "keep")]
}

message("Recomputing scaled short-only strategy returns for main rolling-120 panel...")
vrp_results <- run_vrp_economic_evaluation(
  forecast_inputs = list(main_forecast_panel = forecast_panel),
  master_data = master_data,
  output_dir = table_dir,
  implied_var_cols = "implied_var_eom",
  realized_var_col = "rv_var",
  forecast_unit = "auto",
  common_dates = TRUE,
  include_naive_benchmarks = TRUE,
  min_history = 24L,
  max_abs_position = 1,
  cost_per_turnover = cost_value,
  gamma_values = gamma_value,
  write_outputs = FALSE,
  make_plots = FALSE
)

returns_dt <- vrp_long_return_table(vrp_results$costed_returns)
returns_dt <- returns_dt[
  implied_var_col == "implied_var_eom" &
    target_scale == "log_rv" &
    window_type == "rolling" &
    rolling_window_months == 120L &
    strategy_type == "scaled_short_only" &
    return_variant == "normalized_by_implied_variance" &
    abs(cost_per_turnover - cost_value) < 1e-12
]

format_specification <- function(model_group, model, information_set, forecast_type) {
  out <- fifelse(
    model_group == "Benchmark" | model == "OLS HAR",
    "HAR scaled short-only",
    fifelse(
      forecast_type == "all_EW",
      "All ML forecasts EW (Multiple)",
      fifelse(
        forecast_type == "method_EW",
        paste0(model, " EW (Multiple)"),
        fifelse(
          forecast_type == "infoset_EW",
          paste0("Equal Weight (", information_set, ")"),
          fifelse(
            forecast_type == "stacked",
            paste0(model, " (Multiple)"),
            paste0(model, " (", information_set, ")")
          )
        )
      )
    )
  )
  out
}

returns_dt[, target_date := as.Date(target_date)]
returns_dt[, forecast_specification := format_specification(
  model_group,
  model,
  information_set,
  forecast_type
)]

har_dt <- returns_dt[
  forecast_specification == "HAR scaled short-only",
  .(target_date, har_return = net_return)
]

if (nrow(har_dt) == 0L) {
  stop("Could not identify HAR scaled short-only benchmark returns.")
}

plot_dt <- merge(
  returns_dt[forecast_specification != "HAR scaled short-only"],
  har_dt,
  by = "target_date",
  all.x = TRUE
)

plot_dt <- plot_dt[is.finite(net_return) & is.finite(har_return)]
setorder(plot_dt, forecast_specification, target_date)

plot_dt[, utility := net_return - 0.5 * gamma_value * net_return^2]
plot_dt[, har_utility := har_return - 0.5 * gamma_value * har_return^2]
plot_dt[, utility_gain_vs_har := utility - har_utility]
plot_dt[, return_gain_vs_har := net_return - har_return]

plot_dt[
  ,
  `:=`(
    cumulative_utility_gain_vs_har = cumsum(utility_gain_vs_har),
    cumulative_return_gain_vs_har = cumsum(return_gain_vs_har),
    n_months = seq_len(.N)
  ),
  by = forecast_specification
]

plot_dt[
  ,
  expanding_ceq_model := {
    out <- rep(NA_real_, .N)
    for (i in seq_len(.N)) {
      if (i >= min_expanding_months) {
        x <- net_return[seq_len(i)]
        out[[i]] <- 12 * (mean(x, na.rm = TRUE) - 0.5 * gamma_value * var(x, na.rm = TRUE))
      }
    }
    out
  },
  by = forecast_specification
]

plot_dt[
  ,
  expanding_ceq_har := {
    out <- rep(NA_real_, .N)
    for (i in seq_len(.N)) {
      if (i >= min_expanding_months) {
        x <- har_return[seq_len(i)]
        out[[i]] <- 12 * (mean(x, na.rm = TRUE) - 0.5 * gamma_value * var(x, na.rm = TRUE))
      }
    }
    out
  },
  by = forecast_specification
]

plot_dt[, expanding_ceq_gain_vs_har_annualized := expanding_ceq_model - expanding_ceq_har]

ranking_keep <- ranking_dt[
  !is.na(sharpe_net) & is.finite(sharpe_net),
  .(forecast_specification, sharpe_rank, sharpe_net, ceq_gain_vs_har_gamma3)
]

plot_dt <- merge(plot_dt, ranking_keep, by = "forecast_specification", all.x = TRUE)

highlight_specs <- unique(c(
  ranking_keep[order(sharpe_rank)][seq_len(min(.N, 5L)), forecast_specification],
  "Equal Weight (HAR+Macro+Option)",
  "All ML forecasts EW (Multiple)"
))
highlight_specs <- highlight_specs[highlight_specs %in% plot_dt$forecast_specification]

plot_dt[, highlighted := forecast_specification %in% highlight_specs]
plot_dt[, plot_label := fifelse(highlighted, forecast_specification, "All other specifications")]

series_output <- file.path(
  table_dir,
  "economic_value_vrp_scaled_short_only_utility_gain_gamma3_vs_har_all_models.csv"
)
fwrite(
  plot_dt[
    ,
    .(
      target_date,
      forecast_specification,
      model_group,
      model,
      information_set,
      forecast_type,
      sharpe_rank,
      sharpe_net,
      net_return,
      har_return,
      utility,
      har_utility,
      utility_gain_vs_har,
      cumulative_utility_gain_vs_har,
      return_gain_vs_har,
      cumulative_return_gain_vs_har,
      expanding_ceq_gain_vs_har_annualized,
      highlighted
    )
  ],
  series_output
)

plot_colors <- c(
  "Elastic Net (HAR+Option)" = "#0F766E",
  "Random Forest (HAR+Macro+Option)" = "#EA580C",
  "Random Forest (HAR+Option)" = "#2563EB",
  "Stacked Random Forest (Multiple)" = "#7C3AED",
  "Stacked Elastic Net (Multiple)" = "#DB2777",
  "Equal Weight (HAR+Macro+Option)" = "#A16207",
  "All ML forecasts EW (Multiple)" = "#334155"
)
plot_colors <- plot_colors[names(plot_colors) %in% highlight_specs]

endpoints <- plot_dt[
  highlighted == TRUE,
  .SD[.N],
  by = forecast_specification
]

background_dt <- plot_dt[highlighted == FALSE]
highlight_dt <- plot_dt[highlighted == TRUE]

base_theme <- theme_minimal(base_family = "Helvetica", base_size = 12) +
  theme(
    plot.title = element_text(face = "bold", size = 16, color = "#111827"),
    plot.subtitle = element_text(size = 11, color = "#374151", margin = margin(b = 8)),
    plot.caption = element_text(size = 9, color = "#6B7280", hjust = 0),
    panel.grid.minor = element_blank(),
    panel.grid.major.x = element_blank(),
    legend.position = "bottom",
    legend.title = element_blank(),
    plot.margin = margin(14, 70, 14, 14)
  )

cumulative_plot <- ggplot() +
  geom_hline(yintercept = 0, linewidth = 0.45, color = "#111827") +
  geom_line(
    data = background_dt,
    aes(x = target_date, y = cumulative_utility_gain_vs_har, group = forecast_specification),
    linewidth = 0.35,
    alpha = 0.18,
    color = "#94A3B8"
  ) +
  geom_line(
    data = highlight_dt,
    aes(x = target_date, y = cumulative_utility_gain_vs_har, color = forecast_specification),
    linewidth = 1.05
  ) +
  geom_text(
    data = endpoints,
    aes(x = target_date, y = cumulative_utility_gain_vs_har, label = forecast_specification, color = forecast_specification),
    hjust = -0.04,
    size = 3.1,
    show.legend = FALSE,
    check_overlap = TRUE
  ) +
  scale_color_manual(values = plot_colors) +
  scale_x_date(expand = expansion(mult = c(0.01, 0.18))) +
  labs(
    title = "Investor Utility Gain from Scaled Short-Vol Timing",
    subtitle = paste0(
      "Cumulative quadratic-utility gain versus HAR benchmark, gamma = ",
      gamma_value,
      "; all non-highlighted specifications shown in grey"
    ),
    x = NULL,
    y = "Cumulative utility gain vs HAR",
    caption = paste0(
      "Strategy: scaled short-only VRP timing, normalized variance payoff, ",
      "cost_per_turnover = ", cost_value,
      ". Utility flow: r_t - gamma/2 * r_t^2."
    )
  ) +
  coord_cartesian(clip = "off") +
  base_theme

ceq_plot <- ggplot() +
  geom_hline(yintercept = 0, linewidth = 0.45, color = "#111827") +
  geom_line(
    data = background_dt[is.finite(expanding_ceq_gain_vs_har_annualized)],
    aes(x = target_date, y = expanding_ceq_gain_vs_har_annualized, group = forecast_specification),
    linewidth = 0.35,
    alpha = 0.16,
    color = "#94A3B8"
  ) +
  geom_line(
    data = highlight_dt[is.finite(expanding_ceq_gain_vs_har_annualized)],
    aes(x = target_date, y = expanding_ceq_gain_vs_har_annualized, color = forecast_specification),
    linewidth = 1.05
  ) +
  scale_color_manual(values = plot_colors) +
  labs(
    title = "Expanding CEQ Gain from Scaled Short-Vol Timing",
    subtitle = paste0(
      "Annualized CEQ gain versus HAR benchmark, gamma = ",
      gamma_value,
      "; estimated using returns observed up to each date"
    ),
    x = NULL,
    y = "Expanding annualized CEQ gain vs HAR",
    caption = paste0(
      "CEQ = mean(r) - gamma/2 * var(r), annualized by multiplying by 12. ",
      "First ", min_expanding_months, " months are used before plotting CEQ."
    )
  ) +
  base_theme

cumulative_plot_path <- file.path(
  figure_dir,
  "economic_value_vrp_scaled_short_only_cumulative_utility_gain_gamma3_vs_har_all_models.png"
)
ceq_plot_path <- file.path(
  figure_dir,
  "economic_value_vrp_scaled_short_only_expanding_ceq_gain_gamma3_vs_har_all_models.png"
)

ggsave(cumulative_plot_path, cumulative_plot, width = 12, height = 7, dpi = 300)
ggsave(ceq_plot_path, ceq_plot, width = 12, height = 7, dpi = 300)

summary_output <- file.path(
  table_dir,
  "economic_value_vrp_scaled_short_only_utility_gain_gamma3_vs_har_highlights.csv"
)
fwrite(
  plot_dt[
    highlighted == TRUE,
    .SD[.N],
    by = forecast_specification
  ][
    order(sharpe_rank),
    .(
      forecast_specification,
      sharpe_rank,
      sharpe_net,
      final_cumulative_utility_gain_vs_har = cumulative_utility_gain_vs_har,
      final_cumulative_return_gain_vs_har = cumulative_return_gain_vs_har,
      final_expanding_ceq_gain_vs_har_annualized = expanding_ceq_gain_vs_har_annualized
    )
  ],
  summary_output
)

message("Saved cumulative utility-gain plot to: ", cumulative_plot_path)
message("Saved expanding CEQ-gain plot to: ", ceq_plot_path)
message("Saved all-model utility-gain time series to: ", series_output)
message("Saved highlighted endpoint summary to: ", summary_output)
