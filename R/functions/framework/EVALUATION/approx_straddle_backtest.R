build_approx_monthly_straddle_panel <- function(options_data,
                                                target_days = 30L,
                                                put_delta = -50L,
                                                call_delta = 50L) {
  options_dt <- data.table::copy(data.table::as.data.table(options_data))
  options_dt[, date := as.Date(date)]
  options_dt <- options_dt[ticker == "SPX" & days == target_days]

  put_dt <- options_dt[
    delta == put_delta & cp_flag == "P",
    .(
      date,
      put_strike = impl_strike,
      put_premium = impl_premium,
      put_iv = impl_volatility
    )
  ]

  call_dt <- options_dt[
    delta == call_delta & cp_flag == "C",
    .(
      date,
      call_strike = impl_strike,
      call_premium = impl_premium,
      call_iv = impl_volatility
    )
  ]

  surface_dt <- merge(put_dt, call_dt, by = "date", all = FALSE)
  surface_dt[, month_id := as.Date(format(date, "%Y-%m-01"))]

  month_end_dt <- surface_dt[, .SD[which.max(date)], by = month_id]
  data.table::setorder(month_end_dt, month_id)

  month_end_dt[, `:=`(
    entry_date = date,
    strike_proxy = 0.5 * (put_strike + call_strike),
    spot_proxy = 0.5 * (put_strike + call_strike),
    straddle_premium = put_premium + call_premium,
    next_exit_date = data.table::shift(date, type = "lead"),
    next_spot_proxy = data.table::shift(0.5 * (put_strike + call_strike), type = "lead"),
    next_put_strike = data.table::shift(put_strike, type = "lead"),
    next_call_strike = data.table::shift(call_strike, type = "lead")
  )]

  month_end_dt[, `:=`(
    approx_intrinsic_t1 = abs(next_spot_proxy - strike_proxy),
    short_straddle_payoff = straddle_premium - abs(next_spot_proxy - strike_proxy)
  )]
  month_end_dt[, long_straddle_payoff := -short_straddle_payoff]

  month_end_dt[
    !is.na(next_exit_date),
    .(
      month_id,
      entry_date,
      next_exit_date,
      strike_proxy,
      spot_proxy,
      next_spot_proxy,
      straddle_premium,
      approx_intrinsic_t1,
      short_straddle_payoff,
      long_straddle_payoff,
      put_premium,
      call_premium,
      put_iv,
      call_iv,
      target_days
    )
  ]
}

prepare_approx_straddle_backtest_panel <- function(master_data,
                                                   forecast_df,
                                                   straddle_panel,
                                                   model_forecast_id,
                                                   har_forecast_id = NULL,
                                                   implied_var_col = "implied_var_eom",
                                                   forecast_scale = c("auto", "variance", "volatility")) {
  forecast_scale <- match.arg(forecast_scale)

  signal_panel <- prepare_cvrp_backtest_panel(
    master_data = master_data,
    forecast_df = forecast_df,
    model_forecast_id = model_forecast_id,
    har_forecast_id = har_forecast_id,
    implied_var_col = implied_var_col,
    realized_var_col = "rv_var",
    forecast_scale = forecast_scale
  )

  signal_dt <- data.table::copy(data.table::as.data.table(signal_panel))
  straddle_dt <- data.table::copy(data.table::as.data.table(straddle_panel))

  signal_dt[, month_id := as.Date(format(origin_date, "%Y-%m-01"))]
  straddle_dt[, month_id := as.Date(month_id)]

  panel_dt <- merge(
    signal_dt,
    straddle_dt,
    by = "month_id",
    all = FALSE
  )

  data.table::setorder(panel_dt, origin_date)
  panel_dt
}

