library(data.table)

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
source(file.path("R", "functions", "framework", "EVALUATION", "dm_test.R"))
source(file.path("R", "functions", "framework", "EVALUATION", "encompassing_test.R"))
source(file.path("R", "functions", "framework", "EVALUATION", "evaluate_forecasts.R"))

config <- create_config(base_dir = getwd())

target_feature_sets <- c("HAR", "HAR_O", "HAR_M", "HAR_OM")
ml_methods <- c("enet", "pca", "rf", "nn")
base_refit_every <- as.integer(Sys.getenv("BASE_REFIT_EVERY", unset = "1"))
if (!is.finite(base_refit_every) || base_refit_every < 1L) {
  stop("BASE_REFIT_EVERY must be a positive integer. Got: ", base_refit_every)
}
base_refit_every <- as.integer(base_refit_every)
base_refit_label <- if (base_refit_every == 1L) "monthly_refit" else paste0("refit_", base_refit_every)
n_har_augmented_ml_forecasts <- length(ml_methods) * length(target_feature_sets)

master_data <- load_master_data(config)

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

base_panel <- rbindlist(lapply(base_runs, `[[`, "forecasts"), fill = TRUE)
base_panel <- clean_forecast_table(base_panel)

base_panel <- base_panel[
  target_type == "log" &
    window_type == "rolling" &
    feature_set %in% target_feature_sets &
    model_type %in% c("har_ols", ml_methods)
]

if (nrow(base_panel) == 0L) {
  stop("No log/rolling forecasts found for HAR/HAR_O/HAR_M/HAR_OM.")
}

individual_target_lists <- lapply(
  split(base_panel, by = "forecast_id", keep.by = FALSE),
  function(dt) unique(dt$target_date)
)

common_targets <- Reduce(intersect, individual_target_lists)
if (length(common_targets) == 0L) {
  stop("No common out-of-sample dates across the selected HAR-augmented forecasts.")
}

aligned_panel <- base_panel[target_date %in% common_targets]
har_baseline_id <- "har_ols__HAR__log__rolling"

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
    return(data.table(
      origin_date = as.Date(character()),
      target_date = as.Date(character()),
      model_type = character(),
      feature_set = character(),
      window_type = character(),
      target_type = character(),
      forecast_transformed = numeric(),
      forecast_level = numeric(),
      benchmark_forecast = numeric(),
      actual_transformed = numeric(),
      actual_level = numeric(),
      refit_every = integer(),
      initial_window = integer(),
      forecast_id = character(),
      combination_window = integer(),
      meta_train_rows = integer(),
      n_members = integer(),
      members = character(),
      log_resid_var = numeric()
    ))
  }

  rbindlist(forecast_rows[seq_len(out_i)], fill = TRUE)
}

label_feature_set <- function(feature_set) {
  data.table::fcase(
    feature_set == "HAR", "HAR",
    feature_set == "HAR_O", "HAR + Option",
    feature_set == "HAR_M", "HAR + Macro",
    feature_set == "HAR_OM", "HAR + Option + Macro",
    default = feature_set
  )
}

label_model <- function(model_type) {
  data.table::fcase(
    model_type == "har_ols", "OLS",
    model_type == "enet", "Elastic Net",
    model_type == "pca", "PCA",
    model_type == "rf", "Random Forest",
    model_type == "nn", "Neural Network",
    default = model_type
  )
}

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
      combo_dt[, combo_members := paste(member_ids, collapse = " | ")]
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

if (nrow(stacked_forecasts) == 0L) {
  stop("No stacked ENET/RF forecasts were generated for the HAR-augmented panel.")
}

stacked_target_lists <- lapply(
  split(stacked_forecasts, by = "forecast_id", keep.by = FALSE),
  function(dt) unique(dt$target_date)
)
stacked_common_targets <- Reduce(intersect, stacked_target_lists)

if (length(stacked_common_targets) == 0L) {
  stop("No common stacked forecast dates found for the HAR-augmented panel.")
}

aligned_panel <- aligned_panel[target_date %in% stacked_common_targets]
combo_forecasts <- combo_forecasts[target_date %in% stacked_common_targets]
stacked_forecasts <- stacked_forecasts[target_date %in% stacked_common_targets]

individual_eval <- evaluate_forecasts(forecast_df = aligned_panel, config = config)$summary
combo_eval <- evaluate_forecasts(forecast_df = combo_forecasts, config = config)$summary

combo_meta <- unique(combo_forecasts[, .(forecast_id, n_members, combo_members)])
combo_eval <- merge(combo_eval, combo_meta, by = "forecast_id", all.x = TRUE)

stacked_eval <- evaluate_forecasts(forecast_df = stacked_forecasts, config = config)$summary
stacked_meta <- unique(stacked_forecasts[, .(forecast_id, n_members)])
stacked_eval <- merge(stacked_eval, stacked_meta, by = "forecast_id", all.x = TRUE)

