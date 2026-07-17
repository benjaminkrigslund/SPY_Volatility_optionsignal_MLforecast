library(data.table)
library(ggplot2)

source(file.path("R", "functions", "framework", "00_config.R"))
source(file.path("R", "functions", "framework", "UTILS", "helpers.R"))
source(file.path("R", "functions", "framework", "01_load_data.R"))
source(file.path("R", "functions", "framework", "FEATURES", "feature_sets.R"))
source(file.path("R", "functions", "framework", "MODELS", "model_har.R"))
source(file.path("R", "functions", "framework", "MODELS", "model_enet.R"))
source(file.path("R", "functions", "framework", "MODELS", "model_pca.R"))
source(file.path("R", "functions", "framework", "MODELS", "model_rf.R"))
source(file.path("R", "functions", "framework", "MODELS", "model_nn.R"))
source(file.path("R", "functions", "framework", "MODELS", "model_registry.R"))
source(file.path("R", "functions", "framework", "FORECASTS", "run_forecast.R"))
source(file.path("R", "functions", "framework", "FORECASTS", "combine_forecasts.R"))

required_packages <- c("data.table", "ggplot2", "glmnet", "ranger", "nnet")
missing_packages <- required_packages[!vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)]

if (length(missing_packages) > 0L) {
  stop(
    "Install required packages before running this script: ",
    paste(missing_packages, collapse = ", ")
  )
}

config <- create_config(base_dir = getwd())
master_data <- load_master_data(config)

target_feature_sets <- c("HAR", "HAR_O", "HAR_M", "HAR_OM")
ml_methods <- c("enet", "pca", "rf", "nn")
base_refit_every <- 1L
n_har_augmented_ml_forecasts <- length(ml_methods) * length(target_feature_sets)

build_stacking_frame <- function(forecast_dt) {
  forecast_wide <- dcast(
    forecast_dt,
    target_date ~ forecast_id,
    value.var = "forecast_transformed"
  )

  actual_dt <- forecast_dt[
    ,
    .(
      origin_date = first(origin_date),
      actual_transformed = first(actual_transformed),
      actual_level = first(actual_level),
      benchmark_forecast = first(benchmark_forecast)
    ),
    by = target_date
  ]

  stacking_dt <- merge(actual_dt, forecast_wide, by = "target_date", all = FALSE)
  setorder(stacking_dt, target_date)
  stacking_dt[]
}

