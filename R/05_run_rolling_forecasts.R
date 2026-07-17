#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(data.table)
})

source(file.path("R", "functions", "framework", "00_config.R"))
source(file.path("R", "functions", "framework", "UTILS", "helpers.R"))
source(file.path("R", "functions", "framework", "01_load_data.R"))
source(file.path("R", "functions", "framework", "FEATURES", "feature_sets.R"))
source(file.path("R", "functions", "framework", "MODELS", "model_har.R"))
source(file.path("R", "functions", "framework", "MODELS", "model_pca.R"))
source(file.path("R", "functions", "framework", "MODELS", "model_enet.R"))
source(file.path("R", "functions", "framework", "MODELS", "model_rf.R"))
source(file.path("R", "functions", "framework", "MODELS", "model_nn.R"))
source(file.path("R", "functions", "framework", "MODELS", "model_registry.R"))
source(file.path("R", "functions", "framework", "FORECASTS", "run_forecast.R"))

required_packages <- c("data.table", "glmnet", "ranger", "nnet", "knitr")
missing_packages <- required_packages[!vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)]

if (length(missing_packages) > 0L) {
  stop(
    "Install required packages before running this script: ",
    paste(missing_packages, collapse = ", ")
  )
}

config <- create_config(base_dir = getwd())
config$forecasting$initial_window <- 120L
config$forecasting$refit_every <- 1L
config$forecasting$horizon <- 1L

table_dir <- ensure_dir(config$paths$output_dir)
panel_dir <- ensure_dir(config$paths$forecast_panel_dir)
robustness_table_dir <- ensure_dir(config$paths$robustness_output_dir)

main_csv_path <- file.path(table_dir, "main_forecast_results_table.csv")
main_tex_path <- file.path(table_dir, "main_forecast_results_table.tex")
main_md_path <- file.path(table_dir, "main_forecast_results_table.md")
forecast_panel_csv_path <- file.path(panel_dir, "main_forecast_forecast_panel.csv")
forecast_panel_rds_path <- file.path(panel_dir, "main_forecast_forecast_panel.rds")
rolling60_csv_path <- file.path(robustness_table_dir, "main_forecast_results_table_rolling60.csv")
rolling60_tex_path <- file.path(robustness_table_dir, "main_forecast_results_table_rolling60.tex")
rolling60_md_path <- file.path(robustness_table_dir, "main_forecast_results_table_rolling60.md")
rolling180_csv_path <- file.path(robustness_table_dir, "main_forecast_results_table_rolling180.csv")
rolling180_tex_path <- file.path(robustness_table_dir, "main_forecast_results_table_rolling180.tex")
rolling180_md_path <- file.path(robustness_table_dir, "main_forecast_results_table_rolling180.md")

warnings_log <- character()

add_warning <- function(...) {
  msg <- paste0(...)
  warnings_log <<- unique(c(warnings_log, msg))
  message("WARNING: ", msg)
}

info_set_labels <- c(
  HAR = "HAR",
  HAR_O = "HAR+Option",
  HAR_M = "HAR+Macro",
  HAR_OM = "HAR+Macro+Option"
)

model_labels <- c(
  har_ols = "OLS HAR",
  pca = "PCA",
  enet = "Elastic Net",
  rf = "Random Forest",
  nn = "Neural Network"
)

model_group_labels <- c(
  har_ols = "Benchmark",
  pca = "ML",
  enet = "ML",
  rf = "ML",
  nn = "ML"
)

forecast_type_labels <- c(
  individual = "Individual",
  method_EW = "Method EW",
  infoset_EW = "Info-set EW",
  all_EW = "All EW",
  stacked = "Stacked"
)

format_model_type <- function(model, forecast_type) {
  type_label <- unname(forecast_type_labels[forecast_type])
  fallback_idx <- is.na(type_label) & !is.na(forecast_type)
  type_label[fallback_idx] <- forecast_type[fallback_idx]
  type_label[is.na(type_label)] <- "Unknown"
  paste0(model, " (", type_label, ")")
}

clean_members_string <- function(x) {
  if (length(x) == 0L || all(is.na(x))) {
    return(NA_character_)
  }
  paste(sort(unique(x[!is.na(x)])), collapse = " | ")
}

prepare_forecast_output <- function(forecast_dt,
                                    model_group,
                                    model,
                                    information_set,
                                    forecast_type,
                                    notes = NA_character_,
                                    members = NA_character_) {
  out <- copy(as.data.table(forecast_dt))

  out[, `:=`(
    model_group = model_group,
    model = model,
    information_set = information_set,
    forecast_type = forecast_type,
    target_scale = "log_rv",
    forecast_value_log = as.numeric(forecast_transformed),
    forecast_value_rv = as.numeric(forecast_level),
    realized_value_log = as.numeric(actual_transformed),
    realized_value_rv = as.numeric(actual_level),
    refit_frequency = as.integer(refit_every),
    notes = notes,
    combination_members = members
  )]

  out[, .(
    forecast_id,
    origin_date,
    target_date,
    model_group,
    model,
    information_set,
    forecast_type,
    window_type,
    refit_frequency,
    target_scale,
    forecast_value_log,
    forecast_value_rv,
    realized_value_log,
    realized_value_rv,
    notes,
    combination_members,
    benchmark_forecast
  )]
}

