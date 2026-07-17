coerce_to_date <- function(x) {
  if (inherits(x, "Date")) {
    return(x)
  }
  as.Date(x)
}

infer_forecast_scale <- function(panel_dt,
                                 forecast_col = "forecast_model_raw",
                                 realized_var_col = "realized_var_t1",
                                 actual_col = "actual_level_model") {
  dt <- data.table::copy(data.table::as.data.table(panel_dt))
  keep <- stats::complete.cases(dt[, .SD, .SDcols = c(forecast_col, realized_var_col, actual_col)])
  dt <- dt[keep]

  if (nrow(dt) == 0L) {
    return("variance")
  }

  mae_variance <- mean(abs(dt[[forecast_col]] - dt[[realized_var_col]]), na.rm = TRUE)
  mae_volatility <- mean(abs(dt[[forecast_col]] - sqrt(pmax(dt[[realized_var_col]], 0))), na.rm = TRUE)

  if (is.finite(mae_volatility) && mae_volatility < mae_variance) {
    return("volatility")
  }

  "variance"
}

convert_forecast_to_variance <- function(x, forecast_scale = c("auto", "variance", "volatility"), realized_var = NULL) {
  forecast_scale <- match.arg(forecast_scale)

  if (forecast_scale == "auto") {
    stop("Auto scale must be resolved before conversion.")
  }

  x <- as.numeric(x)

  if (forecast_scale == "volatility") {
    return(x ^ 2)
  }

  x
}

build_high_variance_filter <- function(forecast_var,
                                       method = c("none", "value", "expanding_quantile"),
                                       threshold_value = NULL,
                                       quantile_level = 0.8,
                                       min_history = 24L) {
  method <- match.arg(method)
  forecast_var <- as.numeric(forecast_var)
  n_obs <- length(forecast_var)

  if (method == "none") {
    return(rep(TRUE, n_obs))
  }

  if (method == "value") {
    if (is.null(threshold_value) || !is.finite(threshold_value)) {
      stop("A finite threshold_value is required when method = 'value'.")
    }
    return(forecast_var <= threshold_value)
  }

  allow_trade <- rep(FALSE, n_obs)

  for (i in seq_len(n_obs)) {
    hist_idx <- seq_len(i - 1L)
    hist_vals <- forecast_var[hist_idx]
    hist_vals <- hist_vals[is.finite(hist_vals)]

    if (length(hist_vals) < min_history || !is.finite(forecast_var[i])) {
      next
    }

    cutoff <- as.numeric(stats::quantile(hist_vals, probs = quantile_level, na.rm = TRUE, type = 8))
    allow_trade[i] <- forecast_var[i] <= cutoff
  }

  allow_trade
}

build_scaled_position <- function(signal,
                                  active_flag,
                                  scaling_method = c("none", "zscore"),
                                  clip = 1,
                                  min_history = 24L) {
  scaling_method <- match.arg(scaling_method)
  signal <- as.numeric(signal)
  active_flag <- as.logical(active_flag)
  n_obs <- length(signal)
  out <- rep(0, n_obs)

  if (scaling_method == "none") {
    out[active_flag] <- 1
    return(out)
  }

  for (i in seq_len(n_obs)) {
    if (!isTRUE(active_flag[i]) || !is.finite(signal[i])) {
      next
    }

    hist_idx <- seq_len(i - 1L)
    hist_vals <- signal[hist_idx]
    hist_vals <- hist_vals[is.finite(hist_vals)]

    if (length(hist_vals) < min_history) {
      next
    }

    hist_sd <- stats::sd(hist_vals, na.rm = TRUE)
    if (!is.finite(hist_sd) || hist_sd <= 0) {
      next
    }

    out[i] <- min(clip, abs(signal[i]) / hist_sd)
  }

  out
}

compute_drawdown_series <- function(x) {
  x <- as.numeric(x)
  running_max <- cummax(x)
  x - running_max
}

