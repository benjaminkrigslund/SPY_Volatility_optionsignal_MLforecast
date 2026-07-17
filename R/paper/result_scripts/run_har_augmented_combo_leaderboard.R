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
source(file.path("R", "functions", "framework", "EVALUATION", "dm_test.R"))
source(file.path("R", "functions", "framework", "EVALUATION", "encompassing_test.R"))
source(file.path("R", "functions", "framework", "EVALUATION", "evaluate_forecasts.R"))

config <- create_config(base_dir = getwd())

all_forecasts_path <- file.path(config$paths$results_dir, "all_forecasts.rds")
if (!file.exists(all_forecasts_path)) {
  stop("Missing forecast panel: ", all_forecasts_path)
}

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

individual_eval <- evaluate_forecasts(forecast_df = aligned_panel, config = config)$summary

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
    model_type == "pls", "PLS",
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

combo_eval <- evaluate_forecasts(forecast_df = combo_forecasts, config = config)$summary

combo_meta <- unique(combo_forecasts[, .(forecast_id, n_members, combo_members)])
combo_eval <- merge(combo_eval, combo_meta, by = "forecast_id", all.x = TRUE)

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

stacked_eval <- evaluate_forecasts(forecast_df = stacked_forecasts, config = config)$summary
stacked_meta <- unique(stacked_forecasts[, .(forecast_id, n_members)])
stacked_eval <- merge(stacked_eval, stacked_meta, by = "forecast_id", all.x = TRUE)

individual_board <- individual_eval[
  ,
  .(
    entry_type = "Individual Model",
    combo_name = paste(label_model(model_type), label_feature_set(feature_set), sep = ": "),
    forecast_id,
    combo_type = "Individual Model",
    model_family = label_model(model_type),
    information_set = label_feature_set(feature_set),
    n_eval = n_oos,
    oos_r2,
    qlike,
    n_members = 1L
  )
]

combo_board <- combo_eval[
  ,
  .(
    entry_type = "Equal Weight Combo",
    combo_name = data.table::fcase(
      grepl("^combo_equal_weight_har_across_ml_har_augmented", forecast_id), "EW across ML: HAR",
      grepl("^combo_equal_weight_har_o_across_ml_har_augmented", forecast_id), "EW across ML: HAR + Option",
      grepl("^combo_equal_weight_har_m_across_ml_har_augmented", forecast_id), "EW across ML: HAR + Macro",
      grepl("^combo_equal_weight_har_om_across_ml_har_augmented", forecast_id), "EW across ML: HAR + Option + Macro",
      grepl("^combo_equal_weight_enet_across_har_augmented", forecast_id), "EW Elastic Net across HAR-augmented datasets",
      grepl("^combo_equal_weight_pca_across_har_augmented", forecast_id), "EW PCA across HAR-augmented datasets",
      grepl("^combo_equal_weight_pls_across_har_augmented", forecast_id), "EW PLS across HAR-augmented datasets",
      grepl("^combo_equal_weight_rf_across_har_augmented", forecast_id), "EW Random Forest across HAR-augmented datasets",
      grepl("^combo_equal_weight_nn_across_har_augmented", forecast_id), "EW Neural Network across HAR-augmented datasets",
      forecast_id == "combo_equal_weight_all_har_augmented_ml_x_dataset_log_rolling", "EW all ML x HAR-augmented datasets",
      default = forecast_id
    ),
    forecast_id,
    combo_type = data.table::fcase(
      grepl("_across_ml_har_augmented", forecast_id), "EW Across ML Within Dataset",
      grepl("_across_har_augmented_datasets", forecast_id), "EW Across Datasets Within ML",
      forecast_id == "combo_equal_weight_all_har_augmented_ml_x_dataset_log_rolling", "EW Full Panel",
      default = "EW Combo"
    ),
    model_family = data.table::fcase(
      grepl("^combo_equal_weight_enet_", forecast_id), "Elastic Net",
      grepl("^combo_equal_weight_pca_", forecast_id), "PCA",
      grepl("^combo_equal_weight_pls_", forecast_id), "PLS",
      grepl("^combo_equal_weight_rf_", forecast_id), "Random Forest",
      grepl("^combo_equal_weight_nn_", forecast_id), "Neural Network",
      default = "Multiple"
    ),
    information_set = data.table::fcase(
      grepl("^combo_equal_weight_har_across_ml_har_augmented", forecast_id), "HAR",
      grepl("^combo_equal_weight_har_o_across_ml_har_augmented", forecast_id), "HAR + Option",
      grepl("^combo_equal_weight_har_m_across_ml_har_augmented", forecast_id), "HAR + Macro",
      grepl("^combo_equal_weight_har_om_across_ml_har_augmented", forecast_id), "HAR + Option + Macro",
      default = "Multiple"
    ),
    n_eval = n_oos,
    oos_r2,
    qlike,
    n_members = as.integer(n_members)
  )
]

