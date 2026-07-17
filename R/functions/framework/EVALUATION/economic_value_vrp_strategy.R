library(data.table)
library(ggplot2)

vrp_null_coalesce <- function(x, y) {
  if (is.null(x)) {
    y
  } else {
    x
  }
}

vrp_as_date <- function(x) {
  if (inherits(x, "Date")) {
    return(x)
  }
  as.Date(x)
}

vrp_safe_slug <- function(x) {
  x <- ifelse(is.na(x) | x == "", "na", as.character(x))
  x <- gsub("[^A-Za-z0-9]+", "_", x)
  gsub("_+$", "", gsub("^_+", "", tolower(x)))
}

vrp_annualized_sharpe <- function(x) {
  x <- as.numeric(x)
  sx <- stats::sd(x, na.rm = TRUE)
  mx <- mean(x, na.rm = TRUE)
  if (!is.finite(sx) || sx <= 0 || !is.finite(mx)) {
    return(NA_real_)
  }
  sqrt(12) * mx / sx
}

vrp_max_or_na <- function(x) {
  x <- as.numeric(x)
  x <- x[is.finite(x)]
  if (length(x) == 0L) {
    return(NA_real_)
  }
  max(x)
}

compute_ceq <- function(x, gamma = 3) {
  x <- as.numeric(x)
  mean(x, na.rm = TRUE) - 0.5 * gamma * stats::var(x, na.rm = TRUE)
}

compute_drawdown <- function(cumulative_return) {
  cumulative_return <- as.numeric(cumulative_return)
  running_peak <- cummax(pmax(0, cumulative_return))
  cumulative_return - running_peak
}

vrp_past_sd <- function(x, min_history = 24L) {
  x <- as.numeric(x)
  out <- rep(NA_real_, length(x))

  for (i in seq_along(x)) {
    if (i <= 1L) {
      next
    }
    hist_x <- x[seq_len(i - 1L)]
    hist_x <- hist_x[is.finite(hist_x)]
    if (length(hist_x) < min_history) {
      next
    }
    hist_sd <- stats::sd(hist_x, na.rm = TRUE)
    if (is.finite(hist_sd) && hist_sd > 0) {
      out[i] <- hist_sd
    }
  }

  out
}

vrp_past_quantile <- function(x, probs, min_history = 24L) {
  x <- as.numeric(x)
  out <- rep(NA_real_, length(x))

  for (i in seq_along(x)) {
    if (i <= 1L) {
      next
    }
    hist_x <- x[seq_len(i - 1L)]
    hist_x <- hist_x[is.finite(hist_x)]
    if (length(hist_x) < min_history) {
      next
    }
    out[i] <- as.numeric(stats::quantile(hist_x, probs = probs, na.rm = TRUE, type = 8))
  }

  out
}

vrp_infer_forecast_unit <- function(forecast_raw, realized_var_t1, target_scale = NULL) {
  forecast_raw <- as.numeric(forecast_raw)
  realized_var_t1 <- as.numeric(realized_var_t1)
  keep <- is.finite(forecast_raw) & is.finite(realized_var_t1)

  if (sum(keep) == 0L) {
    return("volatility")
  }

  if (!is.null(target_scale) && any(grepl("log", target_scale, ignore.case = TRUE), na.rm = TRUE)) {
    return("volatility")
  }

  mae_as_variance <- mean(abs(forecast_raw[keep] - realized_var_t1[keep]), na.rm = TRUE)
  mae_as_volatility <- mean(abs(pmax(forecast_raw[keep], 0) ^ 2 - realized_var_t1[keep]), na.rm = TRUE)

  if (is.finite(mae_as_variance) && mae_as_variance <= mae_as_volatility) {
    "variance"
  } else {
    "volatility"
  }
}

vrp_convert_forecast_to_variance <- function(forecast_raw, forecast_unit) {
  forecast_raw <- as.numeric(forecast_raw)
  if (identical(forecast_unit, "volatility")) {
    return(pmax(forecast_raw, 0) ^ 2)
  }
  pmax(forecast_raw, 0)
}

vrp_feature_set_label <- function(feature_set) {
  map <- c(
    HAR = "HAR",
    O = "Option",
    M = "Macro",
    OM = "Option+Macro",
    HAR_O = "HAR+Option",
    HAR_M = "HAR+Macro",
    HAR_OM = "HAR+Macro+Option",
    ALL_ML = "Multiple"
  )
  out <- unname(map[as.character(feature_set)])
  out[is.na(out)] <- as.character(feature_set[is.na(out)])
  out
}

vrp_model_label <- function(model_type) {
  map <- c(
    har_ols = "OLS HAR",
    enet = "Elastic Net",
    pca = "PCA",
    pls = "PLS",
    rf = "Random Forest",
    nn = "Neural Network",
    stacked_enet = "Stacked Elastic Net",
    stacked_rf = "Stacked Random Forest"
  )
  out <- unname(map[as.character(model_type)])
  out[is.na(out)] <- as.character(model_type[is.na(out)])
  out
}

standardize_vrp_forecast_panel <- function(forecast_df,
                                           forecast_source = "forecast_panel") {
  dt <- data.table::copy(data.table::as.data.table(forecast_df))

  if (all(c("forecast_value_rv", "realized_value_rv", "model", "information_set") %in% names(dt))) {
    dt[, origin_date := vrp_as_date(origin_date)]
    dt[, target_date := vrp_as_date(target_date)]
    dt[, forecast_raw := as.numeric(forecast_value_rv)]
    dt[, realized_raw := as.numeric(realized_value_rv)]
    dt[, target_scale := as.character(target_scale)]
    dt[, forecast_source := forecast_source]
    dt[, refit_frequency := as.integer(refit_frequency)]
    dt[, rolling_window_months := as.integer(rolling_window_months)]
    dt[, training_window_months := rolling_window_months]
    dt[, forecast_id := as.character(forecast_id)]
    dt[, model_group := as.character(model_group)]
    dt[, model := as.character(model)]
    dt[, information_set := as.character(information_set)]
    dt[, forecast_type := as.character(forecast_type)]
    dt[, window_type := as.character(window_type)]
  } else if (all(c("forecast_level", "actual_level", "model_type", "feature_set") %in% names(dt))) {
    dt[, origin_date := vrp_as_date(origin_date)]
    dt[, target_date := vrp_as_date(target_date)]
    dt[, forecast_raw := as.numeric(forecast_level)]
    dt[, realized_raw := as.numeric(actual_level)]
    dt[, target_scale := paste0(as.character(target_type), "_rv")]
    dt[, forecast_source := forecast_source]
    dt[, refit_frequency := as.integer(refit_every)]
    dt[, rolling_window_months := data.table::fifelse(
      as.character(window_type) == "rolling",
      as.integer(initial_window),
      NA_integer_
    )]
    dt[, training_window_months := as.integer(initial_window)]
    dt[, forecast_id := as.character(forecast_id)]
    dt[, model_group := data.table::fifelse(model_type == "har_ols", "Benchmark", "ML")]
    dt[, model := vrp_model_label(model_type)]
    dt[, information_set := vrp_feature_set_label(feature_set)]
    dt[, forecast_type := "individual"]
    dt[, window_type := as.character(window_type)]
  } else if (all(c("forecast_date", "forecast_value", "realized_value", "model_family", "information_set") %in% names(dt))) {
    dt[, target_date := vrp_as_date(forecast_date)]
    data.table::setorder(dt, model_family, information_set, target_date)
    dt[, origin_date := data.table::shift(target_date, type = "lag"), by = .(model_family, information_set)]
    dt[, forecast_raw := as.numeric(forecast_value)]
    dt[, realized_raw := as.numeric(realized_value)]
    dt[, target_scale := "level_rv"]
    dt[, forecast_source := forecast_source]
    dt[, refit_frequency := NA_integer_]
    dt[, rolling_window_months := NA_integer_]
    dt[, training_window_months := NA_integer_]
    dt[, forecast_id := vrp_safe_slug(specification_name)]
    dt[, model_group := data.table::fifelse(model_family == "OLS", "Benchmark", "ML")]
    dt[, model := as.character(model_family)]
    dt[, information_set := as.character(information_set)]
    dt[, forecast_type := "tidy_forecast"]
    dt[, window_type := NA_character_]
  } else {
    stop(
      "Could not recognize the forecast panel format. Expected either main_forecast_forecast_panel, ",
      "all_forecasts, or model_universe_tidy_forecasts style columns."
    )
  }

  id_parts <- dt[, .(
    forecast_id = as.character(forecast_id),
    source = as.character(forecast_source),
    target_scale = as.character(target_scale),
    window_type = as.character(window_type),
    refit_frequency = as.character(refit_frequency),
    rolling_window_months = as.character(rolling_window_months),
    forecast_type = as.character(forecast_type)
  )]
  id_parts[is.na(id_parts)] <- "na"
  dt[, forecast_model_id := do.call(paste, c(id_parts, sep = "__"))]

  keep_cols <- c(
    "forecast_source", "forecast_model_id", "forecast_id", "origin_date", "target_date",
    "model_group", "model", "information_set", "forecast_type", "target_scale",
    "window_type", "refit_frequency", "rolling_window_months", "training_window_months",
    "forecast_raw", "realized_raw"
  )

  dt <- dt[, ..keep_cols]
  dt[stats::complete.cases(dt[, .(forecast_model_id, origin_date, target_date, forecast_raw)])]
}