count_members <- function(member_string) {
  if (length(member_string) == 0L || is.na(member_string) || member_string == "") {
    return(NA_integer_)
  }
  length(strsplit(member_string, " \\| ")[[1]])
}

prepare_cached_common155_output <- function(forecast_dt) {
  dt <- copy(as.data.table(forecast_dt))

  dt[, `:=`(
    model_group = NA_character_,
    model = NA_character_,
    information_set = NA_character_,
    forecast_type = NA_character_,
    notes = "Loaded from existing common 155-date monthly-refit rolling forecast artifact.",
    combination_members = NA_character_
  )]

  dt[model_type == "har_ols", `:=`(
    model_group = "Benchmark",
    model = "OLS HAR",
    information_set = "HAR",
    forecast_type = "individual"
  )]

  for (mdl in c("pca", "enet", "rf", "nn")) {
    dt[model_type == mdl & feature_set %in% names(info_set_labels), `:=`(
      model_group = "ML",
      model = model_labels[[mdl]],
      information_set = info_set_labels[feature_set],
      forecast_type = "individual"
    )]
  }

  dt[grepl("^combo_equal_weight_.*_across_har_augmented_datasets_", forecast_id), `:=`(
    model_group = "Combination",
    information_set = "Multiple",
    forecast_type = "method_EW"
  )]
  dt[forecast_id == "combo_equal_weight_enet_across_har_augmented_datasets_log_rolling", model := "Elastic Net EW"]
  dt[forecast_id == "combo_equal_weight_pca_across_har_augmented_datasets_log_rolling", model := "PCA EW"]
  dt[forecast_id == "combo_equal_weight_rf_across_har_augmented_datasets_log_rolling", model := "Random Forest EW"]
  dt[forecast_id == "combo_equal_weight_nn_across_har_augmented_datasets_log_rolling", model := "Neural Network EW"]

  dt[grepl("^combo_equal_weight_har", forecast_id), `:=`(
    model_group = "Combination",
    model = "Equal Weight",
    forecast_type = "infoset_EW"
  )]
  dt[forecast_id == "combo_equal_weight_har_across_ml_har_augmented_log_rolling", information_set := "HAR"]
  dt[forecast_id == "combo_equal_weight_har_o_across_ml_har_augmented_log_rolling", information_set := "HAR+Option"]
  dt[forecast_id == "combo_equal_weight_har_m_across_ml_har_augmented_log_rolling", information_set := "HAR+Macro"]
  dt[forecast_id == "combo_equal_weight_har_om_across_ml_har_augmented_log_rolling", information_set := "HAR+Macro+Option"]

  dt[forecast_id == "combo_equal_weight_all_har_augmented_ml_x_dataset_log_rolling", `:=`(
    model_group = "Combination",
    model = "Equal Weight",
    information_set = "Multiple",
    forecast_type = "all_EW"
  )]

  dt[forecast_id == "stacked_enet_on_har_augmented_forecasts_log_rolling", `:=`(
    model_group = "Stacked",
    model = "Stacked Elastic Net",
    information_set = "Multiple",
    forecast_type = "stacked",
    combination_members = clean_members_string(unlist(lapply(
      c("pca", "enet", "rf", "nn"),
      function(mdl) paste0(mdl, "__", names(info_set_labels), "__log__rolling")
    )))
  )]
  dt[forecast_id == "stacked_rf_on_har_augmented_forecasts_log_rolling", `:=`(
    model_group = "Stacked",
    model = "Stacked Random Forest",
    information_set = "Multiple",
    forecast_type = "stacked",
    combination_members = clean_members_string(unlist(lapply(
      c("pca", "enet", "rf", "nn"),
      function(mdl) paste0(mdl, "__", names(info_set_labels), "__log__rolling")
    )))
  )]

  dt[forecast_type == "method_EW", combination_members := fifelse(
    grepl("enet_", forecast_id), clean_members_string(paste0("enet__", names(info_set_labels), "__log__rolling")),
    fifelse(
      grepl("pca_", forecast_id), clean_members_string(paste0("pca__", names(info_set_labels), "__log__rolling")),
      fifelse(
        grepl("rf_", forecast_id), clean_members_string(paste0("rf__", names(info_set_labels), "__log__rolling")),
        clean_members_string(paste0("nn__", names(info_set_labels), "__log__rolling"))
      )
    )
  )]

  dt[forecast_type == "infoset_EW" & information_set == "HAR", combination_members := clean_members_string(c(
    "pca__HAR__log__rolling", "enet__HAR__log__rolling", "rf__HAR__log__rolling", "nn__HAR__log__rolling"
  ))]
  dt[forecast_type == "infoset_EW" & information_set == "HAR+Option", combination_members := clean_members_string(c(
    "pca__HAR_O__log__rolling", "enet__HAR_O__log__rolling", "rf__HAR_O__log__rolling", "nn__HAR_O__log__rolling"
  ))]
  dt[forecast_type == "infoset_EW" & information_set == "HAR+Macro", combination_members := clean_members_string(c(
    "pca__HAR_M__log__rolling", "enet__HAR_M__log__rolling", "rf__HAR_M__log__rolling", "nn__HAR_M__log__rolling"
  ))]
  dt[forecast_type == "infoset_EW" & information_set == "HAR+Macro+Option", combination_members := clean_members_string(c(
    "pca__HAR_OM__log__rolling", "enet__HAR_OM__log__rolling", "rf__HAR_OM__log__rolling", "nn__HAR_OM__log__rolling"
  ))]
  dt[forecast_type == "all_EW", combination_members := clean_members_string(unlist(lapply(
    c("pca", "enet", "rf", "nn"),
    function(mdl) paste0(mdl, "__", names(info_set_labels), "__log__rolling")
  )))]

  dt[, `:=`(
    target_scale = "log_rv",
    forecast_value_log = as.numeric(forecast_transformed),
    forecast_value_rv = as.numeric(forecast_level),
    realized_value_log = as.numeric(actual_transformed),
    realized_value_rv = as.numeric(actual_level),
    refit_frequency = fifelse(is.na(refit_every), 1L, as.integer(refit_every))
  )]

  dt[, .(
    forecast_id,
    origin_date,
    target_date,
    model_group,
    model,
    information_set,
    forecast_type,
    window_type,
    refit_frequency,
    target_scale,
    forecast_value_log,
    forecast_value_rv,
    realized_value_log,
    realized_value_rv,
    notes,
    combination_members,
    benchmark_forecast
  )]
}

