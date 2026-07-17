library(data.table)

source(file.path("R", "functions", "framework", "00_config.R"))
source(file.path("R", "functions", "framework", "UTILS", "helpers.R"))
source(file.path("R", "functions", "framework", "MODELS", "model_har.R"))
source(file.path("R", "functions", "framework", "MODELS", "model_enet.R"))
source(file.path("R", "functions", "framework", "MODELS", "model_pca.R"))
source(file.path("R", "functions", "framework", "MODELS", "model_pls.R"))
source(file.path("R", "functions", "framework", "MODELS", "model_rf.R"))
source(file.path("R", "functions", "framework", "MODELS", "model_nn.R"))
source(file.path("R", "functions", "framework", "MODELS", "model_registry.R"))
source(file.path("R", "functions", "framework", "FORECASTS", "combine_forecasts.R"))

if (!requireNamespace("MCS", quietly = TRUE)) {
  stop("Package 'MCS' is required but not installed.")
}

config <- create_config(base_dir = getwd())
config$paths$output_dir <- config$paths$robustness_output_dir

leaderboard_path <- file.path(config$paths$output_dir, "har_augmented_combo_leaderboard_common155.csv")
all_forecasts_path <- file.path(config$paths$results_dir, "all_forecasts.rds")

if (!file.exists(leaderboard_path)) {
  stop("Missing leaderboard file: ", leaderboard_path)
}
if (!file.exists(all_forecasts_path)) {
  stop("Missing forecast panel: ", all_forecasts_path)
}

leaderboard <- fread(leaderboard_path)
all_forecasts <- as.data.table(readRDS(all_forecasts_path))
all_forecasts <- clean_forecast_table(all_forecasts)

target_feature_sets <- c("HAR", "HAR_O", "HAR_M", "HAR_OM")
ml_methods <- c("enet", "pca", "pls", "rf", "nn")

base_panel <- all_forecasts[
  target_type == "log" &
    window_type == "rolling" &
    feature_set %in% target_feature_sets &
    model_type %in% c("har_ols", ml_methods)
]

individual_target_lists <- lapply(
  split(base_panel, by = "forecast_id", keep.by = FALSE),
  function(dt) unique(dt$target_date)
)
common_targets <- Reduce(intersect, individual_target_lists)
aligned_panel <- base_panel[target_date %in% common_targets]

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
      target_date = current_date,
      forecast_id = paste0("stacked_", meta_model, "_on_har_augmented_forecasts_log_rolling"),
      actual_level = current_row$actual_level,
      forecast_level = as.numeric(forecast_level)
    )
  }

  if (out_i == 0L) {
    return(data.table(target_date = as.Date(character()), forecast_id = character(), actual_level = numeric(), forecast_level = numeric()))
  }

  rbindlist(forecast_rows[seq_len(out_i)], fill = TRUE)
}

feature_model_ids <- lapply(
  target_feature_sets,
  function(feature_set_value) sort(unique(aligned_panel[feature_set == feature_set_value & model_type %in% ml_methods, forecast_id]))
)
names(feature_model_ids) <- target_feature_sets

method_model_ids <- lapply(
  ml_methods,
  function(method_value) sort(unique(aligned_panel[model_type == method_value & feature_set %in% target_feature_sets, forecast_id]))
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
      combo_dt[, .(target_date, forecast_id, actual_level, forecast_level)]
    }
  ),
  fill = TRUE
)

stacking_dt <- build_stacking_frame(aligned_panel[model_type %in% ml_methods])
stacked_forecasts <- rbindlist(
  lapply(c("enet", "rf"), function(meta_model) {
    run_stacked_forecasts(
      stacking_dt = stacking_dt,
      meta_model = meta_model,
      config = config,
      combination_window = config$forecasting$initial_window,
      min_history = 36L,
      min_features = 2L
    )
  }),
  fill = TRUE
)

stacked_common_targets <- Reduce(
  intersect,
  lapply(split(stacked_forecasts, by = "forecast_id", keep.by = FALSE), function(dt) unique(dt$target_date))
)

aligned_panel <- aligned_panel[target_date %in% stacked_common_targets, .(target_date, forecast_id, actual_level, forecast_level)]
combo_forecasts <- combo_forecasts[target_date %in% stacked_common_targets]
stacked_forecasts <- stacked_forecasts[target_date %in% stacked_common_targets]
all_eval_panel <- rbindlist(list(aligned_panel, combo_forecasts, stacked_forecasts), fill = TRUE)