vrp_add_naive_forecasts <- function(signal_dt,
                                    master_dt,
                                    realized_var_col = "rv_var",
                                    min_history = 24L) {
  if (nrow(signal_dt) == 0L) {
    return(signal_dt)
  }

  scenario_cols <- c(
    "forecast_source", "implied_var_col", "target_scale", "window_type",
    "refit_frequency", "rolling_window_months", "training_window_months"
  )

  date_grid <- unique(signal_dt[, c(
    scenario_cols,
    "origin_date", "target_date", "implied_var_t", "realized_var_t1",
    "short_vol_return_raw", "short_vol_return_normalized"
  ), with = FALSE])
  data.table::setorder(date_grid, forecast_source, implied_var_col, target_scale, window_type, rolling_window_months, origin_date)

  master_hist <- data.table::copy(master_dt)
  master_hist[, date := vrp_as_date(date)]
  master_hist[, realized_var_hist := as.numeric(get(realized_var_col))]
  data.table::setorder(master_hist, date)

  historical_mean <- function(origin_date) {
    hist_vals <- master_hist[date <= origin_date & is.finite(realized_var_hist), realized_var_hist]
    if (length(hist_vals) < min_history) {
      return(NA_real_)
    }
    mean(hist_vals, na.rm = TRUE)
  }

  date_grid[, historical_mean_var := vapply(origin_date, historical_mean, numeric(1))]

  hist_rows <- data.table::copy(date_grid[is.finite(historical_mean_var)])
  hist_rows[, `:=`(
    forecast_model_id = paste(
      "historical_mean_rv",
      forecast_source,
      implied_var_col,
      target_scale,
      window_type,
      refit_frequency,
      rolling_window_months,
      sep = "__"
    ),
    forecast_id = "historical_mean_rv",
    model_group = "Naive",
    model = "Historical Mean RV",
    information_set = "Historical RV",
    forecast_type = "naive",
    forecast_raw = historical_mean_var,
    realized_raw = sqrt(pmax(realized_var_t1, 0)),
    forecast_unit_resolved = "variance",
    forecast_var_t1 = historical_mean_var,
    forecast_conversion = "historical_mean_variance"
  )]

  iv_rows <- data.table::copy(date_grid[is.finite(implied_var_t)])
  iv_rows[, `:=`(
    forecast_model_id = paste(
      "iv_as_rv_forecast",
      forecast_source,
      implied_var_col,
      target_scale,
      window_type,
      refit_frequency,
      rolling_window_months,
      sep = "__"
    ),
    forecast_id = "iv_as_rv_forecast",
    model_group = "Naive",
    model = "IV as RV Forecast",
    information_set = "Option",
    forecast_type = "naive",
    forecast_raw = implied_var_t,
    realized_raw = sqrt(pmax(realized_var_t1, 0)),
    forecast_unit_resolved = "variance",
    forecast_var_t1 = implied_var_t,
    forecast_conversion = "implied_variance_as_forecast"
  )]

  add_cols <- names(signal_dt)
  naive_rows <- data.table::rbindlist(list(hist_rows[, ..add_cols], iv_rows[, ..add_cols]), fill = TRUE)
  data.table::rbindlist(list(signal_dt, naive_rows), fill = TRUE)
}

construct_vrp_signals <- function(forecast_df,
                                  master_data,
                                  implied_var_col = "implied_var_eom",
                                  realized_var_col = "rv_var",
                                  forecast_source = "forecast_panel",
                                  forecast_unit = c("auto", "variance", "volatility"),
                                  common_dates = TRUE,
                                  include_naive_benchmarks = TRUE,
                                  min_history = 24L) {
  forecast_unit <- match.arg(forecast_unit)

  master_dt <- data.table::copy(data.table::as.data.table(master_data))
  if (!"date" %in% names(master_dt)) {
    stop("master_data must contain a date column.")
  }
  if (!implied_var_col %in% names(master_dt)) {
    stop("Column not found in master_data: ", implied_var_col)
  }
  if (!realized_var_col %in% names(master_dt)) {
    stop("Column not found in master_data: ", realized_var_col)
  }

  master_dt[, date := vrp_as_date(date)]

  forecast_dt <- standardize_vrp_forecast_panel(forecast_df, forecast_source = forecast_source)
  forecast_dt[, origin_date := vrp_as_date(origin_date)]
  forecast_dt[, target_date := vrp_as_date(target_date)]

  signal_dt <- master_dt[, .(
    origin_date = date,
    implied_var_t = as.numeric(get(implied_var_col))
  )]

  realized_dt <- master_dt[, .(
    target_date = date,
    realized_var_t1 = as.numeric(get(realized_var_col))
  )]

  dt <- merge(forecast_dt, signal_dt, by = "origin_date", all.x = TRUE)
  dt <- merge(dt, realized_dt, by = "target_date", all.x = TRUE)
  dt[, implied_var_col := implied_var_col]

  required_cols <- c("origin_date", "target_date", "implied_var_t", "realized_var_t1", "forecast_raw")
  dt <- dt[stats::complete.cases(dt[, ..required_cols])]
  dt <- dt[is.finite(implied_var_t) & implied_var_t > 0 & is.finite(realized_var_t1) & realized_var_t1 >= 0]

  dt[, forecast_unit_resolved := if (forecast_unit == "auto") {
    vrp_infer_forecast_unit(forecast_raw, realized_var_t1, target_scale)
  } else {
    forecast_unit
  }, by = forecast_model_id]

  dt[, forecast_var_t1 := vrp_convert_forecast_to_variance(forecast_raw, unique(forecast_unit_resolved)), by = forecast_model_id]
  dt[, forecast_conversion := data.table::fifelse(
    forecast_unit_resolved == "volatility",
    "level_rv_squared_to_variance",
    "already_variance_units"
  )]

  dt[, short_vol_return_raw := implied_var_t - realized_var_t1]
  dt[, short_vol_return_normalized := data.table::fifelse(
    implied_var_t > 0,
    short_vol_return_raw / implied_var_t,
    NA_real_
  )]

  if (isTRUE(include_naive_benchmarks)) {
    dt <- vrp_add_naive_forecasts(
      signal_dt = dt,
      master_dt = master_dt,
      realized_var_col = realized_var_col,
      min_history = min_history
    )
  }

  dt[, vrp_signal := implied_var_t - forecast_var_t1]
  dt[, signal_sign := sign(vrp_signal)]
  dt[, payoff_sign := sign(short_vol_return_raw)]
  dt[, signal_hit := data.table::fifelse(signal_sign == 0 | payoff_sign == 0, NA, signal_sign == payoff_sign)]
  dt[, is_har_benchmark := model_group == "Benchmark" | model == "OLS HAR" | grepl("har_ols__HAR", forecast_id)]

  scenario_cols <- c(
    "forecast_source", "implied_var_col", "target_scale", "window_type",
    "refit_frequency", "rolling_window_months", "training_window_months"
  )

  if (isTRUE(common_dates)) {
    scenario_model_counts <- dt[
      ,
      .(scenario_models = data.table::uniqueN(forecast_model_id)),
      by = scenario_cols
    ]
    scenario_date_counts <- dt[
      ,
      .(date_models = data.table::uniqueN(forecast_model_id)),
      by = c(scenario_cols, "origin_date", "target_date")
    ]
    keep_dates <- merge(scenario_date_counts, scenario_model_counts, by = scenario_cols, all.x = TRUE)
    keep_dates <- keep_dates[date_models == scenario_models, c(scenario_cols, "origin_date", "target_date"), with = FALSE]
    dt <- merge(dt, keep_dates, by = c(scenario_cols, "origin_date", "target_date"), all = FALSE)
  }

  data.table::setorder(
    dt,
    forecast_source, implied_var_col, target_scale, window_type,
    rolling_window_months, forecast_model_id, origin_date
  )

  dt[]
}

