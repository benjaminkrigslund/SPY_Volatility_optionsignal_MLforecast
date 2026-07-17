library(data.table)
library(ggplot2)

source(file.path("R", "functions", "framework", "00_config.R"))

config <- create_config(base_dir = getwd())

importance_path <- file.path(config$paths$results_dir, "combo_meta_ml_x_dataset_log_rolling_importance.csv")
forecast_path <- file.path(config$paths$results_dir, "combo_meta_ml_x_dataset_log_rolling_forecasts.csv")

if (!file.exists(importance_path)) {
  stop("Missing meta-combo importance file: ", importance_path)
}

if (!file.exists(forecast_path)) {
  stop("Missing meta-combo forecast file: ", forecast_path)
}

importance_dt <- fread(importance_path)
forecast_dt <- fread(forecast_path)

importance_dt[, target_date := as.IDate(target_date)]
forecast_dt[, target_date := as.IDate(target_date)]

latest_members <- forecast_dt[
  order(target_date),
  .SD[.N],
  by = forecast_id
][
  ,
  .(forecast_id, target_date, meta_train_rows, n_members, members)
]

enet_selected <- importance_dt[
  forecast_id == "combo_meta_enet_ml_x_dataset_log_rolling" &
    metric == "non_zero_coefficient" &
    is.finite(value)
][
  ,
  .(
    target_date,
    forecast_id,
    individual_forecast = variable,
    coefficient = value,
    abs_coefficient = abs(value)
  )
]

rf_importance <- importance_dt[
  forecast_id == "combo_meta_rf_ml_x_dataset_log_rolling" &
    metric == "variable_importance" &
    is.finite(value)
][
  ,
  .(
    target_date,
    forecast_id,
    individual_forecast = variable,
    importance = value
  )
]

enet_summary <- enet_selected[
  ,
  .(
    months_selected = .N,
    first_selected = min(target_date),
    last_selected = max(target_date),
    mean_abs_coefficient = mean(abs_coefficient),
    latest_coefficient = coefficient[which.max(target_date)]
  ),
  by = individual_forecast
][order(-months_selected, -mean_abs_coefficient)]

rf_summary <- rf_importance[
  ,
  .(
    months_used = .N,
    first_used = min(target_date),
    last_used = max(target_date),
    mean_importance = mean(importance),
    latest_importance = importance[which.max(target_date)]
  ),
  by = individual_forecast
][order(-mean_importance)]

enet_selection_path <- file.path(config$paths$results_dir, "combo_meta_enet_picked_forecasts.csv")
rf_importance_path <- file.path(config$paths$results_dir, "combo_meta_rf_forecast_importance.csv")
latest_members_path <- file.path(config$paths$results_dir, "combo_meta_latest_members.csv")
enet_summary_path <- file.path(config$paths$results_dir, "combo_meta_enet_picked_forecasts_summary.csv")
rf_summary_path <- file.path(config$paths$results_dir, "combo_meta_rf_forecast_importance_summary.csv")

fwrite(enet_selected, enet_selection_path)
fwrite(rf_importance, rf_importance_path)
fwrite(latest_members, latest_members_path)
fwrite(enet_summary, enet_summary_path)
fwrite(rf_summary, rf_summary_path)

top_enet <- enet_summary[1:min(.N, 20L), individual_forecast]
enet_heatmap_dt <- enet_selected[individual_forecast %in% top_enet]
enet_heatmap_dt[, individual_forecast := factor(individual_forecast, levels = rev(top_enet))]

enet_plot <- ggplot(
  enet_heatmap_dt,
  aes(x = target_date, y = individual_forecast, fill = coefficient)
) +
  geom_tile() +
  scale_fill_gradient2(
    low = "#2166AC",
    mid = "white",
    high = "#B2182B",
    midpoint = 0
  ) +
  labs(
    title = "Rolling Meta-ENet Picked Forecasts",
    subtitle = "Colored cells are non-zero coefficients in the forecast-combination model",
    x = NULL,
    y = NULL,
    fill = "Coefficient"
  ) +
  theme_minimal(base_size = 11) +
  theme(
    panel.grid = element_blank(),
    plot.title = element_text(face = "bold")
  )

top_rf <- rf_summary[1:min(.N, 20L), individual_forecast]
rf_heatmap_dt <- rf_importance[individual_forecast %in% top_rf]
rf_heatmap_dt[
  ,
  scaled_importance := importance / max(importance, na.rm = TRUE),
  by = target_date
]
rf_heatmap_dt[, individual_forecast := factor(individual_forecast, levels = rev(top_rf))]

rf_plot <- ggplot(
  rf_heatmap_dt,
  aes(x = target_date, y = individual_forecast, fill = scaled_importance)
) +
  geom_tile() +
  scale_fill_gradient(low = "white", high = "#1B9E77") +
  labs(
    title = "Rolling Meta-RF Forecast Importance",
    subtitle = "Importance is scaled within each monthly refit",
    x = NULL,
    y = NULL,
    fill = "Scaled importance"
  ) +
  theme_minimal(base_size = 11) +
  theme(
    panel.grid = element_blank(),
    plot.title = element_text(face = "bold")
  )

enet_plot_path <- file.path(config$paths$results_dir, "combo_meta_enet_picked_forecasts_heatmap.png")
rf_plot_path <- file.path(config$paths$results_dir, "combo_meta_rf_forecast_importance_heatmap.png")

ggsave(enet_plot_path, enet_plot, width = 11, height = 7, dpi = 300)
ggsave(rf_plot_path, rf_plot, width = 11, height = 7, dpi = 300)

message("Saved ENet picked forecast table to: ", enet_selection_path)
message("Saved RF importance table to: ", rf_importance_path)
message("Saved latest member table to: ", latest_members_path)
message("Saved ENet heatmap to: ", enet_plot_path)
message("Saved RF heatmap to: ", rf_plot_path)

cat("\nLATEST ELIGIBLE MEMBERS\n")
print(latest_members)

cat("\nTOP META-ENET PICKS\n")
print(enet_summary[1:min(.N, 20L)])

cat("\nTOP META-RF IMPORTANCES\n")
print(rf_summary[1:min(.N, 20L)])