prepare_cvrp_backtest_panel <- function(master_data,
                                        forecast_df,
                                        model_forecast_id,
                                        har_forecast_id = NULL,
                                        implied_var_col = "implied_var_eom",
                                        realized_var_col = "rv_var",
                                        forecast_scale = c("auto", "variance", "volatility")) {
  forecast_scale <- match.arg(forecast_scale)

  master_dt <- data.table::copy(data.table::as.data.table(master_data))
  forecast_dt <- clean_forecast_table(forecast_df)

  if (!implied_var_col %in% names(master_dt)) {
    stop("Column not found in master_data: ", implied_var_col)
  }
  if (!realized_var_col %in% names(master_dt)) {
    stop("Column not found in master_data: ", realized_var_col)
  }

  master_dt[, date := coerce_to_date(date)]
  forecast_dt[, origin_date := coerce_to_date(origin_date)]
  forecast_dt[, target_date := coerce_to_date(target_date)]

  model_dt <- forecast_dt[forecast_id == model_forecast_id]
  if (nrow(model_dt) == 0L) {
    stop("No forecast rows found for model_forecast_id = ", model_forecast_id)
  }

  if (is.null(har_forecast_id)) {
    har_dt_candidates <- forecast_dt[
      model_type == "har_ols" &
        feature_set == "HAR" &
        target_type == unique(model_dt$target_type) &
        window_type == unique(model_dt$window_type)
    ]
    har_forecast_id <- unique(har_dt_candidates$forecast_id)
    if (length(har_forecast_id) != 1L) {
      stop("Could not uniquely infer the matching HAR forecast ID for ", model_forecast_id)
    }
  }

  har_dt <- forecast_dt[forecast_id == har_forecast_id]
  if (nrow(har_dt) == 0L) {
    stop("No forecast rows found for har_forecast_id = ", har_forecast_id)
  }

  signal_dt <- master_dt[, .(
    origin_date = date,
    implied_var_signal = get(implied_var_col)
  )]

  realized_dt <- master_dt[, .(
    target_date = date,
    realized_var_t1 = get(realized_var_col)
  )]

  panel_dt <- merge(
    model_dt[, .(
      origin_date,
      target_date,
      forecast_id_model = forecast_id,
      model_type_model = model_type,
      feature_set_model = feature_set,
      target_type_model = target_type,
      window_type_model = window_type,
      forecast_model_raw = forecast_level,
      actual_level_model = actual_level
    )],
    har_dt[, .(
      origin_date,
      target_date,
      forecast_id_har = forecast_id,
      forecast_har_raw = forecast_level,
      actual_level_har = actual_level
    )],
    by = c("origin_date", "target_date"),
    all = FALSE
  )

  panel_dt <- merge(panel_dt, signal_dt, by = "origin_date", all.x = TRUE)
  panel_dt <- merge(panel_dt, realized_dt, by = "target_date", all.x = TRUE)
  data.table::setorder(panel_dt, origin_date)

  inferred_scale <- forecast_scale
  if (forecast_scale == "auto") {
    inferred_scale <- infer_forecast_scale(panel_dt)
  }

  panel_dt[, forecast_var_model := convert_forecast_to_variance(forecast_model_raw, inferred_scale)]
  panel_dt[, forecast_var_har := convert_forecast_to_variance(forecast_har_raw, inferred_scale)]

  panel_dt[, cvrp_har := implied_var_signal - forecast_var_har]
  panel_dt[, cvrp_model := implied_var_signal - forecast_var_model]
  panel_dt[, delta_cvrp := cvrp_model - cvrp_har]
  panel_dt[, short_vol_payoff := implied_var_signal - realized_var_t1]
  panel_dt[, long_vol_payoff := -short_vol_payoff]
  panel_dt[, forecast_scale_used := inferred_scale]

  required_cols <- c(
    "origin_date", "target_date", "implied_var_signal", "realized_var_t1",
    "forecast_var_model", "forecast_var_har", "cvrp_har", "cvrp_model",
    "delta_cvrp", "short_vol_payoff", "long_vol_payoff"
  )

  panel_dt[stats::complete.cases(panel_dt[, ..required_cols])]
}