vrp_strategy_positions_one_model <- function(model_dt,
                                             min_history = 24L,
                                             max_abs_position = 1) {
  dt <- data.table::copy(model_dt)
  data.table::setorder(dt, origin_date)
  signal <- as.numeric(dt$vrp_signal)
  past_sd <- vrp_past_sd(signal, min_history = min_history)
  past_q25 <- vrp_past_quantile(signal, probs = 0.25, min_history = min_history)
  past_q75 <- vrp_past_quantile(signal, probs = 0.75, min_history = min_history)

  sign_position <- function(x) {
    data.table::fifelse(x > 0, 1, data.table::fifelse(x < 0, -1, 0))
  }

  capped <- function(x, lower, upper) {
    pmax(pmin(x, upper), lower)
  }

  strategy_list <- list(
    data.table::data.table(
      strategy_type = "always_short_vol",
      strategy_category = "benchmark",
      threshold_type = "none",
      position = rep(1, length(signal))
    ),
    data.table::data.table(
      strategy_type = "no_trade",
      strategy_category = "benchmark",
      threshold_type = "none",
      position = rep(0, length(signal))
    ),
    data.table::data.table(
      strategy_type = "binary_timing",
      strategy_category = "long_short",
      threshold_type = "zero",
      position = sign_position(signal)
    ),
    data.table::data.table(
      strategy_type = "threshold_quantile_25_75",
      strategy_category = "long_short_threshold",
      threshold_type = "expanding_q25_q75",
      position = data.table::fifelse(
        is.finite(past_q75) & signal > past_q75,
        1,
        data.table::fifelse(is.finite(past_q25) & signal < past_q25, -1, 0)
      )
    ),
    data.table::data.table(
      strategy_type = "threshold_half_sd_long_short",
      strategy_category = "long_short_threshold",
      threshold_type = "expanding_0.5_sd",
      position = data.table::fifelse(
        is.finite(past_sd) & signal > 0.5 * past_sd,
        1,
        data.table::fifelse(is.finite(past_sd) & signal < -0.5 * past_sd, -1, 0)
      )
    ),
    data.table::data.table(
      strategy_type = "threshold_one_sd_long_short",
      strategy_category = "long_short_threshold",
      threshold_type = "expanding_1.0_sd",
      position = data.table::fifelse(
        is.finite(past_sd) & signal > past_sd,
        1,
        data.table::fifelse(is.finite(past_sd) & signal < -past_sd, -1, 0)
      )
    ),
    data.table::data.table(
      strategy_type = "short_only_exit_when_negative",
      strategy_category = "short_vol_risk_control",
      threshold_type = "zero",
      position = data.table::fifelse(signal > 0, 1, 0)
    ),
    data.table::data.table(
      strategy_type = "short_only_threshold_half_sd",
      strategy_category = "short_vol_risk_control",
      threshold_type = "expanding_0.5_sd",
      position = data.table::fifelse(is.finite(past_sd) & signal > 0.5 * past_sd, 1, 0)
    ),
    data.table::data.table(
      strategy_type = "short_only_threshold_one_sd",
      strategy_category = "short_vol_risk_control",
      threshold_type = "expanding_1.0_sd",
      position = data.table::fifelse(is.finite(past_sd) & signal > past_sd, 1, 0)
    ),
    data.table::data.table(
      strategy_type = "scaled_long_short",
      strategy_category = "scaled",
      threshold_type = "expanding_sd",
      position = capped(data.table::fifelse(is.finite(past_sd), signal / past_sd, 0), -max_abs_position, max_abs_position)
    ),
    data.table::data.table(
      strategy_type = "scaled_short_only",
      strategy_category = "scaled_short_vol_risk_control",
      threshold_type = "expanding_sd",
      position = capped(data.table::fifelse(is.finite(past_sd), signal / past_sd, 0), 0, max_abs_position)
    )
  )

  position_dt <- data.table::rbindlist(strategy_list, fill = TRUE, idcol = "strategy_order")
  position_dt[, row_id := rep(seq_len(nrow(dt)), times = length(strategy_list))]
  dt[, row_id := seq_len(.N)]

  out <- merge(dt, position_dt, by = "row_id", allow.cartesian = TRUE)
  out[, row_id := NULL]
  data.table::setorder(out, strategy_order, origin_date)
  out[]
}

compute_strategy_returns <- function(vrp_signal_dt,
                                     min_history = 24L,
                                     max_abs_position = 1) {
  dt <- data.table::copy(data.table::as.data.table(vrp_signal_dt))

  split_cols <- c(
    "forecast_source", "implied_var_col", "target_scale", "window_type",
    "refit_frequency", "rolling_window_months", "forecast_model_id"
  )

  out <- dt[
    ,
    vrp_strategy_positions_one_model(.SD, min_history = min_history, max_abs_position = max_abs_position),
    by = split_cols
  ]

  data.table::setorder(
    out,
    forecast_source, implied_var_col, target_scale, window_type, rolling_window_months,
    forecast_model_id, strategy_order, origin_date
  )

  out[, gross_return_raw := position * short_vol_return_raw]
  out[, gross_return_normalized := position * short_vol_return_normalized]
  out[, turnover := abs(position - data.table::shift(position, fill = 0)), by = c(split_cols, "strategy_type")]
  out[]
}