run_stacked_forecasts <- function(stacking_dt,
                                  meta_model,
                                  config,
                                  combination_window = 120L,
                                  min_history = 36L,
                                  min_features = 2L) {
  feature_cols <- setdiff(
    names(stacking_dt),
    c("target_date", "origin_date", "actual_transformed", "actual_level", "benchmark_forecast")
  )

  model_config <- get_model_config(meta_model, config)
  forecast_rows <- vector("list", nrow(stacking_dt))
  out_i <- 0L

  for (i in seq_len(nrow(stacking_dt))) {
    current_date <- stacking_dt$target_date[i]
    history_dt <- stacking_dt[target_date < current_date]

    if (nrow(history_dt) > combination_window) {
      history_dt <- tail(history_dt, combination_window)
    }

    current_row <- stacking_dt[i]
    available_now <- feature_cols[vapply(
      feature_cols,
      function(col) is.finite(current_row[[col]]),
      logical(1)
    )]

    if (length(available_now) < min_features) {
      next
    }

    history_counts <- vapply(
      available_now,
      function(col) sum(is.finite(history_dt[[col]]) & is.finite(history_dt$actual_transformed)),
      integer(1)
    )
    candidate_features <- available_now[history_counts >= min_history]

    if (length(candidate_features) < min_features) {
      next
    }

    train_dt <- history_dt[, c("actual_transformed", candidate_features), with = FALSE]
    train_dt <- train_dt[complete.cases(train_dt)]

    if (nrow(train_dt) < min_history) {
      next
    }

    X_train <- as.matrix(train_dt[, ..candidate_features])
    y_train <- train_dt$actual_transformed
    X_test <- as.matrix(current_row[, ..candidate_features])

    fitted_model <- tryCatch(
      fit_model(
        model_type = meta_model,
        X_train = X_train,
        y_train = y_train,
        config = model_config,
        feature_names = candidate_features
      ),
      error = function(e) NULL
    )

    if (is.null(fitted_model)) {
      next
    }

    pred_transformed <- predict_model(fitted_model, X_test = X_test, config = model_config)
    fitted_train <- predict_model(fitted_model, X_test = X_train, config = model_config)

    log_resid_var <- stats::var(y_train - fitted_train, na.rm = TRUE)
    if (!is.finite(log_resid_var) || log_resid_var < 0) {
      log_resid_var <- 0
    }

    forecast_level <- inverse_target_transform(
      pred_transformed,
      target_type = "log",
      log_resid_var = log_resid_var
    )

    forecast_floor <- get_level_forecast_floor(
      inverse_target_transform(y_train, target_type = "log", log_resid_var = 0),
      config
    )
    forecast_level <- enforce_positive_forecast(forecast_level, floor_value = forecast_floor)

    out_i <- out_i + 1L
    forecast_rows[[out_i]] <- data.table(
      origin_date = current_row$origin_date,
      target_date = current_date,
      model_type = paste0("stacked_", meta_model),
      feature_set = "HAR_AUGMENTED_STACK",
      window_type = "rolling",
      target_type = "log",
      forecast_transformed = as.numeric(pred_transformed),
      forecast_level = as.numeric(forecast_level),
      benchmark_forecast = current_row$benchmark_forecast,
      actual_transformed = current_row$actual_transformed,
      actual_level = current_row$actual_level,
      refit_every = 1L,
      initial_window = min_history,
      forecast_id = paste0("stacked_", meta_model, "_on_har_augmented_forecasts_log_rolling"),
      combination_window = combination_window,
      meta_train_rows = nrow(train_dt),
      n_members = length(candidate_features),
      members = paste(candidate_features, collapse = " | "),
      log_resid_var = log_resid_var
    )
  }

  if (out_i == 0L) {
    return(data.table())
  }

  rbindlist(forecast_rows[seq_len(out_i)], fill = TRUE)
}

base_specs <- rbindlist(
  list(
    data.table(model_type = "har_ols", feature_set = "HAR"),
    CJ(model_type = ml_methods, feature_set = target_feature_sets, sorted = FALSE)
  ),
  fill = TRUE
)

base_runs <- vector("list", nrow(base_specs))

for (i in seq_len(nrow(base_specs))) {
  spec <- base_specs[i]
  message(
    "[", i, "/", nrow(base_specs), "] Running ",
    spec$model_type, " | ", spec$feature_set, " | log | rolling | refit_every=",
    base_refit_every
  )

  base_runs[[i]] <- run_forecast(
    data = master_data,
    model_type = spec$model_type,
    feature_set = spec$feature_set,
    window_type = "rolling",
    initial_window = config$forecasting$initial_window,
    refit_every = base_refit_every,
    target_type = "log",
    config = config
  )
}

base_forecasts <- rbindlist(lapply(base_runs, `[[`, "forecasts"), fill = TRUE)
base_forecasts <- clean_forecast_table(base_forecasts)
base_importance <- rbindlist(lapply(base_runs, `[[`, "importance"), fill = TRUE)

individual_target_lists <- lapply(
  split(base_forecasts, by = "forecast_id", keep.by = FALSE),
  function(dt) unique(dt$target_date)
)

common_targets <- Reduce(intersect, individual_target_lists)
aligned_panel <- base_forecasts[target_date %in% common_targets]

feature_model_ids <- lapply(
  target_feature_sets,
  function(feature_set_value) {
    sort(unique(aligned_panel[feature_set == feature_set_value & model_type %in% ml_methods, forecast_id]))
  }
)
names(feature_model_ids) <- target_feature_sets

method_model_ids <- lapply(
  ml_methods,
  function(method_value) {
    sort(unique(aligned_panel[model_type == method_value & feature_set %in% target_feature_sets, forecast_id]))
  }
)
names(method_model_ids) <- ml_methods