run_individual_spec <- function(master_data, model_type, feature_set, window_type, config) {
  run_forecast(
    data = master_data,
    model_type = model_type,
    feature_set = feature_set,
    window_type = window_type,
    initial_window = config$forecasting$initial_window,
    refit_every = config$forecasting$refit_every,
    target_type = "log",
    config = config
  )
}

build_equal_weight_combo <- function(base_dt,
                                     member_ids,
                                     combo_id,
                                     model_group,
                                     model,
                                     information_set,
                                     forecast_type,
                                     window_name,
                                     notes) {
  member_ids <- sort(unique(member_ids))
  subset_dt <- base_dt[
    forecast_id %in% member_ids &
      window_type == window_name
  ]

  if (length(member_ids) == 0L || nrow(subset_dt) == 0L) {
    add_warning("No member forecasts found for combination ", combo_id, ".")
    return(data.table())
  }

  member_count_dt <- subset_dt[, .N, by = .(target_date)]
  valid_dates <- member_count_dt[N == length(member_ids), target_date]

  if (length(valid_dates) == 0L) {
    add_warning("No common target dates across combination members for ", combo_id, ".")
    return(data.table())
  }

  combo_core <- subset_dt[target_date %in% valid_dates][
    ,
    .(
      origin_date = first(origin_date),
      forecast_value_log = mean(forecast_value_log),
      forecast_value_rv = mean(forecast_value_rv),
      realized_value_log = first(realized_value_log),
      realized_value_rv = first(realized_value_rv),
      refit_frequency = first(refit_frequency)
    ),
    by = .(target_date, window_type, target_scale)
  ]

  combo_core[, `:=`(
    forecast_id = combo_id,
    model_group = model_group,
    model = model,
    information_set = information_set,
    forecast_type = forecast_type,
    notes = notes,
    combination_members = clean_members_string(member_ids)
  )]

  setcolorder(
    combo_core,
    c(
      "forecast_id", "origin_date", "target_date", "model_group", "model",
      "information_set", "forecast_type", "window_type", "refit_frequency",
      "target_scale", "forecast_value_log", "forecast_value_rv",
      "realized_value_log", "realized_value_rv", "notes", "combination_members"
    )
  )

  combo_core[]
}

build_stacking_frame <- function(base_dt, window_name) {
  stack_input <- copy(base_dt[
    forecast_type == "individual" &
      model_group == "ML" &
      window_type == window_name
  ])

  if (nrow(stack_input) == 0L) {
    return(data.table())
  }

  forecast_wide <- dcast(
    stack_input,
    target_date + origin_date + realized_value_log + realized_value_rv ~ forecast_id,
    value.var = "forecast_value_log"
  )

  setorder(forecast_wide, target_date)
  forecast_wide[]
}