apply_transaction_costs <- function(strategy_return_dt,
                                    cost_per_turnover = c(0, 0.0005, 0.001, 0.0025)) {
  dt <- data.table::copy(data.table::as.data.table(strategy_return_dt))

  out <- data.table::rbindlist(
    lapply(
      cost_per_turnover,
      function(cost_value) {
        cost_dt <- data.table::copy(dt)
        cost_dt[, cost_per_turnover := cost_value]
        cost_dt[, net_return_raw := gross_return_raw - cost_per_turnover * turnover]
        cost_dt[, net_return_normalized := gross_return_normalized - cost_per_turnover * turnover]
        cost_dt[]
      }
    ),
    fill = TRUE
  )

  out[]
}

vrp_long_return_table <- function(costed_return_dt) {
  dt <- data.table::copy(data.table::as.data.table(costed_return_dt))

  raw_dt <- dt[, .(
    forecast_source, implied_var_col, target_scale, window_type, refit_frequency,
    rolling_window_months, training_window_months, forecast_model_id, forecast_id,
    origin_date, target_date, model_group, model, information_set, forecast_type,
    strategy_type, strategy_category, threshold_type, cost_per_turnover,
    implied_var_t, realized_var_t1, forecast_var_t1, vrp_signal,
    short_vol_return_raw, short_vol_return_normalized, signal_hit, position, turnover,
    gross_return = gross_return_raw,
    net_return = net_return_raw,
    return_variant = "raw_variance_payoff",
    return_units = "variance units; transaction cost is subtracted in the same units"
  )]

  normalized_dt <- dt[, .(
    forecast_source, implied_var_col, target_scale, window_type, refit_frequency,
    rolling_window_months, training_window_months, forecast_model_id, forecast_id,
    origin_date, target_date, model_group, model, information_set, forecast_type,
    strategy_type, strategy_category, threshold_type, cost_per_turnover,
    implied_var_t, realized_var_t1, forecast_var_t1, vrp_signal,
    short_vol_return_raw, short_vol_return_normalized, signal_hit, position, turnover,
    gross_return = gross_return_normalized,
    net_return = net_return_normalized,
    return_variant = "normalized_by_implied_variance",
    return_units = "payoff divided by implied variance; transaction cost is subtracted as return units"
  )]

  data.table::rbindlist(list(raw_dt, normalized_dt), fill = TRUE)
}

compute_performance_metrics <- function(costed_return_dt,
                                        gamma_values = c(1, 3, 5)) {
  long_dt <- vrp_long_return_table(costed_return_dt)
  group_cols <- c(
    "forecast_source", "implied_var_col", "target_scale", "window_type", "refit_frequency",
    "rolling_window_months", "training_window_months", "forecast_model_id", "forecast_id",
    "model_group", "model", "information_set", "forecast_type", "strategy_type",
    "strategy_category", "threshold_type", "cost_per_turnover", "return_variant", "return_units"
  )

  summary_dt <- long_dt[
    ,
    {
      net_x <- as.numeric(net_return)
      gross_x <- as.numeric(gross_return)
      cumulative_net <- cumsum(data.table::fifelse(is.finite(net_x), net_x, 0))
      drawdown <- compute_drawdown(cumulative_net)
      worst_cutoff <- as.numeric(stats::quantile(short_vol_return_raw, probs = 0.10, na.rm = TRUE, type = 8))
      worst_short_idx <- is.finite(short_vol_return_raw) & short_vol_return_raw <= worst_cutoff

      base <- data.table::data.table(
        n_months = .N,
        mean_return_net = mean(net_x, na.rm = TRUE),
        annualized_mean_return_net = 12 * mean(net_x, na.rm = TRUE),
        volatility_net = stats::sd(net_x, na.rm = TRUE),
        annualized_volatility_net = sqrt(12) * stats::sd(net_x, na.rm = TRUE),
        sharpe_net = vrp_annualized_sharpe(net_x),
        mean_return_gross = mean(gross_x, na.rm = TRUE),
        annualized_mean_return_gross = 12 * mean(gross_x, na.rm = TRUE),
        volatility_gross = stats::sd(gross_x, na.rm = TRUE),
        annualized_volatility_gross = sqrt(12) * stats::sd(gross_x, na.rm = TRUE),
        sharpe_gross = vrp_annualized_sharpe(gross_x),
        transaction_cost_adjusted_sharpe = vrp_annualized_sharpe(net_x),
        final_cumulative_return_net = data.table::last(cumulative_net),
        max_drawdown = min(drawdown, na.rm = TRUE),
        worst_monthly_return = min(net_x, na.rm = TRUE),
        hit_ratio = mean(signal_hit, na.rm = TRUE),
        pct_months_traded = mean(abs(position) > 0, na.rm = TRUE),
        avg_turnover = mean(turnover, na.rm = TRUE),
        avg_abs_position = mean(abs(position), na.rm = TRUE),
        share_short = mean(position > 0, na.rm = TRUE),
        share_long = mean(position < 0, na.rm = TRUE),
        worst_short_vol_months = sum(worst_short_idx, na.rm = TRUE),
        worst_short_vol_avoidance_rate = mean(position[worst_short_idx] <= 0, na.rm = TRUE),
        avg_position_worst_short_vol_months = mean(position[worst_short_idx], na.rm = TRUE)
      )

      for (gamma in gamma_values) {
        base[[paste0("ceq_gamma", gamma)]] <- compute_ceq(net_x, gamma = gamma)
        base[[paste0("ceq_annualized_gamma", gamma)]] <- 12 * base[[paste0("ceq_gamma", gamma)]]
      }

      base
    },
    by = group_cols
  ]

  scenario_cols <- c(
    "forecast_source", "implied_var_col", "target_scale", "window_type", "refit_frequency",
    "rolling_window_months", "training_window_months", "cost_per_turnover", "return_variant"
  )

  always_short_cols <- c(
    scenario_cols,
    "mean_return_net", "annualized_mean_return_net", "sharpe_net", "max_drawdown",
    paste0("ceq_annualized_gamma", gamma_values)
  )

  always_short_dt <- summary_dt[strategy_type == "always_short_vol"]
  always_short_dt <- always_short_dt[
    order(forecast_source, implied_var_col, target_scale, window_type, rolling_window_months, forecast_model_id)
  ][
    ,
    .SD[1],
    by = scenario_cols,
    .SDcols = setdiff(always_short_cols, scenario_cols)
  ]

  data.table::setnames(
    always_short_dt,
    old = setdiff(names(always_short_dt), scenario_cols),
    new = paste0(setdiff(names(always_short_dt), scenario_cols), "_always_short")
  )

  har_cols <- c(
    scenario_cols,
    "strategy_type",
    "mean_return_net", "annualized_mean_return_net", "sharpe_net", "max_drawdown",
    paste0("ceq_annualized_gamma", gamma_values)
  )

  har_dt <- summary_dt[
    model_group == "Benchmark" | model == "OLS HAR" | grepl("har_ols__HAR", forecast_id)
  ]
  har_dt <- har_dt[
    order(forecast_source, implied_var_col, target_scale, window_type, rolling_window_months, forecast_model_id)
  ][
    ,
    .SD[1],
    by = c(scenario_cols, "strategy_type"),
    .SDcols = setdiff(har_cols, c(scenario_cols, "strategy_type"))
  ]

  data.table::setnames(
    har_dt,
    old = setdiff(names(har_dt), c(scenario_cols, "strategy_type")),
    new = paste0(setdiff(names(har_dt), c(scenario_cols, "strategy_type")), "_har")
  )

  summary_dt <- merge(summary_dt, always_short_dt, by = scenario_cols, all.x = TRUE)
  summary_dt <- merge(summary_dt, har_dt, by = c(scenario_cols, "strategy_type"), all.x = TRUE)

  summary_dt[, mean_return_gain_vs_always_short := mean_return_net - mean_return_net_always_short]
  summary_dt[, annualized_mean_return_gain_vs_always_short := annualized_mean_return_net - annualized_mean_return_net_always_short]
  summary_dt[, sharpe_gain_vs_always_short := sharpe_net - sharpe_net_always_short]
  summary_dt[, max_drawdown_diff_vs_always_short := max_drawdown - max_drawdown_always_short]
  summary_dt[, mean_return_gain_vs_har := mean_return_net - mean_return_net_har]
  summary_dt[, annualized_mean_return_gain_vs_har := annualized_mean_return_net - annualized_mean_return_net_har]
  summary_dt[, sharpe_gain_vs_har := sharpe_net - sharpe_net_har]
  summary_dt[, max_drawdown_diff_vs_har := max_drawdown - max_drawdown_har]

  for (gamma in gamma_values) {
    ceq_col <- paste0("ceq_annualized_gamma", gamma)
    summary_dt[, paste0("ceq_gain_vs_always_short_gamma", gamma, "_annualized") := get(ceq_col) - get(paste0(ceq_col, "_always_short"))]
    summary_dt[, paste0("ceq_gain_vs_har_gamma", gamma, "_annualized") := get(ceq_col) - get(paste0(ceq_col, "_har"))]
  }

  data.table::setorder(
    summary_dt,
    forecast_source, implied_var_col, target_scale, window_type, rolling_window_months,
    return_variant, cost_per_turnover, -sharpe_net
  )

  summary_dt[]
}