combo_specs <- c(
  setNames(
    lapply(target_feature_sets, function(fs) feature_model_ids[[fs]]),
    paste0("combo_equal_weight_", tolower(target_feature_sets), "_across_ml_har_augmented_log_rolling")
  ),
  setNames(
    lapply(ml_methods, function(m) method_model_ids[[m]]),
    paste0("combo_equal_weight_", ml_methods, "_across_har_augmented_datasets_log_rolling")
  ),
  list(
    combo_equal_weight_all_har_augmented_ml_x_dataset_log_rolling =
      sort(unique(aligned_panel[model_type %in% ml_methods, forecast_id]))
  )
)

combo_forecasts <- rbindlist(
  lapply(
    names(combo_specs),
    function(combo_name) {
      member_ids <- combo_specs[[combo_name]]
      if (length(member_ids) == 0L) {
        return(data.table())
      }

      combo_dt <- combine_forecasts(
        forecast_df = aligned_panel[forecast_id %in% member_ids],
        method = "equal_weight",
        selected_models = member_ids,
        combination_name = combo_name
      )

      combo_dt[, n_members := length(member_ids)]
      combo_dt[]
    }
  ),
  fill = TRUE
)

stacking_dt <- build_stacking_frame(aligned_panel[model_type %in% ml_methods])
stacked_forecasts <- rbindlist(
  lapply(
    c("enet", "rf"),
    function(meta_model) {
      run_stacked_forecasts(
        stacking_dt = stacking_dt,
        meta_model = meta_model,
        config = config,
        combination_window = config$forecasting$initial_window,
        min_history = 36L,
        min_features = 2L
      )
    }
  ),
  fill = TRUE
)

stacked_target_lists <- lapply(
  split(stacked_forecasts, by = "forecast_id", keep.by = FALSE),
  function(dt) unique(dt$target_date)
)
stacked_common_targets <- Reduce(intersect, stacked_target_lists)

aligned_panel <- aligned_panel[target_date %in% stacked_common_targets]
combo_forecasts <- combo_forecasts[target_date %in% stacked_common_targets]
stacked_forecasts <- stacked_forecasts[target_date %in% stacked_common_targets]

full_forecast_panel <- rbindlist(
  list(aligned_panel, combo_forecasts, stacked_forecasts),
  fill = TRUE
)

selected_models <- data.table(
  forecast_id = c(
    "har_ols__HAR__log__rolling",
    "enet__HAR_O__log__rolling",
    "rf__HAR_O__log__rolling",
    "combo_equal_weight_har_o_across_ml_har_augmented_log_rolling",
    "stacked_enet_on_har_augmented_forecasts_log_rolling"
  ),
  model_label = c(
    "HAR OLS",
    "ENET HAR + Option",
    "RF HAR + Option",
    "EW Across ML HAR + Option",
    sprintf("Stacked ENET (%d ML forecasts)", n_har_augmented_ml_forecasts)
  )
)

plot_panel <- rbindlist(
  list(
    aligned_panel[, .(forecast_id, target_date, actual_level, forecast_level)],
    combo_forecasts[, .(forecast_id, target_date, actual_level, forecast_level)],
    stacked_forecasts[, .(forecast_id, target_date, actual_level, forecast_level)]
  ),
  fill = TRUE
)

plot_panel <- merge(plot_panel, selected_models, by = "forecast_id", all = FALSE)
plot_panel[, abs_error := abs(actual_level - forecast_level)]
plot_panel[, sq_error := (actual_level - forecast_level) ^ 2]
setorder(plot_panel, model_label, target_date)
plot_panel[, rolling_12m_mae := frollmean(abs_error, n = 12L, align = "right"), by = model_label]