run_stacked_meta <- function(base_dt,
                             window_type,
                             meta_model,
                             config,
                             min_history = 36L) {
  stacking_dt <- build_stacking_frame(base_dt, window_name = window_type)

  if (nrow(stacking_dt) == 0L) {
    add_warning("No stacking frame available for ", meta_model, " / ", window_type, ".")
    return(data.table())
  }

  feature_cols <- setdiff(
    names(stacking_dt),
    c("target_date", "origin_date", "realized_value_log", "realized_value_rv")
  )

  model_config <- get_model_config(meta_model, config)
  min_train_rows <- max(min_history, get_min_train_rows(meta_model))
  use_rolling_history <- identical(window_type, "rolling")
  rolling_history_size <- config$forecasting$initial_window

  forecast_rows <- vector("list", nrow(stacking_dt))
  out_i <- 0L

  for (i in seq_len(nrow(stacking_dt))) {
    current_date <- stacking_dt$target_date[i]
    history_dt <- stacking_dt[target_date < current_date]

    if (use_rolling_history && nrow(history_dt) > rolling_history_size) {
      history_dt <- tail(history_dt, rolling_history_size)
    }

    if (nrow(history_dt) < min_train_rows) {
      next
    }

    current_row <- stacking_dt[i]
    available_now <- feature_cols[vapply(
      feature_cols,
      function(col) is.finite(current_row[[col]]),
      logical(1)
    )]

    if (length(available_now) < 2L) {
      next
    }

    history_counts <- vapply(
      available_now,
      function(col) sum(is.finite(history_dt[[col]]) & is.finite(history_dt$realized_value_log)),
      integer(1)
    )
    candidate_features <- available_now[history_counts >= min_train_rows]

    if (length(candidate_features) < 2L) {
      next
    }

    train_dt <- history_dt[, c("realized_value_log", candidate_features), with = FALSE]
    train_dt <- train_dt[complete.cases(train_dt)]

    if (nrow(train_dt) < min_train_rows) {
      next
    }

    X_train <- as.matrix(train_dt[, ..candidate_features])
    y_train <- train_dt$realized_value_log
    X_test <- as.matrix(current_row[, ..candidate_features])

    fitted_model <- tryCatch(
      fit_model(
        model_type = meta_model,
        X_train = X_train,
        y_train = y_train,
        config = model_config,
        feature_names = candidate_features
      ),
      error = function(e) {
        add_warning(
          "Skipping stacked ", meta_model, " forecast at ",
          as.character(current_date), " because fitting failed: ",
          conditionMessage(e)
        )
        NULL
      }
    )

    if (is.null(fitted_model)) {
      next
    }

    pred_log <- as.numeric(
      predict_model(
        fitted_model,
        X_test = X_test,
        config = model_config
      )
    )
    fitted_train <- as.numeric(
      predict_model(
        fitted_model,
        X_test = X_train,
        config = model_config
      )
    )

    log_resid_var <- stats::var(y_train - fitted_train, na.rm = TRUE)
    if (!is.finite(log_resid_var) || log_resid_var < 0) {
      log_resid_var <- 0
    }

    forecast_rv <- inverse_target_transform(
      pred_log,
      target_type = "log",
      log_resid_var = log_resid_var
    )
    forecast_rv <- enforce_positive_forecast(
      forecast_rv,
      floor_value = get_level_forecast_floor(exp(y_train), config)
    )

    out_i <- out_i + 1L
    forecast_rows[[out_i]] <- data.table(
      forecast_id = paste0("stacked_", meta_model, "__ALL_ML__log__", window_type),
      origin_date = current_row$origin_date,
      target_date = current_date,
      model_group = "Stacked",
      model = paste("Stacked", model_labels[[meta_model]]),
      information_set = "Multiple",
      forecast_type = "stacked",
      window_type = window_type,
      refit_frequency = 1L,
      target_scale = "log_rv",
      forecast_value_log = pred_log,
      forecast_value_rv = as.numeric(forecast_rv),
      realized_value_log = current_row$realized_value_log,
      realized_value_rv = current_row$realized_value_rv,
      notes = if (use_rolling_history) {
        paste0("Stacked with ", model_labels[[meta_model]], "; meta-window=", rolling_history_size, "; min_history=", min_train_rows)
      } else {
        paste0("Stacked with ", model_labels[[meta_model]], "; expanding meta-history; min_history=", min_train_rows)
      },
      combination_members = clean_members_string(candidate_features)
    )
  }

  if (out_i == 0L) {
    add_warning("No stacked forecasts were produced for ", meta_model, " / ", window_type, ".")
    return(data.table())
  }

  rbindlist(forecast_rows[seq_len(out_i)], fill = TRUE)
}

validate_forecast_alignment <- function(forecast_panel) {
  if (nrow(forecast_panel) == 0L) {
    stop("Forecast panel is empty.")
  }

  bad_dates <- forecast_panel[!is.na(origin_date) & !is.na(target_date) & target_date <= origin_date]
  if (nrow(bad_dates) > 0L) {
    stop("Alignment check failed: found forecast rows with target_date <= origin_date.")
  }

  actual_check <- forecast_panel[
    ,
    .(
      n_actual_log = uniqueN(round(realized_value_log, 12)),
      n_actual_rv = uniqueN(round(realized_value_rv, 12))
    ),
    by = .(window_type, target_date)
  ]

  if (any(actual_check$n_actual_log > 1L | actual_check$n_actual_rv > 1L)) {
    stop("Alignment check failed: actual values are inconsistent across forecasts for the same target date.")
  }
}

attach_har_benchmark <- function(forecast_panel) {
  benchmark_dt <- copy(
    forecast_panel[
      forecast_type == "individual" &
        model == "OLS HAR" &
        information_set == "HAR",
      .(
        window_type,
        target_date,
        har_forecast_log = forecast_value_log,
        har_forecast_rv = forecast_value_rv
      )
    ]
  )

  if (nrow(benchmark_dt) == 0L) {
    stop("Could not find HAR benchmark forecasts in the panel.")
  }

  merged <- merge(
    copy(forecast_panel),
    benchmark_dt,
    by = c("window_type", "target_date"),
    all.x = TRUE
  )

  missing_benchmark <- merged[is.na(har_forecast_rv)]
  if (nrow(missing_benchmark) > 0L) {
    add_warning("Some forecast rows are missing HAR benchmark matches and will be excluded from evaluation.")
  }

  merged[]
}

qlike_from_rv <- function(actual_rv, forecast_rv, eps = 1e-8) {
  # forecast_value_rv stores realized volatility in this table; QLIKE is defined on variance.
  qlike_loss_from_volatility(
    actual_vol = actual_rv,
    forecast_vol = forecast_rv,
    eps = eps
  )
}

