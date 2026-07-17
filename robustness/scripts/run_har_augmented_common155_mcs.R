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

aligned_panel <- aligned_panel[target_date %in% stacked_common_targets, .(target_date, forecast_id, actual_level, forecast_level)]
combo_forecasts <- combo_forecasts[target_date %in% stacked_common_targets]
stacked_forecasts <- stacked_forecasts[target_date %in% stacked_common_targets]

all_eval_panel <- rbindlist(list(aligned_panel, combo_forecasts, stacked_forecasts), fill = TRUE)

label_map <- data.table(
  forecast_id = unique(all_eval_panel$forecast_id)
)
label_map[, combo_name := fcase(
  forecast_id == "har_ols__HAR__log__rolling", "OLS: HAR",
  forecast_id == "enet__HAR__log__rolling", "Elastic Net: HAR",
  forecast_id == "enet__HAR_O__log__rolling", "Elastic Net: HAR + Option",
  forecast_id == "enet__HAR_M__log__rolling", "Elastic Net: HAR + Macro",
  forecast_id == "enet__HAR_OM__log__rolling", "Elastic Net: HAR + Option + Macro",
  forecast_id == "pca__HAR__log__rolling", "PCA: HAR",
  forecast_id == "pca__HAR_O__log__rolling", "PCA: HAR + Option",
  forecast_id == "pca__HAR_M__log__rolling", "PCA: HAR + Macro",
  forecast_id == "pca__HAR_OM__log__rolling", "PCA: HAR + Option + Macro",
  forecast_id == "pls__HAR__log__rolling", "PLS: HAR",
  forecast_id == "pls__HAR_O__log__rolling", "PLS: HAR + Option",
  forecast_id == "pls__HAR_M__log__rolling", "PLS: HAR + Macro",
  forecast_id == "pls__HAR_OM__log__rolling", "PLS: HAR + Option + Macro",
  forecast_id == "rf__HAR__log__rolling", "Random Forest: HAR",
  forecast_id == "rf__HAR_O__log__rolling", "Random Forest: HAR + Option",
  forecast_id == "rf__HAR_M__log__rolling", "Random Forest: HAR + Macro",
  forecast_id == "rf__HAR_OM__log__rolling", "Random Forest: HAR + Option + Macro",
  forecast_id == "nn__HAR__log__rolling", "Neural Network: HAR",
  forecast_id == "nn__HAR_O__log__rolling", "Neural Network: HAR + Option",
  forecast_id == "nn__HAR_M__log__rolling", "Neural Network: HAR + Macro",
  forecast_id == "nn__HAR_OM__log__rolling", "Neural Network: HAR + Option + Macro",
  forecast_id == "combo_equal_weight_har_across_ml_har_augmented_log_rolling", "EW across ML: HAR",
  forecast_id == "combo_equal_weight_har_o_across_ml_har_augmented_log_rolling", "EW across ML: HAR + Option",
  forecast_id == "combo_equal_weight_har_m_across_ml_har_augmented_log_rolling", "EW across ML: HAR + Macro",
  forecast_id == "combo_equal_weight_har_om_across_ml_har_augmented_log_rolling", "EW across ML: HAR + Option + Macro",
  forecast_id == "combo_equal_weight_enet_across_har_augmented_datasets_log_rolling", "EW Elastic Net across HAR-augmented datasets",
  forecast_id == "combo_equal_weight_pca_across_har_augmented_datasets_log_rolling", "EW PCA across HAR-augmented datasets",
  forecast_id == "combo_equal_weight_pls_across_har_augmented_datasets_log_rolling", "EW PLS across HAR-augmented datasets",
  forecast_id == "combo_equal_weight_rf_across_har_augmented_datasets_log_rolling", "EW Random Forest across HAR-augmented datasets",
  forecast_id == "combo_equal_weight_nn_across_har_augmented_datasets_log_rolling", "EW Neural Network across HAR-augmented datasets",
  forecast_id == "combo_equal_weight_all_har_augmented_ml_x_dataset_log_rolling", "EW all ML x HAR-augmented datasets",
  forecast_id == "stacked_enet_on_har_augmented_forecasts_log_rolling", "Stacked ENET on HAR-augmented forecasts",
  forecast_id == "stacked_rf_on_har_augmented_forecasts_log_rolling", "Stacked RF on HAR-augmented forecasts",
  default = forecast_id
)]

build_mcs_table <- function(eval_panel, loss_name = c("qlike", "mse"), alpha = 0.10, B = 500L, statistic = "Tmax") {
  loss_name <- match.arg(loss_name)

  loss_dt <- copy(eval_panel)
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
  mcs_dt[]
}

qlike_mcs <- build_mcs_table(all_eval_panel, loss_name = "qlike", alpha = 0.10, B = 500L, statistic = "Tmax")
mse_mcs <- build_mcs_table(all_eval_panel, loss_name = "mse", alpha = 0.10, B = 500L, statistic = "Tmax")
mcs_summary <- rbindlist(list(qlike_mcs, mse_mcs), fill = TRUE)
mcs_summary <- merge(mcs_summary, label_map, by = "forecast_id", all.x = TRUE)
setorder(mcs_summary, loss_name, -retained_in_mcs, rank_m, combo_name)

results_csv <- file.path(config$paths$results_dir, "har_augmented_common155_mcs.csv")
output_csv <- file.path(config$paths$output_dir, "har_augmented_common155_mcs.csv")
output_md <- file.path(config$paths$output_dir, "har_augmented_common155_mcs.md")

ensure_dir(config$paths$output_dir)
fwrite(mcs_summary, results_csv)
fwrite(mcs_summary, output_csv)

md_lines <- c(
  "# HAR-Augmented Common-155 Model Confidence Set",
  "",
  "## QLIKE MCS",
  "",
  "| Combo Name | Retained | MCS p-value | Average Loss | Rank |",
  "|---|---|---:|---:|---:|"
)

for (i in seq_len(nrow(mcs_summary[loss_name == "qlike"]))) {
  row <- mcs_summary[loss_name == "qlike"][i]
  md_lines <- c(md_lines, sprintf(
    "| %s | %s | %.4f | %.4f | %d |",
    row$combo_name,
    ifelse(isTRUE(row$retained_in_mcs), "Yes", "No"),
    row$mcs_pvalue_tmax,
    row$average_loss,
    row$rank_m
  ))
}

md_lines <- c(
  md_lines,
  "",
  "## MSE MCS",
  "",
  "| Combo Name | Retained | MCS p-value | Average Loss | Rank |",
  "|---|---|---:|---:|---:|"
)

for (i in seq_len(nrow(mcs_summary[loss_name == "mse"]))) {
  row <- mcs_summary[loss_name == "mse"][i]
  md_lines <- c(md_lines, sprintf(
    "| %s | %s | %.4f | %.4f | %d |",
    row$combo_name,
    ifelse(isTRUE(row$retained_in_mcs), "Yes", "No"),
    row$mcs_pvalue_tmax,
    row$average_loss,
    row$rank_m
  ))
}

writeLines(md_lines, output_md)

message("Saved HAR-augmented common-155 MCS to: ", results_csv)
message("Saved HAR-augmented common-155 MCS copy to: ", output_csv)
message("Saved HAR-augmented common-155 MCS markdown to: ", output_md)
print(mcs_summary)