error_plot <- ggplot(
  plot_panel[!is.na(rolling_12m_mae)],
  aes(x = target_date, y = rolling_12m_mae, color = model_label)
) +
  geom_line(linewidth = 0.75, alpha = 0.9) +
  scale_color_manual(
    values = setNames(
      c("#2F3437", "#D95F02", "#1B9E77", "#7570B3", "#E6AB02"),
      c(
        "HAR OLS",
        "ENET HAR + Option",
        "RF HAR + Option",
        "EW Across ML HAR + Option",
        sprintf("Stacked ENET (%d ML forecasts)", n_har_augmented_ml_forecasts)
      )
    )
  ) +
  labs(
    title = "12-Month Rolling Mean Absolute Forecast Error",
    subtitle = "Common 155-date monthly-refit sample for HAR-augmented models",
    x = NULL,
    y = "Rolling 12-month MAE",
    color = NULL
  ) +
  theme_minimal(base_size = 12) +
  theme(
    legend.position = "bottom",
    panel.grid.minor = element_blank(),
    plot.title = element_text(face = "bold")
  )

error_plot_output <- file.path(
  config$paths$output_dir,
  "har_augmented_common155_monthly_refit_rolling12m_mae.png"
)
error_csv_output <- file.path(
  config$paths$results_dir,
  "har_augmented_common155_monthly_refit_error_series.csv"
)
forecast_panel_output <- file.path(
  config$paths$results_dir,
  "har_augmented_common155_monthly_refit_forecasts.csv"
)

ggsave(
  filename = error_plot_output,
  plot = error_plot,
  width = 11,
  height = 6,
  dpi = 300
)
fwrite(plot_panel, error_csv_output)
fwrite(full_forecast_panel, forecast_panel_output)

har_o_importance <- base_importance[
  feature_set == "HAR_O" &
    model_type %in% c("enet", "rf")
]
har_o_importance[, refit_key := as.character(refit_origin)]

enet_har_o <- har_o_importance[
  model_type == "enet" &
    metric == "non_zero_coefficient" &
    is.finite(value) &
    abs(value) > 0
][
  ,
  .(
    selected_refits = uniqueN(refit_key),
    selection_rate = uniqueN(refit_key) / uniqueN(har_o_importance[model_type == "enet"]$refit_key),
    mean_abs_coefficient = mean(abs(value), na.rm = TRUE),
    median_abs_coefficient = median(abs(value), na.rm = TRUE),
    latest_abs_coefficient = abs(value[which.max(refit_origin)])
  ),
  by = variable
][order(-selection_rate, -mean_abs_coefficient)]

rf_har_o_raw <- har_o_importance[
  model_type == "rf" &
    metric == "variable_importance" &
    is.finite(value)
]
rf_har_o_raw[, rank_in_refit := frank(-value, ties.method = "min"), by = refit_key]
rf_har_o <- rf_har_o_raw[
  ,
  .(
    refits_used = uniqueN(refit_key),
    top5_refits = uniqueN(refit_key[rank_in_refit <= 5]),
    top5_rate = uniqueN(refit_key[rank_in_refit <= 5]) / uniqueN(rf_har_o_raw$refit_key),
    mean_importance = mean(value, na.rm = TRUE),
    median_importance = median(value, na.rm = TRUE),
    latest_importance = value[which.max(refit_origin)],
    mean_rank = mean(rank_in_refit, na.rm = TRUE)
  ),
  by = variable
][order(-top5_rate, mean_rank, -mean_importance)]

enet_output <- file.path(
  config$paths$results_dir,
  "har_augmented_common155_monthly_refit_enet_har_o_selection.csv"
)
rf_output <- file.path(
  config$paths$results_dir,
  "har_augmented_common155_monthly_refit_rf_har_o_importance.csv"
)

fwrite(enet_har_o, enet_output)
fwrite(rf_har_o, rf_output)

message("Saved error time-series plot to: ", error_plot_output)
message("Saved error time-series data to: ", error_csv_output)
message("Saved monthly-refit forecast panel to: ", forecast_panel_output)
message("Saved ENET HAR+Option variable summary to: ", enet_output)
message("Saved RF HAR+Option variable summary to: ", rf_output)
print(head(enet_har_o, 10L))
print(head(rf_har_o, 10L))