evaluate_against_har <- function(forecast_dt, har_dt, config, har_baseline_id) {
  forecast_ids <- sort(unique(forecast_dt$forecast_id))

  rbindlist(
    lapply(
      forecast_ids,
      function(fid) {
        model_dt <- forecast_dt[forecast_id == fid]
        merged <- merge(
          model_dt[
            ,
            .(
              target_date,
              actual_level,
              model_forecast = forecast_level
            )
          ],
          har_dt[
            ,
            .(
              target_date,
              har_forecast = forecast_level
            )
          ],
          by = "target_date",
          all = FALSE
        )

        se_model <- (merged$actual_level - merged$model_forecast) ^ 2
        se_har <- (merged$actual_level - merged$har_forecast) ^ 2
        qlike_model <- qlike_loss_from_volatility(
          merged$actual_level,
          merged$model_forecast,
          eps = config$evaluation$qlike_epsilon
        )
        qlike_har <- qlike_loss_from_volatility(
          merged$actual_level,
          merged$har_forecast,
          eps = config$evaluation$qlike_epsilon
        )

        dm_mse <- dm_test(se_model, se_har, horizon = config$evaluation$dm_horizon)
        dm_qlike <- dm_test(qlike_model, qlike_har, horizon = config$evaluation$dm_horizon)

        data.table(
          forecast_id = fid,
          n_eval = nrow(merged),
          oos_r2_vs_har = if (fid == har_baseline_id) 0 else 1 - sum(se_model, na.rm = TRUE) / sum(se_har, na.rm = TRUE),
          qlike = mean(qlike_model, na.rm = TRUE),
          qlike_gain_vs_har = mean(qlike_har, na.rm = TRUE) - mean(qlike_model, na.rm = TRUE),
          dm_mse_p_vs_har = if (fid == har_baseline_id) NA_real_ else dm_mse$p_value,
          dm_qlike_p_vs_har = if (fid == har_baseline_id) NA_real_ else dm_qlike$p_value
        )
      }
    ),
    fill = TRUE
  )
}

har_baseline <- aligned_panel[forecast_id == har_baseline_id]
all_eval_panel <- rbindlist(
  list(
    aligned_panel[, .(forecast_id, target_date, actual_level, forecast_level)],
    combo_forecasts[, .(forecast_id, target_date, actual_level, forecast_level)],
    stacked_forecasts[, .(forecast_id, target_date, actual_level, forecast_level)]
  ),
  fill = TRUE
)
vs_har_eval <- evaluate_against_har(all_eval_panel, har_baseline, config, har_baseline_id)

individual_board <- individual_eval[
  ,
  .(
    model_type_display = label_model(model_type),
    information_set_display = label_feature_set(feature_set),
    forecast_id,
    n_eval = n_oos,
    n_members = 1L
  )
]

combo_board <- combo_eval[
  ,
  .(
    model_type_display = data.table::fcase(
      grepl("^combo_equal_weight_har_", forecast_id), "EW Across ML",
      grepl("^combo_equal_weight_enet_across_har_augmented", forecast_id), "EW Elastic Net",
      grepl("^combo_equal_weight_pca_across_har_augmented", forecast_id), "EW PCA",
      grepl("^combo_equal_weight_rf_across_har_augmented", forecast_id), "EW Random Forest",
      grepl("^combo_equal_weight_nn_across_har_augmented", forecast_id), "EW Neural Network",
      forecast_id == "combo_equal_weight_all_har_augmented_ml_x_dataset_log_rolling", "EW Full Panel",
      default = "EW Combo"
    ),
    information_set_display = data.table::fcase(
      grepl("^combo_equal_weight_har_across_ml_har_augmented", forecast_id), "HAR",
      grepl("^combo_equal_weight_har_o_across_ml_har_augmented", forecast_id), "HAR + Option",
      grepl("^combo_equal_weight_har_m_across_ml_har_augmented", forecast_id), "HAR + Macro",
      grepl("^combo_equal_weight_har_om_across_ml_har_augmented", forecast_id), "HAR + Option + Macro",
      grepl("_across_har_augmented_datasets", forecast_id), "All HAR-augmented sets",
      forecast_id == "combo_equal_weight_all_har_augmented_ml_x_dataset_log_rolling", "All HAR-augmented sets",
      default = "Multiple"
    ),
    forecast_id,
    n_eval = n_oos,
    n_members = as.integer(n_members)
  )
]

stacked_board <- stacked_eval[
  ,
  .(
    model_type_display = data.table::fcase(
      forecast_id == "stacked_enet_on_har_augmented_forecasts_log_rolling", "Stacked ENET",
      forecast_id == "stacked_rf_on_har_augmented_forecasts_log_rolling", "Stacked RF",
      default = "Stacked"
    ),
    information_set_display = sprintf(
      "All %d HAR-augmented ML forecasts",
      n_har_augmented_ml_forecasts
    ),
    forecast_id,
    n_eval = n_oos,
    n_members = as.integer(n_members)
  )
]