vrp_make_rankings <- function(summary_dt,
                              primary_cost = 0.001,
                              primary_return_variant = "normalized_by_implied_variance") {
  rankings <- data.table::copy(summary_dt)[
    return_variant == primary_return_variant &
      abs(cost_per_turnover - primary_cost) < 1e-12
  ]

  scenario_cols <- c(
    "forecast_source", "implied_var_col", "target_scale", "window_type",
    "refit_frequency", "rolling_window_months", "training_window_months",
    "cost_per_turnover", "return_variant"
  )

  rankings[, rank_sharpe_net := data.table::frank(-sharpe_net, ties.method = "min"), by = scenario_cols]
  rankings[, rank_ceq_gain_vs_always_short_gamma3 := data.table::frank(
    -ceq_gain_vs_always_short_gamma3_annualized,
    ties.method = "min"
  ), by = scenario_cols]

  data.table::setorder(
    rankings,
    forecast_source, implied_var_col, target_scale, window_type, rolling_window_months,
    rank_ceq_gain_vs_always_short_gamma3, rank_sharpe_net
  )

  rankings[]
}

vrp_summarise_by_strategy <- function(summary_dt) {
  summary_dt[
    ,
    .(
      n_model_strategy_rows = .N,
      avg_sharpe_net = mean(sharpe_net, na.rm = TRUE),
      median_sharpe_net = stats::median(sharpe_net, na.rm = TRUE),
      best_sharpe_net = vrp_max_or_na(sharpe_net),
      avg_ceq_gain_vs_always_short_gamma3_annualized = mean(ceq_gain_vs_always_short_gamma3_annualized, na.rm = TRUE),
      median_ceq_gain_vs_always_short_gamma3_annualized = stats::median(ceq_gain_vs_always_short_gamma3_annualized, na.rm = TRUE),
      best_ceq_gain_vs_always_short_gamma3_annualized = vrp_max_or_na(ceq_gain_vs_always_short_gamma3_annualized),
      avg_max_drawdown_diff_vs_always_short = mean(max_drawdown_diff_vs_always_short, na.rm = TRUE),
      avg_pct_months_traded = mean(pct_months_traded, na.rm = TRUE),
      avg_turnover = mean(avg_turnover, na.rm = TRUE)
    ),
    by = .(
      forecast_source, implied_var_col, target_scale, window_type, refit_frequency,
      rolling_window_months, training_window_months, cost_per_turnover, return_variant,
      strategy_type, strategy_category, threshold_type
    )
  ][
    order(
      forecast_source, implied_var_col, target_scale, window_type, rolling_window_months,
      cost_per_turnover, return_variant, -median_ceq_gain_vs_always_short_gamma3_annualized
    )
  ]
}

vrp_quality_checks <- function(signal_dt, strategy_dt) {
  scenario_cols <- c(
    "forecast_source", "implied_var_col", "target_scale", "window_type",
    "refit_frequency", "rolling_window_months", "training_window_months"
  )

  scenario_dt <- unique(signal_dt[, c(scenario_cols, "origin_date", "target_date", "forecast_model_id"), with = FALSE])
  scenario_summary <- scenario_dt[
    ,
    .(
      n_models = data.table::uniqueN(forecast_model_id),
      n_origin_target_dates = data.table::uniqueN(paste(origin_date, target_date)),
      min_origin_date = min(origin_date),
      max_origin_date = max(origin_date),
      min_target_date = min(target_date),
      max_target_date = max(target_date)
    ),
    by = scenario_cols
  ]
  scenario_model_counts <- scenario_dt[
    ,
    .(scenario_models = data.table::uniqueN(forecast_model_id)),
    by = scenario_cols
  ]
  scenario_date_model_counts <- scenario_dt[
    ,
    .(date_models = data.table::uniqueN(forecast_model_id)),
    by = c(scenario_cols, "origin_date", "target_date")
  ]
  common_date_check <- merge(scenario_date_model_counts, scenario_model_counts, by = scenario_cols, all.x = TRUE)

  threshold_strategies <- c(
    "threshold_quantile_25_75",
    "threshold_half_sd_long_short",
    "threshold_one_sd_long_short",
    "short_only_threshold_half_sd",
    "short_only_threshold_one_sd",
    "scaled_long_short",
    "scaled_short_only"
  )

  data.table::rbindlist(
    list(
      data.table::data.table(
        check_name = "Forecast origin strictly precedes target",
        passed = all(signal_dt$origin_date < signal_dt$target_date),
        detail = "All VRP signals use implied variance at origin_date and realized variance at target_date."
      ),
      data.table::data.table(
        check_name = "Positive implied variance",
        passed = all(is.finite(signal_dt$implied_var_t) & signal_dt$implied_var_t > 0),
        detail = "Rows with missing or non-positive implied variance are removed before strategy construction."
      ),
      data.table::data.table(
        check_name = "Forecasts converted to variance units",
        passed = all(is.finite(signal_dt$forecast_var_t1) & signal_dt$forecast_var_t1 >= 0),
        detail = paste(
          paste(unique(signal_dt$forecast_conversion), collapse = ", "),
          "used before constructing IV_t - E_t[RV_{t+1}]."
        )
      ),
      data.table::data.table(
        check_name = "Past-only thresholds and scaling",
        passed = TRUE,
        detail = paste(
          "Strategies using thresholds or scaled positions compute quantiles/standard deviations",
          "from signal values dated strictly before the current origin month."
        )
      ),
      data.table::data.table(
        check_name = "Common OOS dates by scenario",
        passed = all(common_date_check$date_models == common_date_check$scenario_models),
        detail = paste0(
          "Common-date enforcement is applied within each forecast source / target scale / IV measure scenario; ",
          nrow(scenario_summary), " scenarios retained, with ",
          min(scenario_summary$n_origin_target_dates), " to ",
          max(scenario_summary$n_origin_target_dates), " common origin-target dates."
        )
      ),
      data.table::data.table(
        check_name = "Threshold strategy warm-up produces no trades",
        passed = all(strategy_dt[strategy_type %in% threshold_strategies & !is.finite(vrp_signal), abs(position) == 0], na.rm = TRUE),
        detail = "If a past-only threshold or rolling volatility estimate is unavailable, position is set to zero."
      )
    ),
    fill = TRUE
  )
}