compute_economic_metrics <- function(forecast_panel, target_vol_annual = 0.15, gamma = 5, max_leverage = 1.5) {
  market_col <- "macro_mkt_ret"
  if (!market_col %in% names(master_data)) {
    add_warning("Column ", market_col, " is missing. Utility and wealth metrics will be NA.")
    return(data.table(
      forecast_id = character(),
      utility_gain = numeric(),
      wealth_gain = numeric()
    ))
  }

  return_dt <- unique(master_data[, .(target_date = as.Date(date), market_return = as.numeric(get(market_col)))])
  target_vol_monthly <- target_vol_annual / sqrt(12)

  econ_dt <- merge(
    forecast_panel[window_type == "rolling"],
    return_dt,
    by = "target_date",
    all.x = TRUE
  )

  if (nrow(econ_dt) == 0L) {
    add_warning("No rolling forecasts available for economic evaluation.")
    return(data.table(
      forecast_id = character(),
      utility_gain = numeric(),
      wealth_gain = numeric()
    ))
  }

  econ_dt[, forecast_vol := pmax(forecast_value_rv, config$forecasting$min_positive_forecast)]
  econ_dt[, weight_raw := target_vol_monthly / forecast_vol]
  econ_dt[, weight := pmin(pmax(weight_raw, 0), max_leverage)]
  econ_dt[, portfolio_return := weight * market_return]

  summary_dt <- econ_dt[
    is.finite(portfolio_return),
    .(
      mean_return = mean(portfolio_return, na.rm = TRUE),
      var_return = stats::var(portfolio_return, na.rm = TRUE),
      terminal_wealth = prod(1 + portfolio_return, na.rm = TRUE)
    ),
    by = .(forecast_id)
  ]

  summary_dt[, cer_annualized := 12 * (mean_return - 0.5 * gamma * var_return)]

  benchmark_row <- summary_dt[forecast_id == "har_ols__HAR__log__rolling"]
  if (nrow(benchmark_row) != 1L) {
    add_warning("HAR rolling benchmark economic row missing or duplicated. Utility and wealth gains will be NA.")
    summary_dt[, `:=`(utility_gain = NA_real_, wealth_gain = NA_real_)]
    return(summary_dt[, .(forecast_id, utility_gain, wealth_gain)])
  }

  summary_dt[, `:=`(
    utility_gain = cer_annualized - benchmark_row$cer_annualized[1],
    wealth_gain = terminal_wealth - benchmark_row$terminal_wealth[1]
  )]

  summary_dt[, .(forecast_id, utility_gain, wealth_gain)]
}

compute_economic_metrics_gamma_grid <- function(forecast_panel,
                                                gamma_values = c(1, 2, 5, 10),
                                                target_vol_annual = 0.15,
                                                max_leverage = 1.5) {
  market_col <- "macro_mkt_ret"
  if (!market_col %in% names(master_data)) {
    add_warning("Column ", market_col, " is missing. Utility and wealth metrics will be NA.")
    return(data.table(
      forecast_id = character(),
      wealth_gain = numeric()
    ))
  }

  return_dt <- unique(master_data[, .(target_date = as.Date(date), market_return = as.numeric(get(market_col)))])
  target_vol_monthly <- target_vol_annual / sqrt(12)

  econ_dt <- merge(
    forecast_panel[window_type == "rolling"],
    return_dt,
    by = "target_date",
    all.x = TRUE
  )

  if (nrow(econ_dt) == 0L) {
    add_warning("No rolling forecasts available for economic evaluation.")
    return(data.table(
      forecast_id = character(),
      wealth_gain = numeric()
    ))
  }

  econ_dt[, forecast_vol := pmax(forecast_value_rv, config$forecasting$min_positive_forecast)]
  econ_dt[, weight_raw := target_vol_monthly / forecast_vol]
  econ_dt[, weight := pmin(pmax(weight_raw, 0), max_leverage)]
  econ_dt[, portfolio_return := weight * market_return]

  wealth_dt <- econ_dt[
    is.finite(portfolio_return),
    .(terminal_wealth = prod(1 + portfolio_return, na.rm = TRUE)),
    by = .(forecast_id)
  ]
  benchmark_wealth <- wealth_dt[forecast_id == "har_ols__HAR__log__rolling", terminal_wealth][1]
  wealth_dt[, wealth_gain := terminal_wealth - benchmark_wealth]
  wealth_dt <- wealth_dt[, .(forecast_id, wealth_gain)]

  utility_tables <- lapply(
    gamma_values,
    function(gamma_value) {
      utility_dt <- econ_dt[
        is.finite(portfolio_return),
        .(
          mean_return = mean(portfolio_return, na.rm = TRUE),
          var_return = stats::var(portfolio_return, na.rm = TRUE)
        ),
        by = .(forecast_id)
      ]
      utility_dt[, utility_ce := 12 * (mean_return - 0.5 * gamma_value * var_return)]
      benchmark_ce <- utility_dt[forecast_id == "har_ols__HAR__log__rolling", utility_ce][1]
      out <- utility_dt[, .(forecast_id)]
      out[[paste0("utility_gain_gamma_", gamma_value)]] <- utility_dt$utility_ce - benchmark_ce
      out
    }
  )

  Reduce(
    function(x, y) merge(x, y, by = "forecast_id", all = TRUE),
    c(list(wealth_dt), utility_tables)
  )
}

