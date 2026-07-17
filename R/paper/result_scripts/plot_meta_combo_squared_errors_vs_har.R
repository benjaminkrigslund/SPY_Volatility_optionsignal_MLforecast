library(data.table)
library(ggplot2)

source(file.path("R", "functions", "framework", "00_config.R"))
source(file.path("R", "functions", "framework", "UTILS", "helpers.R"))

config <- create_config(base_dir = getwd())

combo_path <- file.path(config$paths$results_dir, "combo_meta_ml_x_dataset_log_rolling_forecasts.csv")
all_forecasts_path <- file.path(config$paths$results_dir, "all_forecasts.rds")

if (!file.exists(combo_path)) {
  stop("Missing meta-combo forecast file: ", combo_path)
}

if (!file.exists(all_forecasts_path)) {
  stop("Missing base forecast file: ", all_forecasts_path)
}

combo_forecasts <- fread(combo_path)
all_forecasts <- as.data.table(readRDS(all_forecasts_path))
all_forecasts <- clean_forecast_table(all_forecasts)

har_forecasts <- all_forecasts[
  target_type == "log" &
    window_type == "rolling" &
    forecast_id == "har_ols__HAR__log__rolling",
  .(
    target_date,
    actual_level,
    har_forecast = forecast_level
  )
]

plot_dt <- merge(
  combo_forecasts[
    ,
    .(
      target_date,
      forecast_id,
      meta_forecast = forecast_level
    )
  ],
  har_forecasts,
  by = "target_date",
  all = FALSE
)

plot_dt[, `:=`(
  har_sq_error = (actual_level - har_forecast) ^ 2,
  meta_sq_error = (actual_level - meta_forecast) ^ 2
)]

plot_long <- rbindlist(
  list(
    plot_dt[
      ,
      .(
        target_date,
        model = "HAR",
        sq_error = har_sq_error
      )
    ],
    plot_dt[
      ,
      .(
        target_date,
        model = fifelse(
          forecast_id == "combo_meta_enet_ml_x_dataset_log_rolling",
          "Rolling meta ENet",
          "Rolling meta RF"
        ),
        sq_error = meta_sq_error
      )
    ]
  ),
  fill = TRUE
)

plot_long <- unique(plot_long)
plot_long[, target_date := as.IDate(target_date)]

plot <- ggplot(plot_long, aes(x = target_date, y = sq_error, color = model)) +
  geom_line(linewidth = 0.65, alpha = 0.85) +
  scale_color_manual(
    values = c(
      "HAR" = "#2F3437",
      "Rolling meta ENet" = "#D95F02",
      "Rolling meta RF" = "#1B9E77"
    )
  ) +
  labs(
    title = "Squared Forecast Errors vs Rolling Log HAR",
    subtitle = "Meta-combiners are trained only on prior out-of-sample forecast errors",
    x = NULL,
    y = "Squared error",
    color = NULL
  ) +
  theme_minimal(base_size = 12) +
  theme(
    legend.position = "bottom",
    panel.grid.minor = element_blank(),
    plot.title = element_text(face = "bold")
  )

output_path <- file.path(config$paths$results_dir, "combo_meta_ml_x_dataset_log_rolling_squared_errors_vs_har.png")
ggsave(
  filename = output_path,
  plot = plot,
  width = 11,
  height = 6,
  dpi = 300
)

message("Saved squared-error time-series plot to: ", output_path)