run_approx_straddle_strategy_set <- function(panel_dt,
                                             model_label = NULL,
                                             thresholds = list(
                                               cvrp_har = 0,
                                               cvrp_model = 0,
                                               delta_cvrp = 0,
                                               long_cvrp_model = 0
                                             ),
                                             position_modes = c("binary", "signal_scaled"),
                                             scaled_signal = c("cvrp_model", "delta_cvrp"),
                                             high_variance_filter = list(
                                               method = "expanding_quantile",
                                               quantile_level = 0.8,
                                               threshold_value = NULL,
                                               min_history = 24L,
                                               forecast_source = "model"
                                             ),
                                             include_long_vol = TRUE,
                                             max_abs_position = 1,
                                             scaling_method = "zscore") {
  signal_results <- run_cvrp_strategy_set(
    panel_dt = panel_dt,
    model_label = model_label,
    thresholds = thresholds,
    position_modes = position_modes,
    scaled_signal = scaled_signal,
    high_variance_filter = high_variance_filter,
    include_long_vol = include_long_vol,
    max_abs_position = max_abs_position,
    scaling_method = scaling_method
  )

  details_dt <- merge(
    signal_results$details,
    panel_dt[, .(
      origin_date,
      target_date,
      entry_date,
      next_exit_date,
      strike_proxy,
      spot_proxy,
      next_spot_proxy,
      straddle_premium,
      approx_intrinsic_t1,
      short_straddle_payoff,
      long_straddle_payoff
    )],
    by = c("origin_date", "target_date"),
    all.x = TRUE
  )

  details_dt[, strategy_payoff := data.table::fifelse(
    direction == "long",
    position * short_straddle_payoff,
    position * short_straddle_payoff
  )]
  details_dt[, cumulative_payoff := cumsum(data.table::fifelse(is.finite(strategy_payoff), strategy_payoff, 0)), by = .(model_label, strategy_name, position_mode)]
  details_dt[, drawdown := compute_drawdown_series(cumulative_payoff), by = .(model_label, strategy_name, position_mode)]

  performance_dt <- details_dt[
    ,
    .(
      n_months = .N,
      n_trades = sum(abs(position) > 0, na.rm = TRUE),
      trade_share = mean(abs(position) > 0, na.rm = TRUE),
      mean_payoff = mean(strategy_payoff, na.rm = TRUE),
      sd_payoff = stats::sd(strategy_payoff, na.rm = TRUE),
      annualized_mean_payoff = 12 * mean(strategy_payoff, na.rm = TRUE),
      annualized_sharpe = ifelse(
        stats::sd(strategy_payoff, na.rm = TRUE) > 0,
        sqrt(12) * mean(strategy_payoff, na.rm = TRUE) / stats::sd(strategy_payoff, na.rm = TRUE),
        NA_real_
      ),
      hit_rate = mean(strategy_payoff > 0, na.rm = TRUE),
      cumulative_payoff_final = data.table::last(cumulative_payoff),
      max_drawdown = min(drawdown, na.rm = TRUE),
      avg_entry_premium = mean(straddle_premium, na.rm = TRUE),
      avg_intrinsic_exit = mean(approx_intrinsic_t1, na.rm = TRUE)
    ),
    by = .(model_label, model_forecast_id, har_forecast_id, strategy_name, direction, position_mode, filter_name)
  ]

  trade_summary_dt <- details_dt[
    ,
    .(
      n_months = .N,
      active_months = sum(abs(position) > 0, na.rm = TRUE),
      inactive_months = sum(abs(position) == 0, na.rm = TRUE),
      average_abs_position = mean(abs(position), na.rm = TRUE),
      average_active_abs_position = mean(abs(position[abs(position) > 0]), na.rm = TRUE)
    ),
    by = .(model_label, model_forecast_id, strategy_name, direction, position_mode, filter_name)
  ]

  list(
    performance = performance_dt[],
    trade_summary = trade_summary_dt[],
    details = details_dt[]
  )
}

run_approx_straddle_backtest_batch <- function(master_data,
                                               forecast_df,
                                               straddle_panel,
                                               model_forecast_ids,
                                               har_forecast_ids = NULL,
                                               implied_var_col = "implied_var_eom",
                                               forecast_scale = c("auto", "variance", "volatility"),
                                               thresholds = list(
                                                 cvrp_har = 0,
                                                 cvrp_model = 0,
                                                 delta_cvrp = 0,
                                                 long_cvrp_model = 0
                                               ),
                                               position_modes = c("binary", "signal_scaled"),
                                               scaled_signal = c("cvrp_model", "delta_cvrp"),
                                               high_variance_filter = list(
                                                 method = "expanding_quantile",
                                                 quantile_level = 0.8,
                                                 threshold_value = NULL,
                                                 min_history = 24L,
                                                 forecast_source = "model"
                                               ),
                                               include_long_vol = TRUE,
                                               max_abs_position = 1,
                                               scaling_method = "zscore") {
  forecast_scale <- match.arg(forecast_scale)

  if (is.null(har_forecast_ids)) {
    har_forecast_ids <- rep(NA_character_, length(model_forecast_ids))
  }

  batch_results <- vector("list", length(model_forecast_ids))

  for (i in seq_along(model_forecast_ids)) {
    model_id <- model_forecast_ids[i]
    har_id <- har_forecast_ids[i]

    panel_dt <- prepare_approx_straddle_backtest_panel(
      master_data = master_data,
      forecast_df = forecast_df,
      straddle_panel = straddle_panel,
      model_forecast_id = model_id,
      har_forecast_id = if (is.na(har_id)) NULL else har_id,
      implied_var_col = implied_var_col,
      forecast_scale = forecast_scale
    )

    batch_results[[i]] <- run_approx_straddle_strategy_set(
      panel_dt = panel_dt,
      model_label = model_id,
      thresholds = thresholds,
      position_modes = position_modes,
      scaled_signal = scaled_signal,
      high_variance_filter = high_variance_filter,
      include_long_vol = include_long_vol,
      max_abs_position = max_abs_position,
      scaling_method = scaling_method
    )
  }

  list(
    performance = data.table::rbindlist(lapply(batch_results, `[[`, "performance"), fill = TRUE),
    trade_summary = data.table::rbindlist(lapply(batch_results, `[[`, "trade_summary"), fill = TRUE),
    details = data.table::rbindlist(lapply(batch_results, `[[`, "details"), fill = TRUE)
  )
}