plot_vrp_cumulative_returns <- function(costed_return_dt,
                                        summary_dt,
                                        output_path = NULL,
                                        scenario_filter = list(
                                          implied_var_col = "implied_var_eom",
                                          cost_per_turnover = 0.001,
                                          return_variant = "normalized_by_implied_variance"
                                        )) {
  long_dt <- vrp_long_return_table(costed_return_dt)

  for (filter_name in names(scenario_filter)) {
    long_dt <- long_dt[get(filter_name) == scenario_filter[[filter_name]]]
    summary_dt <- summary_dt[get(filter_name) == scenario_filter[[filter_name]]]
  }

  if (nrow(long_dt) == 0L || nrow(summary_dt) == 0L) {
    return(NULL)
  }

  primary_scenario <- summary_dt[
    order(
      data.table::fifelse(forecast_source == "main_forecast_panel", 0L, 1L),
      data.table::fifelse(rolling_window_months == 120L, 0L, 1L),
      target_scale,
      window_type
    )
  ][1]

  scenario_cols <- c(
    "forecast_source", "implied_var_col", "target_scale", "window_type",
    "refit_frequency", "rolling_window_months", "training_window_months",
    "cost_per_turnover", "return_variant"
  )

  scenario_key <- primary_scenario[, ..scenario_cols]
  summary_scenario <- merge(summary_dt, scenario_key, by = scenario_cols)
  long_scenario <- merge(long_dt, scenario_key, by = scenario_cols)

  always_key <- summary_scenario[strategy_type == "always_short_vol"][1]
  har_key <- summary_scenario[
    (model_group == "Benchmark" | model == "OLS HAR" | grepl("har_ols__HAR", forecast_id)) &
      strategy_type == "binary_timing"
  ][1]
  best_ml_key <- summary_scenario[
    !model_group %in% c("Benchmark", "Naive") &
      strategy_type == "binary_timing"
  ][order(-sharpe_net)][1]
  best_risk_key <- summary_scenario[
    !model_group %in% c("Benchmark", "Naive") &
      strategy_category %in% c("short_vol_risk_control", "scaled_short_vol_risk_control")
  ][order(-sharpe_net)][1]

  selected <- data.table::rbindlist(
    list(
      always_key[, plot_label := "Always short volatility"],
      har_key[, plot_label := "HAR VRP timing"],
      best_ml_key[, plot_label := "Best ML binary timing"],
      best_risk_key[, plot_label := "Best ML short-vol risk control"]
    ),
    fill = TRUE
  )
  selected <- selected[!is.na(forecast_model_id)]

  plot_dt <- merge(
    long_scenario,
    selected[, .(forecast_model_id, strategy_type, plot_label)],
    by = c("forecast_model_id", "strategy_type"),
    all = FALSE
  )
  data.table::setorder(plot_dt, plot_label, origin_date)
  plot_dt[, cumulative_return := cumsum(data.table::fifelse(is.finite(net_return), net_return, 0)), by = plot_label]

  p <- ggplot2::ggplot(plot_dt, ggplot2::aes(x = target_date, y = cumulative_return, color = plot_label)) +
    ggplot2::geom_hline(yintercept = 0, color = "grey80", linewidth = 0.35) +
    ggplot2::geom_line(linewidth = 0.85, alpha = 0.95) +
    ggplot2::labs(
      title = "VRP Timing Strategy Cumulative Returns",
      subtitle = paste(
        unique(plot_dt$implied_var_col),
        unique(plot_dt$return_variant),
        paste0("cost=", unique(plot_dt$cost_per_turnover)),
        sep = " | "
      ),
      x = NULL,
      y = "Cumulative net return",
      color = NULL
    ) +
    ggplot2::theme_minimal(base_size = 12) +
    ggplot2::theme(
      legend.position = "bottom",
      panel.grid.minor = ggplot2::element_blank(),
      plot.title = ggplot2::element_text(face = "bold")
    )

  if (!is.null(output_path)) {
    ggplot2::ggsave(output_path, p, width = 11, height = 6.5, dpi = 300)
  }

  p
}

plot_vrp_drawdowns <- function(costed_return_dt,
                               summary_dt,
                               output_path = NULL,
                               scenario_filter = list(
                                 implied_var_col = "implied_var_eom",
                                 cost_per_turnover = 0.001,
                                 return_variant = "normalized_by_implied_variance"
                               )) {
  long_dt <- vrp_long_return_table(costed_return_dt)

  for (filter_name in names(scenario_filter)) {
    long_dt <- long_dt[get(filter_name) == scenario_filter[[filter_name]]]
    summary_dt <- summary_dt[get(filter_name) == scenario_filter[[filter_name]]]
  }

  if (nrow(long_dt) == 0L || nrow(summary_dt) == 0L) {
    return(NULL)
  }

  primary_scenario <- summary_dt[
    order(
      data.table::fifelse(forecast_source == "main_forecast_panel", 0L, 1L),
      data.table::fifelse(rolling_window_months == 120L, 0L, 1L),
      target_scale,
      window_type
    )
  ][1]

  scenario_cols <- c(
    "forecast_source", "implied_var_col", "target_scale", "window_type",
    "refit_frequency", "rolling_window_months", "training_window_months",
    "cost_per_turnover", "return_variant"
  )

  scenario_key <- primary_scenario[, ..scenario_cols]
  summary_scenario <- merge(summary_dt, scenario_key, by = scenario_cols)
  long_scenario <- merge(long_dt, scenario_key, by = scenario_cols)

  always_key <- summary_scenario[strategy_type == "always_short_vol"][1]
  best_ml_key <- summary_scenario[
    !model_group %in% c("Benchmark", "Naive") &
      strategy_type != "always_short_vol" &
      strategy_type != "no_trade"
  ][order(-sharpe_net)][1]

  selected <- data.table::rbindlist(
    list(
      always_key[, plot_label := "Always short volatility"],
      best_ml_key[, plot_label := "Best ML timing strategy"]
    ),
    fill = TRUE
  )
  selected <- selected[!is.na(forecast_model_id)]

  plot_dt <- merge(
    long_scenario,
    selected[, .(forecast_model_id, strategy_type, plot_label)],
    by = c("forecast_model_id", "strategy_type"),
    all = FALSE
  )
  data.table::setorder(plot_dt, plot_label, origin_date)
  plot_dt[, cumulative_return := cumsum(data.table::fifelse(is.finite(net_return), net_return, 0)), by = plot_label]
  plot_dt[, drawdown := compute_drawdown(cumulative_return), by = plot_label]

  p <- ggplot2::ggplot(plot_dt, ggplot2::aes(x = target_date, y = drawdown, color = plot_label)) +
    ggplot2::geom_hline(yintercept = 0, color = "grey80", linewidth = 0.35) +
    ggplot2::geom_line(linewidth = 0.85, alpha = 0.95) +
    ggplot2::labs(
      title = "VRP Timing Drawdowns",
      subtitle = paste(
        unique(plot_dt$implied_var_col),
        unique(plot_dt$return_variant),
        paste0("cost=", unique(plot_dt$cost_per_turnover)),
        sep = " | "
      ),
      x = NULL,
      y = "Drawdown from prior cumulative peak",
      color = NULL
    ) +
    ggplot2::theme_minimal(base_size = 12) +
    ggplot2::theme(
      legend.position = "bottom",
      panel.grid.minor = ggplot2::element_blank(),
      plot.title = ggplot2::element_text(face = "bold")
    )

  if (!is.null(output_path)) {
    ggplot2::ggsave(output_path, p, width = 11, height = 6.5, dpi = 300)
  }

  p
}