build_mcs_table <- function(eval_panel, label_dt, subset_name, loss_name = c("qlike", "mse"), alpha = 0.10, B = 500L, statistic = "Tmax") {
  loss_name <- match.arg(loss_name)

  subset_ids <- label_dt$forecast_id
  loss_dt <- copy(eval_panel[forecast_id %in% subset_ids])
  if (loss_name == "qlike") {
    loss_dt[, loss_value := qlike_loss_from_volatility(actual_level, forecast_level, eps = config$evaluation$qlike_epsilon)]
  } else {
    loss_dt[, loss_value := (actual_level - forecast_level) ^ 2]
  }

  loss_wide <- dcast(loss_dt, target_date ~ forecast_id, value.var = "loss_value")
  loss_matrix <- as.matrix(loss_wide[, -1])
  finite_rows <- apply(loss_matrix, 1, function(x) all(is.finite(x)))
  loss_matrix <- loss_matrix[finite_rows, , drop = FALSE]

  mcs_object <- MCS::MCSprocedure(
    Loss = loss_matrix,
    alpha = alpha,
    B = B,
    statistic = statistic,
    verbose = FALSE
  )

  mcs_table <- as.data.frame(mcs_object@show)
  mcs_table$forecast_id <- rownames(mcs_table)
  mcs_dt <- as.data.table(mcs_table)
  setnames(
    mcs_dt,
    c("Rank_M", "v_M", "MCS_M", "Rank_R", "v_R", "MCS_R", "Loss"),
    c("rank_m", "v_m", "mcs_pvalue_tmax", "rank_r", "v_r", "mcs_pvalue_tr", "average_loss")
  )
  mcs_dt[, retained_in_mcs := mcs_pvalue_tmax > alpha]
  mcs_dt[, loss_name := loss_name]
  mcs_dt[, subset_name := subset_name]
  merge(mcs_dt, label_dt[, .(forecast_id, combo_name, entry_type, combo_type)], by = "forecast_id", all.x = TRUE)
}

top10_labels <- leaderboard[order(rank_oos_r2_vs_har, rank_qlike)][1:10, .(forecast_id, combo_name, entry_type, combo_type)]
combo_only_labels <- leaderboard[entry_type != "Individual Model", .(forecast_id, combo_name, entry_type, combo_type)]

top10_mcs <- rbindlist(list(
  build_mcs_table(all_eval_panel, top10_labels, subset_name = "top10", loss_name = "qlike"),
  build_mcs_table(all_eval_panel, top10_labels, subset_name = "top10", loss_name = "mse")
), fill = TRUE)

combo_only_mcs <- rbindlist(list(
  build_mcs_table(all_eval_panel, combo_only_labels, subset_name = "combo_only", loss_name = "qlike"),
  build_mcs_table(all_eval_panel, combo_only_labels, subset_name = "combo_only", loss_name = "mse")
), fill = TRUE)

mcs_summary <- rbindlist(list(top10_mcs, combo_only_mcs), fill = TRUE)
setorder(mcs_summary, subset_name, loss_name, -retained_in_mcs, rank_m, combo_name)

results_csv <- file.path(config$paths$results_dir, "har_augmented_common155_mcs_subsets.csv")
output_csv <- file.path(config$paths$output_dir, "har_augmented_common155_mcs_subsets.csv")
output_md <- file.path(config$paths$output_dir, "har_augmented_common155_mcs_subsets.md")

ensure_dir(config$paths$output_dir)
fwrite(mcs_summary, results_csv)
fwrite(mcs_summary, output_csv)

make_md_section <- function(dt, heading) {
  lines <- c("", paste0("## ", heading), "", "| Combo Name | Entry Type | Retained | MCS p-value | Average Loss | Rank |", "|---|---|---|---:|---:|---:|")
  for (i in seq_len(nrow(dt))) {
    row <- dt[i]
    lines <- c(lines, sprintf(
      "| %s | %s | %s | %.4f | %.4f | %d |",
      row$combo_name,
      row$entry_type,
      ifelse(isTRUE(row$retained_in_mcs), "Yes", "No"),
      row$mcs_pvalue_tmax,
      row$average_loss,
      row$rank_m
    ))
  }
  lines
}

md_lines <- c("# HAR-Augmented Common-155 MCS Subsets")
md_lines <- c(md_lines, make_md_section(mcs_summary[subset_name == "top10" & loss_name == "qlike"], "Top 10 by OOS R2 vs HAR: QLIKE MCS"))
md_lines <- c(md_lines, make_md_section(mcs_summary[subset_name == "top10" & loss_name == "mse"], "Top 10 by OOS R2 vs HAR: MSE MCS"))
md_lines <- c(md_lines, make_md_section(mcs_summary[subset_name == "combo_only" & loss_name == "qlike"], "Combo-Only: QLIKE MCS"))
md_lines <- c(md_lines, make_md_section(mcs_summary[subset_name == "combo_only" & loss_name == "mse"], "Combo-Only: MSE MCS"))
writeLines(md_lines, output_md)

message("Saved HAR-augmented common-155 subset MCS to: ", results_csv)
message("Saved HAR-augmented common-155 subset MCS copy to: ", output_csv)
message("Saved HAR-augmented common-155 subset MCS markdown to: ", output_md)
print(mcs_summary)
