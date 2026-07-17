library(data.table)
library(ggplot2)

source(file.path("R", "functions", "framework", "00_config.R"))
source(file.path("R", "functions", "framework", "UTILS", "helpers.R"))
source(file.path("R", "functions", "framework", "01_load_data.R"))
source(file.path("R", "functions", "framework", "FEATURES", "feature_sets.R"))
source(file.path("R", "functions", "framework", "MODELS", "model_enet.R"))
source(file.path("R", "functions", "framework", "MODELS", "model_pca.R"))
source(file.path("R", "functions", "framework", "MODELS", "model_pls.R"))
source(file.path("R", "functions", "framework", "MODELS", "model_rf.R"))
source(file.path("R", "functions", "framework", "MODELS", "model_nn.R"))
source(file.path("R", "functions", "framework", "MODELS", "model_registry.R"))
source(file.path("R", "functions", "framework", "FORECASTS", "run_forecast.R"))

required_packages <- c("data.table", "ggplot2", "glmnet", "pls", "ranger", "nnet")
missing_packages <- required_packages[!vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)]

if (length(missing_packages) > 0L) {
  stop(
    "Install required packages before running this script: ",
    paste(missing_packages, collapse = ", ")
  )
}

config <- create_config(base_dir = getwd())
master_data <- load_master_data(config)
option_vars <- resolve_feature_columns(master_data, config, "option")

clean_importance_path <- file.path(
  config$paths$results_dir,
  "ml_option_clean_feature_importance_log_rolling.rds"
)

if (file.exists(clean_importance_path)) {
  clean_importance <- as.data.table(readRDS(clean_importance_path))
} else {
  spec_grid <- CJ(
    model_type = c("enet", "pca", "pls", "rf", "nn"),
    feature_set = c("O", "OM"),
    sorted = FALSE
  )

  forecast_runs <- vector("list", nrow(spec_grid))

  for (i in seq_len(nrow(spec_grid))) {
    spec <- spec_grid[i]
    message(
      "[", i, "/", nrow(spec_grid), "] Collecting importance for ",
      spec$model_type, " | ", spec$feature_set, " | log | rolling"
    )

    forecast_runs[[i]] <- run_forecast(
      data = master_data,
      model_type = spec$model_type,
      feature_set = spec$feature_set,
      window_type = "rolling",
      initial_window = config$forecasting$initial_window,
      refit_every = config$forecasting$refit_every,
      target_type = "log",
      config = config
    )
  }

  clean_importance <- rbindlist(lapply(forecast_runs, `[[`, "importance"), fill = TRUE)
  saveRDS(clean_importance, clean_importance_path)
  fwrite(
    clean_importance,
    file.path(config$paths$results_dir, "ml_option_clean_feature_importance_log_rolling.csv")
  )
}

all_importance_path <- file.path(config$paths$results_dir, "all_variable_importance.rds")
if (!file.exists(all_importance_path)) {
  stop("Missing saved variable-importance file: ", all_importance_path)
}

existing_importance <- as.data.table(readRDS(all_importance_path))
har_augmented_importance <- existing_importance[
  target_type == "log" &
    window_type == "rolling" &
    feature_set %in% c("HAR_O", "HAR_OM") &
    model_type %in% c("enet", "pca", "pls", "rf", "nn")
]

option_importance <- rbindlist(
  list(clean_importance, har_augmented_importance),
  fill = TRUE
)

option_importance <- option_importance[
  target_type == "log" &
    window_type == "rolling" &
    feature_set %in% c("O", "OM", "HAR_O", "HAR_OM") &
    variable %in% option_vars
]

option_importance[, refit_key := as.character(refit_origin)]

total_refits <- option_importance[
  ,
  .(total_refits = uniqueN(refit_key)),
  by = .(model_type, feature_set)
]

enet_selection <- option_importance[
  model_type == "enet" &
    metric == "non_zero_coefficient" &
    is.finite(value) &
    abs(value) > 0
][
  ,
  .(
    selected_refits = uniqueN(refit_key),
    mean_abs_coefficient = mean(abs(value), na.rm = TRUE),
    median_abs_coefficient = median(abs(value), na.rm = TRUE),
    first_selected = min(refit_origin),
    last_selected = max(refit_origin)
  ),
  by = .(feature_set, variable)
]

enet_selection <- merge(
  enet_selection,
  total_refits[model_type == "enet"],
  by = "feature_set",
  all.x = TRUE
)
enet_selection[, selection_rate := selected_refits / total_refits]
setorder(enet_selection, -selection_rate, -mean_abs_coefficient)

rf_importance <- option_importance[
  model_type == "rf" &
    metric == "variable_importance" &
    is.finite(value)
]
rf_importance[
  ,
  rank_in_refit := frank(-value, ties.method = "min"),
  by = .(feature_set, refit_key)
]