stacked_board <- stacked_eval[
  ,
  .(
    entry_type = "Stacked Combo",
    combo_name = data.table::fcase(
      forecast_id == "stacked_enet_on_har_augmented_forecasts_log_rolling", "Stacked ENET on HAR-augmented forecasts",
      forecast_id == "stacked_rf_on_har_augmented_forecasts_log_rolling", "Stacked RF on HAR-augmented forecasts",
      default = forecast_id
    ),
    forecast_id,
    combo_type = "Stacked Forecasts",
    model_family = data.table::fcase(
      grepl("^stacked_enet", forecast_id), "Elastic Net",
      grepl("^stacked_rf", forecast_id), "Random Forest",
      default = "Stacked"
    ),
    information_set = "All HAR-augmented forecasts",
    n_eval = n_oos,
    oos_r2,
    qlike,
    n_members = as.integer(n_members)
  )
]

leaderboard <- rbindlist(list(individual_board, combo_board, stacked_board), fill = TRUE)
leaderboard[, rank_oos_r2 := data.table::frank(-oos_r2, ties.method = "min")]
leaderboard[, rank_qlike := data.table::frank(qlike, ties.method = "min")]
setorder(leaderboard, rank_oos_r2, rank_qlike, entry_type, combo_name)

results_csv <- file.path(config$paths$results_dir, "har_augmented_combo_leaderboard.csv")
output_csv <- file.path(config$paths$output_dir, "har_augmented_combo_leaderboard.csv")
output_md <- file.path(config$paths$output_dir, "har_augmented_combo_leaderboard.md")

ensure_dir(config$paths$output_dir)
fwrite(leaderboard, results_csv)
fwrite(leaderboard, output_csv)

md_lines <- c(
  "# HAR-Augmented Leaderboard",
  "",
  "| Rank OOS R2 | Rank QLIKE | Entry Type | Combo Name | Combo Type | Model Family | Information Set | N | OOS R2 | QLIKE | Members |",
  "|---:|---:|---|---|---|---|---|---:|---:|---:|---:|"
)

for (i in seq_len(nrow(leaderboard))) {
  row <- leaderboard[i]
  md_lines <- c(
    md_lines,
    sprintf(
      "| %d | %d | %s | %s | %s | %s | %s | %d | %.4f | %.4f | %d |",
      row$rank_oos_r2,
      row$rank_qlike,
      row$entry_type,
      row$combo_name,
      row$combo_type,
      row$model_family,
      row$information_set,
      row$n_eval,
      row$oos_r2,
      row$qlike,
      row$n_members
    )
  )
}

writeLines(md_lines, output_md)

message("Saved HAR-augmented leaderboard to: ", results_csv)
message("Saved HAR-augmented leaderboard copy to: ", output_csv)
message("Saved HAR-augmented leaderboard markdown to: ", output_md)
print(leaderboard)
