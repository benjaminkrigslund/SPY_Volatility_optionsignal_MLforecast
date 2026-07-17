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

selected_specs <- data.table(
  forecast_id = c(
    "enet__HAR_O__log__rolling",
    "rf__HAR_O__log__rolling",
    "rf__HAR_OM__log__rolling",
    "nn__HAR_OM__log__rolling",
    "combo_equal_weight_har_across_ml_har_augmented_log_rolling",
    "combo_equal_weight_har_o_across_ml_har_augmented_log_rolling",
    "combo_equal_weight_har_m_across_ml_har_augmented_log_rolling",
    "combo_equal_weight_har_om_across_ml_har_augmented_log_rolling",
    "combo_equal_weight_enet_across_har_augmented_datasets_log_rolling",
    "combo_equal_weight_pca_across_har_augmented_datasets_log_rolling",
    "combo_equal_weight_rf_across_har_augmented_datasets_log_rolling",
    "combo_equal_weight_nn_across_har_augmented_datasets_log_rolling",
    "combo_equal_weight_all_har_augmented_ml_x_dataset_log_rolling",
    "stacked_rf_on_har_augmented_forecasts_log_rolling",
    "stacked_enet_on_har_augmented_forecasts_log_rolling"
  ),
  plot_label = c(
    "Elastic Net | HAR+Option",
    "Random Forest | HAR+Option",
    "Random Forest | HAR+Macro+Option",
    "Neural Network | HAR+Macro+Option",
    "Equal Weight | HAR",
    "Equal Weight | HAR+Option",
    "Equal Weight | HAR+Macro",
    "Equal Weight | HAR+Macro+Option",
    "Elastic Net EW | Multiple",
    "PCA EW | Multiple",
    "Random Forest EW | Multiple",
    "Neural Network EW | Multiple",
    "Equal Weight | All ML",
    "Stacked Random Forest",
    "Stacked Elastic Net"
  ),
  plot_group = c(
    "Individual models",
    "Individual models",
    "Individual models",
    "Individual models",
    "Info-set equal weights",
    "Info-set equal weights",
    "Info-set equal weights",
    "Info-set equal weights",
    "Method equal weights",
    "Method equal weights",
    "Method equal weights",
    "Method equal weights",
    "All-model forecast combinations",
    "All-model forecast combinations",
    "All-model forecast combinations"
  ),
  plot_order = seq_len(15L)
)

missing_ids <- setdiff(selected_specs$forecast_id, unique(panel_120$forecast_id))
if (length(missing_ids) > 0L) {
  stop("Selected forecast IDs are missing from the panel: ", paste(missing_ids, collapse = ", "))
}

har_dt <- panel_120[
  forecast_id == "har_ols__HAR__log__rolling",
  .(target_date, har_forecast_rv = forecast_value_rv)
]

if (nrow(har_dt) == 0L) {
  stop("Could not find HAR benchmark series in the 120-month forecast panel.")
}

error_dt <- merge(
  panel_120[forecast_id %in% selected_specs$forecast_id],
  har_dt,
  by = "target_date",
  all.x = TRUE
)
error_dt <- merge(error_dt, selected_specs, by = "forecast_id", all.x = TRUE)
setorder(error_dt, plot_order, target_date)

error_dt[, `:=`(
  model_error = realized_value_rv - forecast_value_rv,
  har_error = realized_value_rv - har_forecast_rv
)]
error_dt[, `:=`(
  model_abs_error = abs(model_error),
  har_abs_error = abs(har_error),
  model_sq_error = model_error ^ 2,
  har_sq_error = har_error ^ 2
)]
error_dt[, `:=`(
  abs_error_gain_vs_har = har_abs_error - model_abs_error,
  sq_error_gain_vs_har = har_sq_error - model_sq_error,
  cumulative_abs_error_gain_vs_har = cumsum(har_abs_error - model_abs_error),
  cumulative_sq_error_gain_vs_har = cumsum(har_sq_error - model_sq_error),
  rolling12_model_mae = frollmean(model_abs_error, n = 12L, align = "right"),
  rolling12_har_mae = frollmean(har_abs_error, n = 12L, align = "right")
), by = forecast_id]
error_dt[, rolling12_mae_gain_vs_har := rolling12_har_mae - rolling12_model_mae]