evaluate_against_har <- function(forecast_panel, compute_economic = TRUE) {
  eval_dt <- attach_har_benchmark(forecast_panel)
  eval_dt <- eval_dt[
    is.finite(realized_value_rv) &
      is.finite(forecast_value_rv) &
      is.finite(har_forecast_rv)
  ]

  eval_dt[, `:=`(
    se_model = (realized_value_rv - forecast_value_rv) ^ 2,
    se_har = (realized_value_rv - har_forecast_rv) ^ 2,
    qlike_model = qlike_from_rv(realized_value_rv, forecast_value_rv, eps = config$evaluation$qlike_epsilon),
    qlike_har = qlike_from_rv(realized_value_rv, har_forecast_rv, eps = config$evaluation$qlike_epsilon)
  )]

  summary_dt <- eval_dt[
    ,
    .(
      model_group = first(model_group),
      model = first(model),
      information_set = first(information_set),
      forecast_type = first(forecast_type),
      window_type = first(window_type),
      refit_frequency = first(refit_frequency),
      target_scale = first(target_scale),
      n_oos = .N,
      mse = mean(se_model),
      rmse = sqrt(mean(se_model)),
      rmse_har = sqrt(mean(se_har)),
      rmse_gain_vs_har = sqrt(mean(se_har)) - sqrt(mean(se_model)),
      qlike = mean(qlike_model),
      qlike_har = mean(qlike_har),
      qlike_gain_vs_har = mean(qlike_har) - mean(qlike_model),
      r2_oos_vs_har = {
        denom <- sum(se_har)
        if (is.finite(denom) && denom > 0) 1 - sum(se_model) / denom else NA_real_
      },
      notes = first(notes),
      combination_members = first(combination_members)
    ),
    by = .(forecast_id)
  ]

  if (isTRUE(compute_economic)) {
    econ_dt <- compute_economic_metrics(forecast_panel)
    summary_dt <- merge(summary_dt, econ_dt, by = "forecast_id", all.x = TRUE)
  } else {
    summary_dt[, `:=`(utility_gain = NA_real_, wealth_gain = NA_real_)]
  }

  summary_dt[window_type == "expanding", `:=`(utility_gain = NA_real_, wealth_gain = NA_real_)]

  benchmark_ids <- summary_dt[model == "OLS HAR", forecast_id]
  if (length(benchmark_ids) > 0L) {
    summary_dt[forecast_id %in% benchmark_ids, `:=`(
      r2_oos_vs_har = 0,
      qlike_gain_vs_har = 0,
      rmse_gain_vs_har = 0,
      utility_gain = fifelse(window_type == "rolling", 0, utility_gain),
      wealth_gain = fifelse(window_type == "rolling", 0, wealth_gain)
    )]
  }

  summary_dt[]
}

write_latex_table <- function(results_dt, path, digits = 5) {
  latex_lines <- knitr::kable(
    as.data.frame(results_dt),
    format = "latex",
    booktabs = TRUE,
    longtable = FALSE,
    digits = digits
  )
  writeLines(latex_lines, con = path)
}

write_md_table <- function(results_dt, path, heading_lines, digits = 5) {
  writeLines(
    c(
      heading_lines,
      "",
      knitr::kable(as.data.frame(results_dt), format = "pipe", digits = digits)
    ),
    con = path
  )
}

make_window_config <- function(config, initial_window) {
  window_config <- config
  window_config$forecasting$initial_window <- as.integer(initial_window)
  window_config
}

compute_member_counts <- function(summary_dt) {
  out <- copy(summary_dt)
  out[, members := fifelse(
    model == "OLS HAR",
    1L,
    fifelse(
      forecast_type == "individual",
      1L,
      vapply(combination_members, count_members, integer(1))
    )
  )]
  out[]
}

format_window_results <- function(summary_dt, robustness_dt = NULL) {
  dt <- compute_member_counts(summary_dt)

  if (!is.null(robustness_dt)) {
    dt <- merge(
      dt,
      robustness_dt,
      by = c("model", "information_set", "forecast_type"),
      all.x = TRUE
    )
  }

  dt[, `:=`(
    rank_r2_oos = data.table::frank(-r2_oos_vs_har, ties.method = "min"),
    rank_qlike = data.table::frank(qlike, ties.method = "min")
  )]

  setorder(dt, rank_r2_oos, rank_qlike, model, information_set)
  dt
}