run_cvrp_strategy_set <- function(panel_dt,
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
  dt <- data.table::copy(data.table::as.data.table(panel_dt))
  data.table::setorder(dt, origin_date)

  scaled_signal <- match.arg(scaled_signal)
  base_signal <- if (scaled_signal == "delta_cvrp") dt$delta_cvrp else dt$cvrp_model

  filter_forecast <- if ((high_variance_filter$forecast_source %||% "model") == "har") {
    dt$forecast_var_har
  } else {
    dt$forecast_var_model
  }

  high_var_allow <- build_high_variance_filter(
    forecast_var = filter_forecast,
    method = high_variance_filter$method %||% "none",
    threshold_value = high_variance_filter$threshold_value,
    quantile_level = high_variance_filter$quantile_level %||% 0.8,
    min_history = high_variance_filter$min_history %||% 24L
  )

  strategy_specs <- list(
    list(
      strategy_name = "always_short_vol",
      direction = "short",
      active_flag = rep(TRUE, nrow(dt)),
      filter_name = "none"
    ),
    list(
      strategy_name = "short_when_cvrp_har_positive",
      direction = "short",
      active_flag = dt$cvrp_har > (thresholds$cvrp_har %||% 0),
      filter_name = "none"
    ),
    list(
      strategy_name = "short_when_cvrp_model_positive",
      direction = "short",
      active_flag = dt$cvrp_model > (thresholds$cvrp_model %||% 0),
      filter_name = "none"
    ),
    list(
      strategy_name = "short_when_har_and_delta_positive",
      direction = "short",
      active_flag = dt$cvrp_har > (thresholds$cvrp_har %||% 0) &
        dt$delta_cvrp > (thresholds$delta_cvrp %||% 0),
      filter_name = "none"
    ),
    list(
      strategy_name = "short_when_cvrp_model_positive_filtered",
      direction = "short",
      active_flag = dt$cvrp_model > (thresholds$cvrp_model %||% 0) & high_var_allow,
      filter_name = high_variance_filter$method %||% "none"
    ),
    list(
      strategy_name = "short_when_har_and_delta_positive_filtered",
      direction = "short",
      active_flag = dt$cvrp_har > (thresholds$cvrp_har %||% 0) &
        dt$delta_cvrp > (thresholds$delta_cvrp %||% 0) &
        high_var_allow,
      filter_name = high_variance_filter$method %||% "none"
    )
  )

  if (isTRUE(include_long_vol)) {
    strategy_specs[[length(strategy_specs) + 1L]] <- list(
      strategy_name = "long_when_cvrp_model_negative",
      direction = "long",
      active_flag = dt$cvrp_model < -(thresholds$long_cvrp_model %||% 0),
      filter_name = "none"
    )
  }

  detail_rows <- vector("list", length(strategy_specs) * length(position_modes))
  out_idx <- 0L

  for (spec in strategy_specs) {
    for (position_mode in position_modes) {
      active_flag <- isTRUE(spec$direction == "short") || isTRUE(spec$direction == "long")
      active_flag <- spec$active_flag

      if (position_mode == "binary") {
        base_position <- as.numeric(active_flag)
      } else {
        base_position <- build_scaled_position(
          signal = base_signal,
          active_flag = active_flag,
          scaling_method = scaling_method,
          clip = max_abs_position,
          min_history = high_variance_filter$min_history %||% 24L
        )
      }

      signed_position <- if (spec$direction == "long") {
        -base_position
      } else {
        base_position
      }

      payoff <- if (spec$direction == "long") {
        signed_position * dt$short_vol_payoff
      } else {
        signed_position * dt$short_vol_payoff
      }

      cumulative_payoff <- cumsum(data.table::fifelse(is.finite(payoff), payoff, 0))
      drawdown <- compute_drawdown_series(cumulative_payoff)

      out_idx <- out_idx + 1L
      detail_rows[[out_idx]] <- data.table::data.table(
        origin_date = dt$origin_date,
        target_date = dt$target_date,
        model_label = model_label %||% unique(dt$forecast_id_model),
        model_forecast_id = unique(dt$forecast_id_model),
        har_forecast_id = unique(dt$forecast_id_har),
        strategy_name = spec$strategy_name,
        direction = spec$direction,
        position_mode = position_mode,
        filter_name = spec$filter_name,
        implied_var_signal = dt$implied_var_signal,
        realized_var_t1 = dt$realized_var_t1,
        forecast_var_model = dt$forecast_var_model,
        forecast_var_har = dt$forecast_var_har,
        cvrp_har = dt$cvrp_har,
        cvrp_model = dt$cvrp_model,
        delta_cvrp = dt$delta_cvrp,
        short_vol_payoff = dt$short_vol_payoff,
        position = signed_position,
        strategy_payoff = payoff,
        cumulative_payoff = cumulative_payoff,
        drawdown = drawdown,
        forecast_scale_used = dt$forecast_scale_used
      )
    }
  }

  details_dt <- data.table::rbindlist(detail_rows[seq_len(out_idx)], fill = TRUE)

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
      max_drawdown = min(drawdown, na.rm = TRUE)
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
      average_active_abs_position = mean(abs(position[abs(position) > 0]), na.rm = TRUE),
      short_share = mean(position > 0, na.rm = TRUE),
      long_share = mean(position < 0, na.rm = TRUE)
    ),
    by = .(model_label, model_forecast_id, strategy_name, direction, position_mode, filter_name)
  ]

  list(
    performance = performance_dt[],
    trade_summary = trade_summary_dt[],
    details = details_dt[]
  )
}