error_dt[, plot_label := factor(plot_label, levels = selected_specs$plot_label)]
error_dt[, plot_group := factor(
  plot_group,
  levels = c(
    "Individual models",
    "Info-set equal weights",
    "Method equal weights",
    "All-model forecast combinations"
  )
)]

reported_cols <- c(
  "realized_value_rv",
  "forecast_value_rv",
  "har_forecast_rv",
  "model_error",
  "har_error",
  "model_abs_error",
  "har_abs_error",
  "model_sq_error",
  "har_sq_error",
  "abs_error_gain_vs_har",
  "sq_error_gain_vs_har",
  "cumulative_abs_error_gain_vs_har",
  "cumulative_sq_error_gain_vs_har",
  "rolling12_model_mae",
  "rolling12_har_mae",
  "rolling12_mae_gain_vs_har"
)

export_dt <- copy(error_dt[, c(
  "target_date",
  "forecast_id",
  "plot_label",
  "plot_group",
  reported_cols
), with = FALSE])
export_dt[, (reported_cols) := lapply(.SD, round, digits = 8), .SDcols = reported_cols]
fwrite(export_dt, file.path(table_dir, "main_forecast_error_timeseries_selected.csv"))

summary_dt <- error_dt[
  ,
  .(
    model_mae = round(mean(model_abs_error, na.rm = TRUE), 6),
    har_mae = round(mean(har_abs_error, na.rm = TRUE), 6),
    mae_gain_vs_har = round(mean(abs_error_gain_vs_har, na.rm = TRUE), 6),
    model_mse = round(mean(model_sq_error, na.rm = TRUE), 6),
    har_mse = round(mean(har_sq_error, na.rm = TRUE), 6),
    mse_gain_vs_har = round(mean(sq_error_gain_vs_har, na.rm = TRUE), 6),
    final_cumulative_abs_error_gain_vs_har = round(last(cumulative_abs_error_gain_vs_har), 6),
    final_cumulative_sq_error_gain_vs_har = round(last(cumulative_sq_error_gain_vs_har), 6)
  ),
  by = .(plot_order, plot_group, plot_label)
][order(plot_order)]
fwrite(summary_dt, file.path(table_dir, "main_forecast_error_timeseries_selected_summary.csv"))

line_palette <- c(
  "Elastic Net | HAR+Option" = "#0072B2",
  "Random Forest | HAR+Option" = "#D55E00",
  "Random Forest | HAR+Macro+Option" = "#009E73",
  "Neural Network | HAR+Macro+Option" = "#CC79A7",
  "Equal Weight | HAR" = "#8C8C8C",
  "Equal Weight | HAR+Option" = "#E69F00",
  "Equal Weight | HAR+Macro" = "#8B8B00",
  "Equal Weight | HAR+Macro+Option" = "#44AA99",
  "Elastic Net EW | Multiple" = "#332288",
  "PCA EW | Multiple" = "#AA4499",
  "Random Forest EW | Multiple" = "#56B4E9",
  "Neural Network EW | Multiple" = "#117733",
  "Equal Weight | All ML" = "#000000",
  "Stacked Random Forest" = "#7F3C8D",
  "Stacked Elastic Net" = "#11A579"
)

base_theme <- theme_minimal(base_size = 11) +
  theme(
    legend.position = "bottom",
    legend.title = element_blank(),
    legend.text = element_text(size = 8),
    legend.key.width = grid::unit(14, "pt"),
    panel.grid.minor = element_blank(),
    plot.title = element_text(face = "bold"),
    strip.text = element_text(face = "bold"),
    axis.title.y = element_text(margin = margin(r = 8))
  )
legend_guides <- guides(color = guide_legend(nrow = 3, byrow = TRUE))

crisis_start <- as.Date("2020-03-01")
crisis_end <- as.Date("2020-12-31")