rf_summary <- rf_importance[
  ,
  .(
    refits_used = uniqueN(refit_key),
    top5_refits = uniqueN(refit_key[rank_in_refit <= 5]),
    mean_importance = mean(value, na.rm = TRUE),
    median_importance = median(value, na.rm = TRUE),
    mean_rank = mean(rank_in_refit, na.rm = TRUE)
  ),
  by = .(feature_set, variable)
]
rf_summary <- merge(
  rf_summary,
  total_refits[model_type == "rf"],
  by = "feature_set",
  all.x = TRUE
)
rf_summary[, top5_rate := top5_refits / total_refits]
setorder(rf_summary, -top5_rate, mean_rank, -mean_importance)

loading_importance <- option_importance[
  model_type %in% c("pca", "pls") &
    metric == "loading" &
    is.finite(value)
]
loading_importance[
  ,
  abs_loading := abs(value)
]
loading_importance[
  ,
  rank_in_component := frank(-abs_loading, ties.method = "min"),
  by = .(model_type, feature_set, refit_key, component)
]

loading_summary <- loading_importance[
  ,
  .(
    loading_rows = .N,
    top5_component_hits = sum(rank_in_component <= 5, na.rm = TRUE),
    mean_abs_loading = mean(abs_loading, na.rm = TRUE),
    median_abs_loading = median(abs_loading, na.rm = TRUE)
  ),
  by = .(model_type, feature_set, variable)
]
setorder(loading_summary, model_type, feature_set, -top5_component_hits, -mean_abs_loading)

combined_score <- rbindlist(
  list(
    enet_selection[
      ,
      .(
        evidence_type = "enet_nonzero",
        feature_set,
        variable,
        score = selection_rate,
        secondary_score = mean_abs_coefficient
      )
    ],
    rf_summary[
      ,
      .(
        evidence_type = "rf_top5_importance",
        feature_set,
        variable,
        score = top5_rate,
        secondary_score = mean_importance
      )
    ]
  ),
  fill = TRUE
)

overall_option_summary <- combined_score[
  ,
  .(
    mean_score = mean(score, na.rm = TRUE),
    max_score = max(score, na.rm = TRUE),
    evidence_count = .N
  ),
  by = variable
][order(-mean_score, -max_score)]

output_dir <- config$paths$results_dir
fwrite(
  enet_selection,
  file.path(output_dir, "option_variable_enet_selection_log_rolling.csv")
)
fwrite(
  rf_summary,
  file.path(output_dir, "option_variable_rf_importance_log_rolling.csv")
)
fwrite(
  loading_summary,
  file.path(output_dir, "option_variable_pca_pls_loading_summary_log_rolling.csv")
)
fwrite(
  overall_option_summary,
  file.path(output_dir, "option_variable_overall_selection_summary_log_rolling.csv")
)

plot_dt <- enet_selection[
  ,
  .SD[which.max(selection_rate)],
  by = variable
][order(-selection_rate, -mean_abs_coefficient)][1:min(.N, 15L)]
plot_dt[, variable := factor(variable, levels = rev(variable))]

enet_plot <- ggplot(plot_dt, aes(x = selection_rate, y = variable)) +
  geom_col(fill = "#D95F02", width = 0.75) +
  scale_x_continuous(labels = scales::percent_format(accuracy = 1)) +
  labs(
    title = "Most Frequently Selected Option Variables",
    subtitle = "Rolling log ENet models; best selection rate across O, OM, HAR+O, HAR+O+M",
    x = "Selection rate across refits",
    y = NULL
  ) +
  theme_minimal(base_size = 11) +
  theme(
    panel.grid.minor = element_blank(),
    plot.title = element_text(face = "bold")
  )

rf_plot_dt <- rf_summary[
  ,
  .SD[which.max(top5_rate)],
  by = variable
][order(-top5_rate, mean_rank)][1:min(.N, 15L)]
rf_plot_dt[, variable := factor(variable, levels = rev(variable))]

rf_plot <- ggplot(rf_plot_dt, aes(x = top5_rate, y = variable)) +
  geom_col(fill = "#1B9E77", width = 0.75) +
  scale_x_continuous(labels = scales::percent_format(accuracy = 1)) +
  labs(
    title = "Option Variables Most Often Top-5 in RF Importance",
    subtitle = "Rolling log RF models; best top-5 rate across O, OM, HAR+O, HAR+O+M",
    x = "Top-5 importance rate across refits",
    y = NULL
  ) +
  theme_minimal(base_size = 11) +
  theme(
    panel.grid.minor = element_blank(),
    plot.title = element_text(face = "bold")
  )

ggsave(
  file.path(output_dir, "option_variable_enet_selection_log_rolling.png"),
  enet_plot,
  width = 10,
  height = 6,
  dpi = 300
)
ggsave(
  file.path(output_dir, "option_variable_rf_top5_importance_log_rolling.png"),
  rf_plot,
  width = 10,
  height = 6,
  dpi = 300
)

cat("\nTOP ENET OPTION SELECTIONS\n")
print(enet_selection[1:min(.N, 20L)])

cat("\nTOP RF OPTION IMPORTANCE FREQUENCIES\n")
print(rf_summary[1:min(.N, 20L)])

cat("\nOVERALL OPTION SUMMARY FROM ENET + RF SIGNALS\n")
print(overall_option_summary[1:min(.N, 20L)])