run_cvrp_backtest_batch <- function(master_data,
                                    forecast_df,
                                    model_forecast_ids,
                                    har_forecast_ids = NULL,
                                    implied_var_col = "implied_var_eom",
                                    realized_var_col = "rv_var",
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
  if (length(har_forecast_ids) != length(model_forecast_ids)) {
    stop("har_forecast_ids must be NULL or the same length as model_forecast_ids.")
  }

  batch_results <- vector("list", length(model_forecast_ids))

  for (i in seq_along(model_forecast_ids)) {
    model_id <- model_forecast_ids[i]
    har_id <- har_forecast_ids[i]

    panel_dt <- prepare_cvrp_backtest_panel(
      master_data = master_data,
      forecast_df = forecast_df,
      model_forecast_id = model_id,
      har_forecast_id = if (is.na(har_id)) NULL else har_id,
      implied_var_col = implied_var_col,
      realized_var_col = realized_var_col,
      forecast_scale = forecast_scale
    )

    batch_results[[i]] <- run_cvrp_strategy_set(
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

plot_cvrp_cumulative <- function(details_dt,
                                 strategy_names = NULL,
                                 position_modes = NULL,
                                 top_n_models = NULL) {
  plot_dt <- data.table::copy(data.table::as.data.table(details_dt))

  if (!is.null(strategy_names)) {
    plot_dt <- plot_dt[strategy_name %in% strategy_names]
  }
  if (!is.null(position_modes)) {
    plot_dt <- plot_dt[position_mode %in% position_modes]
  }
  if (!is.null(top_n_models)) {
    keep_models <- plot_dt[
      ,
      .(score = data.table::last(cumulative_payoff)),
      by = .(model_label)
    ][order(-score)][seq_len(min(top_n_models, .N))]$model_label
    plot_dt <- plot_dt[model_label %in% keep_models]
  }

  ggplot2::ggplot(
    plot_dt,
    ggplot2::aes(x = target_date, y = cumulative_payoff, color = strategy_name)
  ) +
    ggplot2::geom_line(linewidth = 0.7) +
    ggplot2::facet_grid(position_mode ~ model_label, scales = "free_y") +
    ggplot2::labs(
      title = "CVRP Strategy Cumulative Payoff",
      x = NULL,
      y = "Cumulative payoff"
    ) +
    ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(legend.position = "bottom")
}

plot_cvrp_drawdown <- function(details_dt,
                               strategy_names = NULL,
                               position_modes = NULL,
                               top_n_models = NULL) {
  plot_dt <- data.table::copy(data.table::as.data.table(details_dt))

  if (!is.null(strategy_names)) {
    plot_dt <- plot_dt[strategy_name %in% strategy_names]
  }
  if (!is.null(position_modes)) {
    plot_dt <- plot_dt[position_mode %in% position_modes]
  }
  if (!is.null(top_n_models)) {
    keep_models <- plot_dt[
      ,
      .(score = min(drawdown, na.rm = TRUE)),
      by = .(model_label)
    ][order(score)][seq_len(min(top_n_models, .N))]$model_label
    plot_dt <- plot_dt[model_label %in% keep_models]
  }

  ggplot2::ggplot(
    plot_dt,
    ggplot2::aes(x = target_date, y = drawdown, color = strategy_name)
  ) +
    ggplot2::geom_line(linewidth = 0.7) +
    ggplot2::facet_grid(position_mode ~ model_label, scales = "free_y") +
    ggplot2::labs(
      title = "CVRP Strategy Drawdown",
      x = NULL,
      y = "Drawdown"
    ) +
    ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(legend.position = "bottom")
}