cumulative_gain_plot <- ggplot(
  error_dt,
  aes(x = target_date, y = cumulative_sq_error_gain_vs_har, color = plot_label)
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
  facet_wrap(~ plot_group, ncol = 1, scales = "free_y") +
  scale_color_manual(values = line_palette, drop = FALSE) +
  legend_guides +
  labs(
    title = "Cumulative Squared-Error Gain versus HAR",
    subtitle = "Selected 120-month rolling log-RV forecasts; shaded area marks Mar-Dec 2020",
    x = NULL,
    y = "Cumulative HAR SE - model SE"
  ) +
  base_theme

cumulative_abs_gain_plot <- ggplot(
  error_dt,
  aes(x = target_date, y = cumulative_abs_error_gain_vs_har, color = plot_label)
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
  facet_wrap(~ plot_group, ncol = 1, scales = "free_y") +
  scale_color_manual(values = line_palette, drop = FALSE) +
  legend_guides +
  labs(
    title = "Cumulative Absolute-Error Gain versus HAR",
    subtitle = "Selected 120-month rolling log-RV forecasts; shaded area marks Mar-Dec 2020",
    x = NULL,
    y = "Cumulative HAR AE - model AE"
  ) +
  base_theme

rolling_mae_gain_plot <- ggplot(
  error_dt[is.finite(rolling12_mae_gain_vs_har)],
  aes(x = target_date, y = rolling12_mae_gain_vs_har, color = plot_label)
) +
  geom_hline(yintercept = 0, linetype = "dashed", color = "grey50", linewidth = 0.35) +
  geom_line(linewidth = 0.85, alpha = 0.95) +
  facet_wrap(~ plot_group, ncol = 1, scales = "free_y") +
  scale_color_manual(values = line_palette, drop = FALSE) +
  legend_guides +
  labs(
    title = "Trailing 12-Month MAE Gain versus HAR",
    subtitle = "Positive values mean lower average absolute forecast error than HAR over the trailing year",
    x = NULL,
    y = "HAR MAE - model MAE"
  ) +
  base_theme

abs_error_plot <- ggplot(
  error_dt,
  aes(x = target_date, y = model_abs_error, color = plot_label)
) +
  geom_line(linewidth = 0.75, alpha = 0.9) +
  facet_wrap(~ plot_group, ncol = 1, scales = "free_y") +
  scale_color_manual(values = line_palette, drop = FALSE) +
  legend_guides +
  labs(
    title = "Absolute Forecast Errors",
    subtitle = "Selected 120-month rolling log-RV forecasts evaluated on RV scale",
    x = NULL,
    y = "|realized RV - forecast RV|"
  ) +
  base_theme

ggsave(
  filename = file.path(figure_dir, "main_forecast_error_cumulative_sq_gain_selected.png"),
  plot = cumulative_gain_plot,
  width = 11,
  height = 11,
  dpi = 300
)

ggsave(
  filename = file.path(figure_dir, "main_forecast_error_cumulative_abs_gain_selected.png"),
  plot = cumulative_abs_gain_plot,
  width = 11,
  height = 11,
  dpi = 300
)

ggsave(
  filename = file.path(figure_dir, "main_forecast_error_rolling12_mae_gain_selected.png"),
  plot = rolling_mae_gain_plot,
  width = 11,
  height = 11,
  dpi = 300
)

ggsave(
  filename = file.path(figure_dir, "main_forecast_error_absolute_selected.png"),
  plot = abs_error_plot,
  width = 11,
  height = 11,
  dpi = 300
)

cat("Saved selected error time-series data and plots:\n")
cat(" - ", file.path(table_dir, "main_forecast_error_timeseries_selected.csv"), "\n", sep = "")
cat(" - ", file.path(table_dir, "main_forecast_error_timeseries_selected_summary.csv"), "\n", sep = "")
cat(" - ", file.path(figure_dir, "main_forecast_error_cumulative_sq_gain_selected.png"), "\n", sep = "")
cat(" - ", file.path(figure_dir, "main_forecast_error_cumulative_abs_gain_selected.png"), "\n", sep = "")
cat(" - ", file.path(figure_dir, "main_forecast_error_rolling12_mae_gain_selected.png"), "\n", sep = "")
cat(" - ", file.path(figure_dir, "main_forecast_error_absolute_selected.png"), "\n", sep = "")