build_full_rolling_window_results <- function(master_data, window_length, config) {
  window_config <- make_window_config(config, initial_window = window_length)

  specs <- rbindlist(list(
    CJ(model_type = "har_ols", feature_set = "HAR", window_type = "rolling", sorted = FALSE),
    CJ(model_type = c("pca", "enet", "rf", "nn"), feature_set = names(info_set_labels), window_type = "rolling", sorted = FALSE)
  ), fill = TRUE)

  parts <- vector("list", nrow(specs))

  for (i in seq_len(nrow(specs))) {
    spec <- specs[i]
    message(
      "[", i, "/", nrow(specs), "] Running ",
      spec$model_type, " | ", spec$feature_set, " | log | rolling | window=",
      window_length
    )

    run_i <- run_individual_spec(
      master_data = master_data,
      model_type = spec$model_type,
      feature_set = spec$feature_set,
      window_type = "rolling",
      config = window_config
    )

    parts[[i]] <- prepare_forecast_output(
      forecast_dt = run_i$forecasts,
      model_group = model_group_labels[[spec$model_type]],
      model = model_labels[[spec$model_type]],
      information_set = info_set_labels[[spec$feature_set]],
      forecast_type = "individual",
      notes = paste0("Rolling window = ", window_length, " months; monthly refit.")
    )
  }

  panel <- rbindlist(parts, fill = TRUE)
  validate_forecast_alignment(panel)

  combo_parts <- list()
  combo_i <- 0L

  for (model_type in c("pca", "enet", "rf", "nn")) {
    member_ids <- unique(panel[
      forecast_type == "individual" &
        model == model_labels[[model_type]],
      forecast_id
    ])

    combo_i <- combo_i + 1L
    combo_parts[[combo_i]] <- build_equal_weight_combo(
      base_dt = panel,
      member_ids = member_ids,
      combo_id = paste0("ew_method__", model_type, "__rolling", window_length),
      model_group = "Combination",
      model = paste(model_labels[[model_type]], "EW"),
      information_set = "Multiple",
      forecast_type = "method_EW",
      window_name = "rolling",
      notes = paste0("Rolling window = ", window_length, " months; equal weight across information sets.")
    )
  }

  for (feature_set in names(info_set_labels)) {
    member_ids <- unique(panel[
      forecast_type == "individual" &
        model %in% model_labels[c("pca", "enet", "rf", "nn")] &
        information_set == info_set_labels[[feature_set]],
      forecast_id
    ])

    combo_i <- combo_i + 1L
    combo_parts[[combo_i]] <- build_equal_weight_combo(
      base_dt = panel,
      member_ids = member_ids,
      combo_id = paste0("ew_infoset__", feature_set, "__rolling", window_length),
      model_group = "Combination",
      model = "Equal Weight",
      information_set = info_set_labels[[feature_set]],
      forecast_type = "infoset_EW",
      window_name = "rolling",
      notes = paste0("Rolling window = ", window_length, " months; equal weight across ML methods.")
    )
  }

  combo_i <- combo_i + 1L
  combo_parts[[combo_i]] <- build_equal_weight_combo(
    base_dt = panel,
    member_ids = unique(panel[forecast_type == "individual" & model_group == "ML", forecast_id]),
    combo_id = paste0("ew_all_ml__rolling", window_length),
    model_group = "Combination",
    model = "Equal Weight",
    information_set = "Multiple",
    forecast_type = "all_EW",
    window_name = "rolling",
    notes = paste0("Rolling window = ", window_length, " months; equal weight across all ML forecasts.")
  )

  combo_panel <- rbindlist(combo_parts, fill = TRUE)
  stacked_panel <- rbindlist(list(
    run_stacked_meta(panel, window_type = "rolling", meta_model = "enet", config = window_config),
    run_stacked_meta(panel, window_type = "rolling", meta_model = "rf", config = window_config)
  ), fill = TRUE)

  full_panel <- rbindlist(list(panel, combo_panel, stacked_panel), fill = TRUE)
  validate_forecast_alignment(full_panel)

  list(
    panel = full_panel,
    summary = evaluate_against_har(full_panel, compute_economic = TRUE)
  )
}

master_data <- load_master_data(config)

if (!"macro_mkt_ret" %in% names(master_data)) {
  add_warning("`macro_mkt_ret` not found in master dataset. Rolling utility/wealth metrics will be NA.")
}

cached_rolling_path <- file.path(
  config$paths$results_dir,
  "har_augmented_common155_monthly_refit_forecasts.csv"
)

if (!file.exists(cached_rolling_path)) {
  stop(
    "Missing required rolling common-155 forecast artifact: ", cached_rolling_path,
    "\nThis script now uses the earlier common-155 monthly-refit panel for the main table."
  )
}

rolling_raw <- fread(cached_rolling_path)
rolling_raw <- rolling_raw[target_type == "log" & window_type == "rolling"]
rolling_panel <- prepare_cached_common155_output(rolling_raw)
validate_forecast_alignment(rolling_panel)

expected_rolling_n <- unique(rolling_panel[, .N, by = forecast_id]$N)
if (!identical(sort(expected_rolling_n), 155L)) {
  add_warning("Rolling common sample is expected to have 155 rows for every forecast, but found: ", paste(sort(expected_rolling_n), collapse = ", "))
}

rolling_results_120 <- evaluate_against_har(rolling_panel, compute_economic = FALSE)
rolling_results_120 <- compute_member_counts(rolling_results_120)

rolling60_run <- build_full_rolling_window_results(master_data, window_length = 60L, config = config)
rolling180_run <- build_full_rolling_window_results(master_data, window_length = 180L, config = config)

rolling60_results <- format_window_results(rolling60_run$summary)
rolling180_results <- format_window_results(rolling180_run$summary)

robustness_dt_60 <- rolling60_results[, .(
  model,
  information_set,
  forecast_type,
  r2_oos_60_vs_har = r2_oos_vs_har
)]

robustness_dt_180 <- rolling180_results[, .(
  model,
  information_set,
  forecast_type,
  r2_oos_180_vs_har = r2_oos_vs_har
)]

results_dt <- merge(
  rolling_results_120,
  robustness_dt_60,
  by = c("model", "information_set", "forecast_type"),
  all.x = TRUE
)
results_dt <- merge(
  results_dt,
  robustness_dt_180,
  by = c("model", "information_set", "forecast_type"),
  all.x = TRUE
)

results_dt[, `:=`(
  rank_r2_oos = data.table::frank(-r2_oos_vs_har, ties.method = "min"),
  rank_qlike = data.table::frank(qlike, ties.method = "min")
)]