leaderboard <- rbindlist(list(individual_board, combo_board, stacked_board), fill = TRUE)
leaderboard <- merge(leaderboard, vs_har_eval, by = c("forecast_id", "n_eval"), all.x = TRUE)
leaderboard[, rank_oos_r2_vs_har := data.table::frank(-oos_r2_vs_har, ties.method = "min", na.last = "keep")]
leaderboard[, rank_qlike := data.table::frank(qlike, ties.method = "min", na.last = "keep")]
setorder(leaderboard, rank_oos_r2_vs_har, rank_qlike, model_type_display, information_set_display)

leaderboard <- leaderboard[
  ,
  .(
    rank_oos_r2_vs_har,
    rank_qlike,
    model_type = model_type_display,
    information_set = information_set_display,
    n_eval,
    oos_r2_vs_har,
    qlike,
    qlike_gain_vs_har,
    n_members,
    forecast_id,
    dm_mse_p_vs_har,
    dm_qlike_p_vs_har
  )
]

results_csv <- file.path(config$paths$results_dir, "har_augmented_combo_leaderboard_common155.csv")
if (base_refit_every == config$forecasting$refit_every) {
  results_csv <- file.path(config$paths$results_dir, "har_augmented_combo_leaderboard_common155.csv")
  output_csv <- file.path(config$paths$output_dir, "har_augmented_combo_leaderboard_common155.csv")
  output_md <- file.path(config$paths$output_dir, "har_augmented_combo_leaderboard_common155.md")
} else {
  results_csv <- file.path(
    config$paths$results_dir,
    paste0("har_augmented_combo_leaderboard_common155_", base_refit_label, ".csv")
  )
  output_csv <- file.path(
    config$paths$output_dir,
    paste0("har_augmented_combo_leaderboard_common155_", base_refit_label, ".csv")
  )
  output_md <- file.path(
    config$paths$output_dir,
    paste0("har_augmented_combo_leaderboard_common155_", base_refit_label, ".md")
  )
}

ensure_dir(config$paths$output_dir)
fwrite(leaderboard, results_csv)
fwrite(leaderboard, output_csv)

md_lines <- c(
  paste0("# HAR-Augmented Leaderboard on Common 155-Date Stacking Sample (", base_refit_label, ")"),
  "",
  "Common sample construction:",
  "- 155 out-of-sample dates that are available for every HAR-augmented individual forecast and for both stacked forecasts.",
  "- Information sets: `HAR`, `HAR + Option`, `HAR + Macro`, and `HAR + Option + Macro`.",
  sprintf("- Baseline: OLS is estimated only on `HAR`, with `refit_every = %d`.", base_refit_every),
  "- Individual ML models: 4 methods on each information set (`Elastic Net`, `PCA`, `Random Forest`, `Neural Network`), giving 16 HAR-augmented ML forecasts.",
  sprintf("- All base models in this table are re-estimated with `refit_every = %d` on a 120-month rolling window.", base_refit_every),
  "- Equal-weight combinations across ML within each information set.",
  "- Equal-weight combinations across information sets within each ML method.",
  sprintf("- One grand equal-weight forecast across all %d HAR-augmented ML forecasts.", n_har_augmented_ml_forecasts),
  sprintf("- Two stacked meta-forecasts on top of the same %d forecasts: `Stacked RF` and `Stacked ENET`.", n_har_augmented_ml_forecasts),
  "- The stacked layer is refit every month in this script.",
  "",
  "| Rank OOS R2 vs HAR | Rank QLIKE | Model Type | Information Set | N | OOS R2 vs HAR | QLIKE | QLIKE Gain vs HAR | Members |",
  "|---:|---:|---|---|---:|---:|---:|---:|---:|"
)

for (i in seq_len(nrow(leaderboard))) {
  row <- leaderboard[i]
  md_lines <- c(
    md_lines,
    sprintf(
      "| %d | %d | %s | %s | %d | %.4f | %.4f | %.4f | %d |",
      row$rank_oos_r2_vs_har,
      row$rank_qlike,
      row$model_type,
      row$information_set,
      row$n_eval,
      row$oos_r2_vs_har,
      row$qlike,
      row$qlike_gain_vs_har,
      row$n_members
    )
  )
}

writeLines(md_lines, output_md)

message("Saved HAR-augmented common-155 leaderboard to: ", results_csv)
message("Saved HAR-augmented common-155 leaderboard copy to: ", output_csv)
message("Saved HAR-augmented common-155 leaderboard markdown to: ", output_md)
print(leaderboard)