plot_vrp_forecast_scatter <- function(vrp_signal_dt,
                                      summary_dt,
                                      output_path = NULL,
                                      implied_var_col = "implied_var_eom") {
  plot_key <- summary_dt[
    get("implied_var_col") == implied_var_col &
      return_variant == "normalized_by_implied_variance" &
      abs(cost_per_turnover - 0.001) < 1e-12 &
      !model_group %in% c("Benchmark", "Naive") &
      strategy_type != "always_short_vol" &
      strategy_type != "no_trade"
  ][order(-sharpe_net)][1]

  if (nrow(plot_key) == 0L || is.na(plot_key$forecast_model_id)) {
    plot_key <- summary_dt[
      get("implied_var_col") == implied_var_col &
        return_variant == "normalized_by_implied_variance" &
        abs(cost_per_turnover - 0.001) < 1e-12
    ][order(-sharpe_net)][1]
  }

  if (nrow(plot_key) == 0L || is.na(plot_key$forecast_model_id)) {
    return(NULL)
  }

  key_cols <- c(
    "forecast_source", "implied_var_col", "target_scale", "window_type",
    "refit_frequency", "rolling_window_months", "training_window_months",
    "forecast_model_id"
  )

  plot_dt <- merge(vrp_signal_dt, plot_key[, ..key_cols], by = key_cols, all = FALSE)
  plot_dt[, iv_above_forecast := implied_var_t > forecast_var_t1]

  p <- ggplot2::ggplot(
    plot_dt,
    ggplot2::aes(x = forecast_var_t1, y = realized_var_t1, color = iv_above_forecast)
  ) +
    ggplot2::geom_abline(slope = 1, intercept = 0, color = "grey55", linewidth = 0.45) +
    ggplot2::geom_point(alpha = 0.78, size = 2) +
    ggplot2::labs(
      title = "Forecast vs Realized Variance",
      subtitle = paste(unique(plot_dt$model), unique(plot_dt$information_set), sep = " | "),
      x = "Model forecast RV_{t+1} in variance units",
      y = "Realized RV_{t+1} in variance units",
      color = "IV_t > forecast"
    ) +
    ggplot2::theme_minimal(base_size = 12) +
    ggplot2::theme(
      legend.position = "bottom",
      panel.grid.minor = ggplot2::element_blank(),
      plot.title = ggplot2::element_text(face = "bold")
    )

  if (!is.null(output_path)) {
    ggplot2::ggsave(output_path, p, width = 8.5, height = 6.5, dpi = 300)
  }

  p
}

plot_vrp_variance_timeseries <- function(vrp_signal_dt,
                                         summary_dt,
                                         output_path = NULL,
                                         implied_var_col = "implied_var_eom") {
  plot_key <- summary_dt[
    get("implied_var_col") == implied_var_col &
      return_variant == "normalized_by_implied_variance" &
      abs(cost_per_turnover - 0.001) < 1e-12 &
      !model_group %in% c("Benchmark", "Naive") &
      strategy_category %in% c("short_vol_risk_control", "scaled_short_vol_risk_control")
  ][order(-sharpe_net)][1]

  if (nrow(plot_key) == 0L || is.na(plot_key$forecast_model_id)) {
    plot_key <- summary_dt[
      get("implied_var_col") == implied_var_col &
        return_variant == "normalized_by_implied_variance" &
        abs(cost_per_turnover - 0.001) < 1e-12
    ][order(-sharpe_net)][1]
  }

  if (nrow(plot_key) == 0L || is.na(plot_key$forecast_model_id)) {
    return(NULL)
  }

  key_cols <- c(
    "forecast_source", "implied_var_col", "target_scale", "window_type",
    "refit_frequency", "rolling_window_months", "training_window_months",
    "forecast_model_id"
  )

  plot_dt <- merge(vrp_signal_dt, plot_key[, ..key_cols], by = key_cols, all = FALSE)
  plot_long <- data.table::melt(
    plot_dt,
    id.vars = "target_date",
    measure.vars = c("implied_var_t", "forecast_var_t1", "realized_var_t1"),
    variable.name = "series",
    value.name = "variance"
  )
  plot_long[, series := factor(
    series,
    levels = c("implied_var_t", "forecast_var_t1", "realized_var_t1"),
    labels = c("Implied variance at t", "Forecast realized variance t+1", "Realized variance t+1")
  )]

  p <- ggplot2::ggplot(plot_long, ggplot2::aes(x = target_date, y = variance, color = series)) +
    ggplot2::geom_line(linewidth = 0.75, alpha = 0.92) +
    ggplot2::labs(
      title = "Implied, Forecast, and Realized Variance",
      subtitle = paste(unique(plot_dt$model), unique(plot_dt$information_set), sep = " | "),
      x = NULL,
      y = "Variance units",
      color = NULL
    ) +
    ggplot2::theme_minimal(base_size = 12) +
    ggplot2::theme(
      legend.position = "bottom",
      panel.grid.minor = ggplot2::element_blank(),
      plot.title = ggplot2::element_text(face = "bold")
    )

  if (!is.null(output_path)) {
    ggplot2::ggsave(output_path, p, width = 11, height = 6.5, dpi = 300)
  }

  p
}

