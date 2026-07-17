#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(data.table)
  library(ggplot2)
})

table_dir <- file.path(getwd(), "output", "tables")
figure_dir <- file.path(getwd(), "output", "figures")
panel_path <- file.path(getwd(), "data", "processed", "forecast_panels", "main_forecast_forecast_panel.csv")
dir.create(table_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(figure_dir, recursive = TRUE, showWarnings = FALSE)

if (!file.exists(panel_path)) {
  stop("Missing forecast panel: ", panel_path)
}

panel <- fread(panel_path)
panel[, target_date := as.Date(target_date)]

panel_120 <- panel[
  rolling_window_months == 120L &
    window_type == "rolling" &
    target_scale == "log_rv"
]

if (nrow(panel_120) == 0L) {
  stop("No 120-month rolling log-RV forecasts found in ", panel_path)
}

har_dt <- panel_120[
  forecast_id == "har_ols__HAR__log__rolling",
  .(
    target_date,
    har_forecast_rv = forecast_value_rv,
    realized_value_rv
  )
]

if (nrow(har_dt) == 0L) {
  stop("Could not find HAR benchmark series in the 120-month forecast panel.")
}

selected_specs <- data.table(
  forecast_id = c(
    "enet__HAR_O__log__rolling",
    "rf__HAR_O__log__rolling",
    "rf__HAR_OM__log__rolling",
    "nn__HAR_OM__log__rolling",
    "combo_equal_weight_har_o_across_ml_har_augmented_log_rolling",
    "combo_equal_weight_rf_across_har_augmented_datasets_log_rolling",
    "combo_equal_weight_all_har_augmented_ml_x_dataset_log_rolling",
    "stacked_rf_on_har_augmented_forecasts_log_rolling",
    "stacked_enet_on_har_augmented_forecasts_log_rolling"
  ),
  plot_label = c(
    "Elastic Net | HAR+Option",
    "Random Forest | HAR+Option",
    "Random Forest | HAR+Macro+Option",
    "Neural Network | HAR+Macro+Option",
    "Equal Weight | HAR+Option",
    "Random Forest EW | Multiple",
    "Equal Weight | All ML",
    "Stacked Random Forest",
    "Stacked Elastic Net"
  ),
  plot_group = c(
    "Individual models",
    "Individual models",
    "Individual models",
    "Individual models",
    "Equal-weight combinations",
    "Equal-weight combinations",
    "Equal-weight combinations",
    "Stacked combinations",
    "Stacked combinations"
  ),
  plot_order = seq_len(9L)
)

available_ids <- unique(panel_120$forecast_id)
missing_ids <- setdiff(selected_specs$forecast_id, available_ids)
if (length(missing_ids) > 0L) {
  stop("Selected forecast IDs are missing from the panel: ", paste(missing_ids, collapse = ", "))
}

plot_dt <- merge(
  panel_120[forecast_id %in% selected_specs$forecast_id],
  har_dt,
  by = "target_date",
  all.x = TRUE,
  suffixes = c("", "_har_row")
)
plot_dt <- merge(plot_dt, selected_specs, by = "forecast_id", all.x = TRUE)
setorder(plot_dt, plot_order, target_date)

plot_dt[, `:=`(
  se_model = (realized_value_rv - forecast_value_rv) ^ 2,
  se_har = (realized_value_rv - har_forecast_rv) ^ 2
)]

plot_dt[, `:=`(
  cumulative_model_se = cumsum(se_model),
  cumulative_har_se = cumsum(se_har),
  n_elapsed = seq_len(.N)
), by = forecast_id]

plot_dt[, cumulative_r2_oos_vs_har := 1 - cumulative_model_se / cumulative_har_se]

rolling_r2_window_months <- 36L
plot_dt[, `:=`(
  rolling_model_se = frollsum(se_model, n = rolling_r2_window_months, align = "right"),
  rolling_har_se = frollsum(se_har, n = rolling_r2_window_months, align = "right")
), by = forecast_id]

plot_dt[, rolling36_r2_oos_vs_har := 1 - rolling_model_se / rolling_har_se]

plot_dt[, plot_label := factor(plot_label, levels = selected_specs$plot_label)]
plot_dt[, plot_group := factor(
  plot_group,
  levels = c("Individual models", "Equal-weight combinations", "Stacked combinations")
)]

fwrite(
  plot_dt[, .(
    target_date,
    forecast_id,
    plot_label,
    plot_group,
    n_elapsed,
    cumulative_r2_oos_vs_har = round(cumulative_r2_oos_vs_har, 6),
    rolling36_r2_oos_vs_har = round(rolling36_r2_oos_vs_har, 6)
  )],
  file.path(table_dir, "main_forecast_r2oos_timeseries_selected.csv")
)

summary_dt <- plot_dt[
  ,
  .(
    final_cumulative_r2_oos_vs_har = round(last(cumulative_r2_oos_vs_har), 5),
    min_cumulative_r2_oos_vs_har = round(min(cumulative_r2_oos_vs_har, na.rm = TRUE), 5),
    max_cumulative_r2_oos_vs_har = round(max(cumulative_r2_oos_vs_har, na.rm = TRUE), 5),
    final_rolling36_r2_oos_vs_har = round(last(rolling36_r2_oos_vs_har), 5),
    min_rolling36_r2_oos_vs_har = round(min(rolling36_r2_oos_vs_har, na.rm = TRUE), 5),
    max_rolling36_r2_oos_vs_har = round(max(rolling36_r2_oos_vs_har, na.rm = TRUE), 5)
  ),
  by = .(plot_order, plot_group, plot_label)
][order(plot_order)]

fwrite(summary_dt, file.path(table_dir, "main_forecast_r2oos_timeseries_selected_summary.csv"))

line_palette <- c(
  "Elastic Net | HAR+Option" = "#0072B2",
  "Random Forest | HAR+Option" = "#D55E00",
  "Random Forest | HAR+Macro+Option" = "#009E73",
  "Neural Network | HAR+Macro+Option" = "#CC79A7",
  "Equal Weight | HAR+Option" = "#E69F00",
  "Random Forest EW | Multiple" = "#56B4E9",
  "Equal Weight | All ML" = "#000000",
  "Stacked Random Forest" = "#7F3C8D",
  "Stacked Elastic Net" = "#11A579"
)

base_theme <- theme_minimal(base_size = 11) +
  theme(
    legend.position = "bottom",
    legend.title = element_blank(),
    panel.grid.minor = element_blank(),
    plot.title = element_text(face = "bold"),
    strip.text = element_text(face = "bold"),
    axis.title.y = element_text(margin = margin(r = 8))
  )

cumulative_plot_dt <- plot_dt[n_elapsed >= 12L]
crisis_start <- as.Date("2020-03-01")
crisis_end <- as.Date("2020-12-31")

cumulative_plot <- ggplot(
  cumulative_plot_dt,
  aes(x = target_date, y = cumulative_r2_oos_vs_har, color = plot_label)
) +
  annotate(
    "rect",
    xmin = crisis_start,
    xmax = crisis_end,
    ymin = -Inf,
    ymax = Inf,
    fill = "grey70",
    alpha = 0.18
  ) +
  geom_hline(yintercept = 0, linetype = "dashed", color = "grey50", linewidth = 0.35) +
  geom_line(linewidth = 0.85, alpha = 0.95) +
  facet_wrap(~ plot_group, ncol = 1) +
  scale_color_manual(values = line_palette, drop = FALSE) +
  labs(
    title = "Cumulative R2 OOS Gain Over HAR Benchmark",
    subtitle = "Selected 120-month rolling log-RV forecasts; first 12 OOS months omitted; shaded area marks Mar-Dec 2020",
    x = NULL,
    y = "1 - cumulative model SE / cumulative HAR SE"
  ) +
  base_theme

rolling_plot <- ggplot(
  plot_dt[is.finite(rolling36_r2_oos_vs_har)],
  aes(x = target_date, y = rolling36_r2_oos_vs_har, color = plot_label)
) +
  geom_hline(yintercept = 0, linetype = "dashed", color = "grey50", linewidth = 0.35) +
  geom_line(linewidth = 0.85, alpha = 0.95) +
  facet_wrap(~ plot_group, ncol = 1) +
  scale_color_manual(values = line_palette, drop = FALSE) +
  labs(
    title = "Trailing 36-Month OOS R2 versus HAR",
    subtitle = "Selected 120-month rolling log-RV forecasts; local performance over time",
    x = NULL,
    y = "36-month OOS R2 vs HAR"
  ) +
  base_theme

ggsave(
  filename = file.path(figure_dir, "main_forecast_r2oos_cumulative_selected.png"),
  plot = cumulative_plot,
  width = 11,
  height = 8,
  dpi = 300
)

ggsave(
  filename = file.path(figure_dir, "main_forecast_cumulative_r2_oos_gain_vs_har_selected.png"),
  plot = cumulative_plot,
  width = 11,
  height = 8,
  dpi = 300
)

ggsave(
  filename = file.path(figure_dir, "main_forecast_r2oos_rolling36_selected.png"),
  plot = rolling_plot,
  width = 11,
  height = 8,
  dpi = 300
)

nn_diag_dt <- plot_dt[
  forecast_id == "nn__HAR_OM__log__rolling",
  .(
    target_date,
    realized_value_rv,
    nn_forecast_rv = forecast_value_rv,
    har_forecast_rv,
    nn_error = realized_value_rv - forecast_value_rv,
    har_error = realized_value_rv - har_forecast_rv,
    nn_sq_error = se_model,
    har_sq_error = se_har,
    error_ratio_vs_har = se_model / se_har,
    cumulative_r2_oos_vs_har,
    nn_sq_error_share = se_model / sum(se_model)
  )
]

fwrite(
  nn_diag_dt[, .(
    target_date,
    realized_value_rv = round(realized_value_rv, 6),
    nn_forecast_rv = round(nn_forecast_rv, 6),
    har_forecast_rv = round(har_forecast_rv, 6),
    nn_error = round(nn_error, 6),
    har_error = round(har_error, 6),
    nn_sq_error = round(nn_sq_error, 8),
    har_sq_error = round(har_sq_error, 8),
    error_ratio_vs_har = round(error_ratio_vs_har, 3),
    cumulative_r2_oos_vs_har = round(cumulative_r2_oos_vs_har, 6),
    nn_sq_error_share = round(nn_sq_error_share, 6)
  )],
  file.path(table_dir, "main_forecast_nn_har_om_diagnostics.csv")
)

nn_start_dt <- nn_diag_dt[seq_len(min(.N, 24L))]
path_plot_dt <- data.table::melt(
  nn_start_dt,
  id.vars = "target_date",
  measure.vars = c("realized_value_rv", "nn_forecast_rv", "har_forecast_rv"),
  variable.name = "series",
  value.name = "value"
)
path_plot_dt[, panel := "Forecast and realized RV"]

error_plot_dt <- data.table::melt(
  nn_start_dt,
  id.vars = "target_date",
  measure.vars = c("nn_sq_error", "har_sq_error"),
  variable.name = "series",
  value.name = "value"
)
error_plot_dt[, panel := "Squared errors"]

nn_diag_plot_dt <- rbindlist(list(path_plot_dt, error_plot_dt), fill = TRUE)
nn_diag_plot_dt[, series := factor(
  series,
  levels = c("realized_value_rv", "nn_forecast_rv", "har_forecast_rv", "nn_sq_error", "har_sq_error"),
  labels = c("Realized RV", "NN forecast", "HAR forecast", "NN squared error", "HAR squared error")
)]
nn_diag_plot_dt[, panel := factor(panel, levels = c("Forecast and realized RV", "Squared errors"))]

nn_diag_palette <- c(
  "Realized RV" = "#000000",
  "NN forecast" = "#CC79A7",
  "HAR forecast" = "#0072B2",
  "NN squared error" = "#CC79A7",
  "HAR squared error" = "#0072B2"
)

nn_diag_plot <- ggplot(
  nn_diag_plot_dt,
  aes(x = target_date, y = value, color = series)
) +
  geom_line(linewidth = 0.9) +
  geom_point(size = 1.8, alpha = 0.9) +
  facet_wrap(~ panel, ncol = 1, scales = "free_y") +
  scale_color_manual(values = nn_diag_palette, drop = FALSE) +
  labs(
    title = "Why the NN HAR+Macro+Option Cumulative R2 Starts Low",
    subtitle = "First 24 OOS months; NN errors spike when HAR is already close to realized RV",
    x = NULL,
    y = NULL
  ) +
  base_theme

ggsave(
  filename = file.path(figure_dir, "main_forecast_nn_har_om_start_diagnostics.png"),
  plot = nn_diag_plot,
  width = 10.5,
  height = 7,
  dpi = 300
)

cat("Saved selected R2 OOS time-series data and plots:\n")
cat(" - ", file.path(table_dir, "main_forecast_r2oos_timeseries_selected.csv"), "\n", sep = "")
cat(" - ", file.path(table_dir, "main_forecast_r2oos_timeseries_selected_summary.csv"), "\n", sep = "")
cat(" - ", file.path(figure_dir, "main_forecast_r2oos_cumulative_selected.png"), "\n", sep = "")
cat(" - ", file.path(figure_dir, "main_forecast_cumulative_r2_oos_gain_vs_har_selected.png"), "\n", sep = "")
cat(" - ", file.path(figure_dir, "main_forecast_r2oos_rolling36_selected.png"), "\n", sep = "")
cat(" - ", file.path(table_dir, "main_forecast_nn_har_om_diagnostics.csv"), "\n", sep = "")
cat(" - ", file.path(figure_dir, "main_forecast_nn_har_om_start_diagnostics.png"), "\n", sep = "")