results_dt[, model := format_model_type(model, forecast_type)]

setorder(results_dt, rank_r2_oos, model, information_set)

results_dt <- results_dt[, .(
  rank_r2_oos,
  rank_qlike,
  model,
  members,
  information_set,
  n_oos,
  rmse_gain_vs_har,
  r2_oos_vs_har,
  qlike_gain_vs_har,
  r2_oos_60_vs_har,
  r2_oos_180_vs_har
)]

reported_numeric_cols <- c(
  "rmse_gain_vs_har",
  "r2_oos_vs_har",
  "qlike_gain_vs_har",
  "r2_oos_60_vs_har",
  "r2_oos_180_vs_har"
)
results_dt[, (reported_numeric_cols) := lapply(.SD, round, digits = 5), .SDcols = reported_numeric_cols]

setorder(results_dt, rank_r2_oos, model, information_set)

fwrite(results_dt, main_csv_path)
write_latex_table(results_dt, main_tex_path)
write_md_table(
  results_dt,
  main_md_path,
  c(
    "# Main Forecast Results Table",
    "",
    "Main table design:",
    "- Rolling 120-month log-RV window only in the reported rows.",
    "- Common 155-date sample for every rolling individual, equal-weight, and stacked forecast.",
    "- `model` combines the model name and forecast type; `members` is placed next to it.",
    "- The table is sorted by `rank_r2_oos`; `rank_qlike` is reported as a statistical ranking but is not used for sorting.",
    "- `rmse_gain_vs_har` is OLS HAR RMSE minus model RMSE, so positive values mean lower RMSE than HAR.",
    "- QLIKE is reported only as gain versus HAR.",
    "- `r2_oos_60_vs_har` and `r2_oos_180_vs_har` report the same specification's OOS R2 versus OLS HAR under 60- and 180-month rolling log-RV windows using each robustness run's available OOS sample."
  )
)

fwrite(rolling60_results, rolling60_csv_path)
write_latex_table(rolling60_results, rolling60_tex_path)
write_md_table(
  rolling60_results,
  rolling60_md_path,
  c(
    "# Full Results: 60-Month Rolling Window",
    "",
    "- Same model universe, combinations, and stacked forecasts as the main table.",
    "- Benchmark is rolling OLS HAR with a 60-month estimation window."
  )
)

fwrite(rolling180_results, rolling180_csv_path)
write_latex_table(rolling180_results, rolling180_tex_path)
write_md_table(
  rolling180_results,
  rolling180_md_path,
  c(
    "# Full Results: 180-Month Rolling Window",
    "",
    "- Same model universe, combinations, and stacked forecasts as the main table.",
    "- Benchmark is rolling OLS HAR with a 180-month estimation window."
  )
)

full_panel <- rbindlist(
  list(
    rolling_panel[, rolling_window_months := 120L],
    rolling60_run$panel[, rolling_window_months := 60L],
    rolling180_run$panel[, rolling_window_months := 180L]
  ),
  fill = TRUE
)
saveRDS(full_panel, forecast_panel_rds_path)
fwrite(full_panel, forecast_panel_csv_path)

individual_series <- uniqueN(rolling_panel[forecast_type == "individual", forecast_id])
combo_series <- uniqueN(rolling_panel[forecast_type %in% c("method_EW", "infoset_EW", "all_EW"), forecast_id])
stacked_series <- uniqueN(rolling_panel[forecast_type == "stacked", forecast_id])

best_r2_row <- results_dt[order(rank_r2_oos)][1]
best_qlike_row <- results_dt[order(rank_qlike, rank_r2_oos)][1]

cat("\nMain forecast pipeline completed successfully.\n")
cat("Results table: ", main_csv_path, "\n", sep = "")
cat("LaTeX table:   ", main_tex_path, "\n", sep = "")
cat("Forecast panel:", forecast_panel_csv_path, "\n\n", sep = "")

cat("Console summary\n")
cat("---------------\n")
cat("Individual forecast series produced: ", individual_series,
    " (", nrow(rolling_panel[forecast_type == "individual"]), " rolling rows)\n", sep = "")
cat("Combination forecast series produced: ", combo_series,
    " (", nrow(rolling_panel[forecast_type %in% c("method_EW", "infoset_EW", "all_EW")]), " rolling rows)\n", sep = "")
cat("Stacked forecast series produced: ", stacked_series,
    " (", nrow(rolling_panel[forecast_type == "stacked"]), " rolling rows)\n", sep = "")

if (nrow(best_r2_row) == 1L) {
  cat(
    "Best model by R2_oos: ",
    best_r2_row$model, " | ", best_r2_row$information_set,
    " | R2_oos=", sprintf("%.5f", best_r2_row$r2_oos_vs_har), "\n",
    sep = ""
  )
}

if (nrow(best_qlike_row) == 1L) {
  cat(
    "Best model by QLIKE rank: ",
    best_qlike_row$model, " | ", best_qlike_row$information_set,
    " | qlike_gain=", sprintf("%.5f", best_qlike_row$qlike_gain_vs_har), "\n",
    sep = ""
  )
}

if (length(warnings_log) == 0L) {
  cat("Warnings: none\n")
} else {
  cat("Warnings:\n")
  for (warning_msg in warnings_log) {
    cat(" - ", warning_msg, "\n", sep = "")
  }
}