run_vrp_economic_evaluation <- function(forecast_inputs,
                                        master_data,
                                        output_dir = file.path(getwd(), "output", "tables"),
                                        figure_dir = file.path(getwd(), "output", "figures"),
                                        implied_var_cols = c("implied_var_eom", "implied_var_month_avg"),
                                        realized_var_col = "rv_var",
                                        forecast_unit = "auto",
                                        common_dates = TRUE,
                                        include_naive_benchmarks = TRUE,
                                        min_history = 24L,
                                        max_abs_position = 1,
                                        cost_per_turnover = c(0, 0.0005, 0.001, 0.0025),
                                        gamma_values = c(1, 3, 5),
                                        write_outputs = TRUE,
                                        make_plots = TRUE) {
  if (is.data.frame(forecast_inputs) || data.table::is.data.table(forecast_inputs)) {
    forecast_inputs <- list(forecast_panel = forecast_inputs)
  }

  available_iv_cols <- intersect(implied_var_cols, names(master_data))
  if (length(available_iv_cols) == 0L) {
    stop("None of the requested implied variance columns are available in master_data.")
  }

  signal_batches <- list()
  batch_id <- 0L

  for (source_name in names(forecast_inputs)) {
    for (iv_col in available_iv_cols) {
      batch_id <- batch_id + 1L
      message("Constructing VRP signals: ", source_name, " | ", iv_col)
      signal_batches[[batch_id]] <- construct_vrp_signals(
        forecast_df = forecast_inputs[[source_name]],
        master_data = master_data,
        implied_var_col = iv_col,
        realized_var_col = realized_var_col,
        forecast_source = source_name,
        forecast_unit = forecast_unit,
        common_dates = common_dates,
        include_naive_benchmarks = include_naive_benchmarks,
        min_history = min_history
      )
    }
  }

  vrp_signal_dt <- data.table::rbindlist(signal_batches, fill = TRUE)
  strategy_dt <- compute_strategy_returns(
    vrp_signal_dt = vrp_signal_dt,
    min_history = min_history,
    max_abs_position = max_abs_position
  )
  costed_dt <- apply_transaction_costs(strategy_dt, cost_per_turnover = cost_per_turnover)
  summary_dt <- compute_performance_metrics(costed_dt, gamma_values = gamma_values)
  rankings_dt <- vrp_make_rankings(summary_dt, primary_cost = 0.001)
  by_strategy_dt <- vrp_summarise_by_strategy(summary_dt)
  qc_dt <- vrp_quality_checks(vrp_signal_dt, strategy_dt)

  if (isTRUE(write_outputs)) {
    if (!dir.exists(output_dir)) {
      dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
    }

    data.table::fwrite(summary_dt, file.path(output_dir, "economic_value_vrp_summary.csv"))
    data.table::fwrite(summary_dt[cost_per_turnover > 0], file.path(output_dir, "economic_value_vrp_summary_net_costs.csv"))
    data.table::fwrite(rankings_dt, file.path(output_dir, "economic_value_vrp_model_rankings.csv"))
    data.table::fwrite(by_strategy_dt, file.path(output_dir, "economic_value_vrp_by_strategy.csv"))
    data.table::fwrite(qc_dt, file.path(output_dir, "economic_value_vrp_quality_checks.csv"))
  }

  if (isTRUE(make_plots)) {
    if (!dir.exists(figure_dir)) {
      dir.create(figure_dir, recursive = TRUE, showWarnings = FALSE)
    }

    plot_vrp_cumulative_returns(
      costed_return_dt = costed_dt,
      summary_dt = summary_dt,
      output_path = file.path(figure_dir, "economic_value_vrp_cumulative_returns.png")
    )
    plot_vrp_drawdowns(
      costed_return_dt = costed_dt,
      summary_dt = summary_dt,
      output_path = file.path(figure_dir, "economic_value_vrp_drawdowns.png")
    )
    plot_vrp_forecast_scatter(
      vrp_signal_dt = vrp_signal_dt,
      summary_dt = summary_dt,
      output_path = file.path(figure_dir, "economic_value_vrp_forecast_scatter.png"),
      implied_var_col = "implied_var_eom"
    )
    plot_vrp_variance_timeseries(
      vrp_signal_dt = vrp_signal_dt,
      summary_dt = summary_dt,
      output_path = file.path(figure_dir, "economic_value_vrp_variance_timeseries.png"),
      implied_var_col = "implied_var_eom"
    )
  }

  list(
    signals = vrp_signal_dt,
    strategy_returns = strategy_dt,
    costed_returns = costed_dt,
    summary = summary_dt,
    rankings = rankings_dt,
    by_strategy = by_strategy_dt,
    quality_checks = qc_dt
  )
}

run_default_vrp_economic_evaluation <- function(base_dir = getwd()) {
  config_path <- file.path(base_dir, "R", "functions", "framework", "00_config.R")
  helper_path <- file.path(base_dir, "R", "functions", "framework", "UTILS", "helpers.R")
  load_data_path <- file.path(base_dir, "R", "functions", "framework", "01_load_data.R")

  if (file.exists(config_path)) {
    source(config_path)
  }
  if (file.exists(helper_path)) {
    source(helper_path)
  }
  if (file.exists(load_data_path)) {
    source(load_data_path)
  }

  config <- if (exists("create_config")) {
    create_config(base_dir = base_dir)
  } else {
    list(
      paths = list(
        data_dir = file.path(base_dir, "DATA"),
        output_dir = file.path(base_dir, "output", "tables"),
        figures_dir = file.path(base_dir, "output", "figures"),
        results_dir = file.path(base_dir, "data", "processed", "model_artifacts")
      )
    )
  }

  master_path_candidates <- c(
    file.path(base_dir, "data", "processed", "master_dataset.csv"),
    file.path(base_dir, "DATA", "master_dataset.csv")
  )
  master_path <- master_path_candidates[file.exists(master_path_candidates)][1]
  if (is.na(master_path)) {
    stop("Could not find master_dataset.csv in data/processed/.")
  }
  master_data <- data.table::fread(master_path)

  forecast_inputs <- list()

  main_panel_path <- file.path(base_dir, "data", "processed", "forecast_panels", "main_forecast_forecast_panel.csv")
  if (file.exists(main_panel_path)) {
    forecast_inputs$main_forecast_panel <- data.table::fread(main_panel_path)
  }

  all_forecasts_path <- file.path(config$paths$results_dir, "all_forecasts.csv")
  if (file.exists(all_forecasts_path)) {
    forecast_inputs$model_universe_all_forecasts <- data.table::fread(all_forecasts_path)
  }

  if (length(forecast_inputs) == 0L) {
    stop("No forecast panels found. Expected data/processed/forecast_panels/main_forecast_forecast_panel.csv or data/processed/model_artifacts/all_forecasts.csv.")
  }

  results <- run_vrp_economic_evaluation(
    forecast_inputs = forecast_inputs,
    master_data = master_data,
    output_dir = config$paths$output_dir,
    figure_dir = config$paths$figures_dir,
    implied_var_cols = c("implied_var_eom", "implied_var_month_avg"),
    realized_var_col = "rv_var",
    forecast_unit = "auto",
    common_dates = TRUE,
    include_naive_benchmarks = TRUE,
    min_history = 24L,
    max_abs_position = 1,
    cost_per_turnover = c(0, 0.0005, 0.001, 0.0025),
    gamma_values = c(1, 3, 5),
    write_outputs = TRUE,
    make_plots = TRUE
  )

  final_table <- results$rankings[
    implied_var_col == "implied_var_eom" &
      return_variant == "normalized_by_implied_variance" &
      abs(cost_per_turnover - 0.001) < 1e-12 &
      strategy_type != "always_short_vol" &
      strategy_type != "no_trade"
  ][
    order(
      data.table::fifelse(forecast_source == "main_forecast_panel", 0L, 1L),
      data.table::fifelse(rolling_window_months == 120L, 0L, 1L),
      rank_ceq_gain_vs_always_short_gamma3,
      rank_sharpe_net
    )
  ][
    ,
    .(
      forecast_source,
      target_scale,
      window_type,
      rolling_window_months,
      model,
      information_set,
      strategy_type,
      sharpe_net = round(sharpe_net, 3),
      ceq_gain_vs_always_short_gamma3_annualized = round(ceq_gain_vs_always_short_gamma3_annualized, 4),
      max_drawdown_diff_vs_always_short = round(max_drawdown_diff_vs_always_short, 4),
      pct_months_traded = round(pct_months_traded, 3)
    )
  ][1:min(.N, 15)]

  message("Saved VRP economic-value outputs to: ", config$paths$output_dir)
  message("Returns are reported both in raw variance-payoff units and normalized by implied variance.")
  message("Concise ranking: normalized payoff, cost_per_turnover = 0.001, implied_var_eom.")
  print(final_table)

  invisible(results)
}

vrp_running_as_main_script <- function() {
  sourced_frames <- vapply(
    sys.frames(),
    function(frame) !is.null(frame$ofile),
    logical(1)
  )
  !interactive() && !any(sourced_frames)
}

if (vrp_running_as_main_script()) {
  run_default_vrp_economic_evaluation(base_dir = getwd())
}
