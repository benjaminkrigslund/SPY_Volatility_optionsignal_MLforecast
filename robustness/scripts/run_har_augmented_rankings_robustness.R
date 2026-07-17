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
config$paths$output_dir <- config$paths$robustness_output_dir
master_data <- load_master_data(config)

target_feature_sets <- c("HAR", "HAR_O", "HAR_M", "HAR_OM")
ml_methods <- c("enet", "pca", "rf", "nn")
base_refit_every <- 1L

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

run_stacked_forecasts_generic <- function(stacking_dt,
                                          meta_model,
                                          config,
                                          target_type,
                                          window_type,
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

    if (window_type == "rolling" && nrow(history_dt) > combination_window) {
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

    if (target_type == "log") {
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
    } else {
      log_resid_var <- 0
      forecast_level <- as.numeric(pred_transformed)
      forecast_floor <- get_level_forecast_floor(y_train, config)
    }

    forecast_level <- enforce_positive_forecast(forecast_level, floor_value = forecast_floor)

    out_i <- out_i + 1L
    forecast_rows[[out_i]] <- data.table(
      origin_date = current_row$origin_date,
      target_date = current_date,
      model_type = paste0("stacked_", meta_model),
      feature_set = "HAR_AUGMENTED_STACK",
      window_type = window_type,
      target_type = target_type,
      forecast_transformed = as.numeric(pred_transformed),
      forecast_level = as.numeric(forecast_level),
      benchmark_forecast = current_row$benchmark_forecast,
      actual_transformed = current_row$actual_transformed,
      actual_level = current_row$actual_level,
      refit_every = 1L,
      initial_window = min_history,
      forecast_id = paste0("stacked_", meta_model, "_on_har_augmented_forecasts__", target_type, "__", window_type),
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

build_scenario_panel <- function(target_type,
                                 window_type,
                                 config,
                                 master_data,
                                 use_saved_main = FALSE) {
  scenario_target_type <- target_type
  scenario_window_type <- window_type

  if (use_saved_main) {
    saved_path <- file.path(
      config$paths$results_dir,
      "har_augmented_common155_monthly_refit_forecasts.csv"
    )
    if (!file.exists(saved_path)) {
      stop("Missing saved main forecast panel: ", saved_path)
    }
    return(clean_forecast_table(fread(saved_path)))
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
      "[", target_type, " / ", window_type, "][", i, "/", nrow(base_specs), "] Running ",
      spec$model_type, " | ", spec$feature_set, " | refit_every=", base_refit_every
    )

    base_runs[[i]] <- run_forecast(
      data = master_data,
      model_type = spec$model_type,
      feature_set = spec$feature_set,
      window_type = window_type,
      initial_window = config$forecasting$initial_window,
      refit_every = base_refit_every,
      target_type = target_type,
      config = config
    )
  }

  base_panel <- rbindlist(lapply(base_runs, `[[`, "forecasts"), fill = TRUE)
  base_panel <- clean_forecast_table(base_panel)
  base_panel <- base_panel[
    target_type == scenario_target_type &
      window_type == scenario_window_type &
      feature_set %in% target_feature_sets &
      model_type %in% c("har_ols", ml_methods)
  ]

  individual_target_lists <- lapply(
    split(base_panel, by = "forecast_id", keep.by = FALSE),
    function(dt) unique(dt$target_date)
  )

  common_targets <- Reduce(intersect, individual_target_lists)
  aligned_panel <- base_panel[target_date %in% common_targets]

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
      paste0("combo_equal_weight_", tolower(target_feature_sets), "_across_ml_har_augmented__", target_type, "__", window_type)
    ),
    setNames(
      lapply(ml_methods, function(m) method_model_ids[[m]]),
      paste0("combo_equal_weight_", ml_methods, "_across_har_augmented_datasets__", target_type, "__", window_type)
    ),
    list(
      setNames(
        list(sort(unique(aligned_panel[model_type %in% ml_methods, forecast_id]))),
        paste0("combo_equal_weight_all_har_augmented_ml_x_dataset__", target_type, "__", window_type)
      )
    )
  )

  combo_specs <- unlist(combo_specs, recursive = FALSE)

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
        run_stacked_forecasts_generic(
          stacking_dt = stacking_dt,
          meta_model = meta_model,
          config = config,
          target_type = target_type,
          window_type = window_type,
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

  rbindlist(list(aligned_panel, combo_forecasts, stacked_forecasts), fill = TRUE)
}

build_rank_table <- function(full_panel, scenario_key, scenario_label, target_type, window_type) {
  har_baseline_id <- paste("har_ols", "HAR", target_type, window_type, sep = "__")
  har_baseline <- full_panel[forecast_id == har_baseline_id]

  forecast_eval <- evaluate_forecasts(forecast_df = full_panel, config = config)$summary

  rank_dt <- forecast_eval[
    ,
    .(
      forecast_id,
      model_type_display = data.table::fcase(
        model_type == "har_ols", "OLS",
        model_type == "enet", "Elastic Net",
        model_type == "pca", "PCA",
        model_type == "rf", "Random Forest",
        model_type == "nn", "Neural Network",
        model_type == "stacked_enet", "Stacked ENET",
        model_type == "stacked_rf", "Stacked RF",
        grepl("^combo_equal_weight_har_", forecast_id), "EW Across ML",
        grepl("^combo_equal_weight_enet_", forecast_id), "EW Elastic Net",
        grepl("^combo_equal_weight_pca_", forecast_id), "EW PCA",
        grepl("^combo_equal_weight_rf_", forecast_id), "EW Random Forest",
        grepl("^combo_equal_weight_nn_", forecast_id), "EW Neural Network",
        grepl("^combo_equal_weight_all_har_augmented_ml_x_dataset", forecast_id), "EW Full Panel",
        default = label_model(model_type)
      ),
      information_set_display = data.table::fcase(
        feature_set == "HAR", "HAR",
        feature_set == "HAR_O", "HAR + Option",
        feature_set == "HAR_M", "HAR + Macro",
        feature_set == "HAR_OM", "HAR + Option + Macro",
        grepl("^combo_equal_weight_har_across_ml_har_augmented", forecast_id), "HAR",
        grepl("^combo_equal_weight_har_o_across_ml_har_augmented", forecast_id), "HAR + Option",
        grepl("^combo_equal_weight_har_m_across_ml_har_augmented", forecast_id), "HAR + Macro",
        grepl("^combo_equal_weight_har_om_across_ml_har_augmented", forecast_id), "HAR + Option + Macro",
        grepl("_across_har_augmented_datasets__", forecast_id), "All HAR-augmented sets",
        grepl("^combo_equal_weight_all_har_augmented_ml_x_dataset", forecast_id), "All HAR-augmented sets",
        grepl("^stacked_", forecast_id), sprintf("All %d HAR-augmented ML forecasts", length(ml_methods) * length(target_feature_sets)),
        default = feature_set
      ),
      n_eval = n_oos,
      qlike = qlike,
      forecast_level = NA_real_
    )
  ]

  eval_panel <- full_panel[, .(forecast_id, target_date, actual_level, forecast_level)]
  vs_har <- rbindlist(
    lapply(
      sort(unique(eval_panel$forecast_id)),
      function(fid) {
        model_dt <- eval_panel[forecast_id == fid]
        merged <- merge(
          model_dt[, .(target_date, actual_level, model_forecast = forecast_level)],
          har_baseline[, .(target_date, har_forecast = forecast_level)],
          by = "target_date",
          all = FALSE
        )
        data.table(
          forecast_id = fid,
          n_eval = nrow(merged),
          oos_r2_vs_har = if (fid == har_baseline_id) {
            0
          } else {
            1 - sum((merged$actual_level - merged$model_forecast) ^ 2, na.rm = TRUE) /
              sum((merged$actual_level - merged$har_forecast) ^ 2, na.rm = TRUE)
          }
        )
      }
    ),
    fill = TRUE
  )

  rank_dt <- merge(rank_dt, vs_har, by = c("forecast_id", "n_eval"), all.x = TRUE)
  rank_dt[, entry_key := paste(model_type_display, information_set_display, sep = " | ")]
  rank_dt[, scenario := scenario_label]
  rank_dt[, rank_oos_r2_vs_har := frank(-oos_r2_vs_har, ties.method = "min")]
  rank_dt[, rank_qlike := frank(qlike, ties.method = "min")]

  rank_dt[
    ,
    .(
      entry_key,
      model_type = model_type_display,
      information_set = information_set_display,
      scenario,
      rank_oos_r2_vs_har,
      rank_qlike
    )
  ]
}

scenario_specs <- list(
  list(
    key = "rolling_log",
    label = "Rolling logRV",
    target_type = "log",
    window_type = "rolling",
    use_saved_main = TRUE
  ),
  list(
    key = "expanding_log",
    label = "Expanding logRV",
    target_type = "log",
    window_type = "expanding",
    use_saved_main = FALSE
  ),
  list(
    key = "rolling_level",
    label = "Rolling RV",
    target_type = "level",
    window_type = "rolling",
    use_saved_main = FALSE
  )
)

rank_tables <- lapply(
  scenario_specs,
  function(spec) {
    panel <- build_scenario_panel(
      target_type = spec$target_type,
      window_type = spec$window_type,
      config = config,
      master_data = master_data,
      use_saved_main = spec$use_saved_main
    )
    build_rank_table(
      full_panel = panel,
      scenario_key = spec$key,
      scenario_label = spec$label,
      target_type = spec$target_type,
      window_type = spec$window_type
    )
  }
)

rank_long <- rbindlist(rank_tables, fill = TRUE)

rank_wide_r2 <- dcast(
  rank_long,
  entry_key + model_type + information_set ~ scenario,
  value.var = "rank_oos_r2_vs_har"
)
rank_wide_qlike <- dcast(
  rank_long,
  entry_key + model_type + information_set ~ scenario,
  value.var = "rank_qlike"
)

setnames(
  rank_wide_r2,
  old = c("Rolling logRV", "Expanding logRV", "Rolling RV"),
  new = c("rank_r2_rolling_logrv", "rank_r2_expanding_logrv", "rank_r2_rolling_rv")
)
setnames(
  rank_wide_qlike,
  old = c("Rolling logRV", "Expanding logRV", "Rolling RV"),
  new = c("rank_qlike_rolling_logrv", "rank_qlike_expanding_logrv", "rank_qlike_rolling_rv")
)

rank_compare <- merge(
  rank_wide_r2,
  rank_wide_qlike,
  by = c("entry_key", "model_type", "information_set"),
  all = TRUE
)
setorder(rank_compare, rank_r2_rolling_logrv, rank_qlike_rolling_logrv, model_type, information_set)

csv_out <- file.path(config$paths$results_dir, "har_augmented_rankings_robustness.csv")
md_out <- file.path(config$paths$output_dir, "har_augmented_rankings_robustness.md")

fwrite(rank_compare, csv_out)

md_lines <- c(
  "# HAR-Augmented Robustness Ranking Comparison",
  "",
  "Monthly-refit reduced model universe (`OLS`, `ENET`, `PCA`, `RF`, `NN`; no `PLS`).",
  "",
  "| Model Type | Information Set | R2 Rank: Rolling logRV | R2 Rank: Expanding logRV | R2 Rank: Rolling RV | QLIKE Rank: Rolling logRV | QLIKE Rank: Expanding logRV | QLIKE Rank: Rolling RV |",
  "|---|---|---:|---:|---:|---:|---:|---:|"
)

for (i in seq_len(nrow(rank_compare))) {
  row <- rank_compare[i]
  md_lines <- c(
    md_lines,
    sprintf(
      "| %s | %s | %d | %d | %d | %d | %d | %d |",
      row$model_type,
      row$information_set,
      row$rank_r2_rolling_logrv,
      row$rank_r2_expanding_logrv,
      row$rank_r2_rolling_rv,
      row$rank_qlike_rolling_logrv,
      row$rank_qlike_expanding_logrv,
      row$rank_qlike_rolling_rv
    )
  )
}

writeLines(md_lines, md_out)

message("Saved robustness ranking CSV to: ", csv_out)
message("Saved robustness ranking markdown to: ", md_out)
print(rank_compare)
