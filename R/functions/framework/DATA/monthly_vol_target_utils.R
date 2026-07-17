build_monthly_spy_5min_vol <- function(data_path = file.path("data", "raw", ""), month_position = c("end", "start")) {
  month_position <- match.arg(month_position)

  spy_daily_5min_vol <- data.table::fread(
    paste0(data_path, "SPY_daily_5min_vol.csv")
  ) |>
    dplyr::transmute(
      date = as.Date(Date),
      daily_vol = as.numeric(Volatility)
    ) |>
    dplyr::filter(!is.na(date), !is.na(daily_vol)) |>
    dplyr::arrange(date)

  month_dates <- if (month_position == "end") {
    lubridate::ceiling_date(spy_daily_5min_vol$date, unit = "month") - lubridate::days(1)
  } else {
    lubridate::floor_date(spy_daily_5min_vol$date, unit = "month")
  }

  spy_daily_5min_vol |>
    dplyr::mutate(month = month_dates) |>
    dplyr::group_by(month) |>
    dplyr::summarise(
      trading_days = dplyr::n(),
      realized_var = mean(daily_vol^2, na.rm = TRUE),
      realized_vol = sqrt(realized_var),
      realized_vol_annualized = realized_vol,
      .groups = "drop"
    ) |>
    dplyr::arrange(month)
}

lag_monthly_predictors <- function(data, date_col = "month") {
  predictor_cols <- setdiff(names(data), date_col)
  ordered_data <- data[order(data[[date_col]]), , drop = FALSE]

  dplyr::mutate(
    ordered_data,
    dplyr::across(
      dplyr::all_of(predictor_cols),
      dplyr::lag
    )
  )
}

get_available_forecast_predictors <- function(
  train_data,
  current_data,
  predictor_names,
  min_non_missing = 24L
) {
  available_predictors <- predictor_names[
    !purrr::map_lgl(
      predictor_names,
      ~ {
        current_value <- current_data[[.x]]
        length(current_value) == 0 || is.na(current_value[[1]])
      }
    )
  ]

  available_predictors[
    purrr::map_int(
      available_predictors,
      ~ sum(!is.na(train_data[[.x]]))
    ) >= min_non_missing
  ]
}

build_forward_realized_var_forecast <- function(
  realized_vol_data,
  initial_window = 120,
  min_train_obs = 36
) {
  forecast_data <- realized_vol_data |>
    dplyr::arrange(month) |>
    dplyr::mutate(
      har_var_1 = realized_var,
      har_var_3 = data.table::frollmean(realized_var, n = 3, align = "right"),
      har_var_12 = data.table::frollmean(realized_var, n = 12, align = "right"),
      next_realized_var = dplyr::lead(realized_var),
      next_realized_vol = dplyr::lead(realized_vol)
    )

  n_obs <- nrow(forecast_data)
  expected_next_realized_var <- rep(NA_real_, n_obs)

  if (n_obs == 0) {
    return(
      forecast_data |>
        dplyr::transmute(
          month,
          expected_next_realized_var = NA_real_,
          expected_next_realized_vol = NA_real_
        )
    )
  }

  har_formula <- next_realized_var ~ har_var_1 + har_var_3 + har_var_12
  start_index <- max(initial_window, 12L) + 1L

  for (i in seq.int(start_index, n_obs)) {
    train_subset <- forecast_data[1:(i - 1), , drop = FALSE] |>
      dplyr::select(next_realized_var, har_var_1, har_var_3, har_var_12) |>
      tidyr::drop_na()

    current_subset <- forecast_data[i, , drop = FALSE] |>
      dplyr::select(har_var_1, har_var_3, har_var_12)

    if (nrow(train_subset) < min_train_obs || any(is.na(current_subset))) {
      next
    }

    har_fit <- stats::lm(har_formula, data = train_subset)
    expected_next_realized_var[i] <- as.numeric(
      stats::predict(har_fit, newdata = current_subset)
    )
  }

  forecast_data |>
    dplyr::transmute(
      month,
      expected_next_realized_var = expected_next_realized_var,
      expected_next_realized_vol = sqrt(pmax(expected_next_realized_var, 0))
    )
}

build_monthly_factor_matrix <- function(
  data_path = file.path("data", "raw", ""),
  start_date = as.Date("1972-01-31"),
  lag_predictors = TRUE
) {
  factor_data <- data.table::fread(
    paste0(data_path, "[usa]_[all_factors]_[monthly]_[vw_cap].csv")
  ) |>
    dplyr::select(date, name, ret) |>
    tidyr::pivot_wider(names_from = name, values_from = ret) |>
    dplyr::mutate(date = as.Date(date)) |>
    dplyr::arrange(date)

  if (!is.null(start_date)) {
    factor_data <- dplyr::filter(factor_data, date >= start_date)
  }

  if (lag_predictors) {
    factor_data <- lag_monthly_predictors(factor_data, date_col = "date")
  }

  factor_data
}

get_option_signal_names <- function() {
  c(
    "implied_var_eom",
    "atm_iv_eom",
    "put_25_iv_eom",
    "call_25_iv_eom",
    "skew_25_eom",
    "downside_skew_eom",
    "smile_curvature_25_eom",
    "skew_10_eom",
    "downside_skew_10_eom",
    "smile_curvature_10_eom",
    "atm_dispersion_eom",
    "put_25_dispersion_eom",
    "mean_dispersion_eom",
    "atm_iv_month_avg",
    "implied_var_month_avg",
    "vrp_forward_eom",
    "vrp_forward_month_avg",
    "skew_25_month_avg",
    "smile_curvature_25_month_avg",
    "mean_dispersion_month_avg"
  )
}

build_monthly_option_signals <- function(
  data_path = file.path("data", "raw", ""),
  realized_vol_data = NULL,
  lag_predictors = FALSE
) {
  options_spx <- data.table::fread(paste0(data_path, "Options_data_SPX.csv"))

  if (is.null(realized_vol_data)) {
    realized_vol_data <- build_monthly_spy_5min_vol(
      data_path = data_path,
      month_position = "end"
    )
  }

  forward_var_forecasts <- build_forward_realized_var_forecast(
    realized_vol_data = realized_vol_data
  )

  daily_option_signals <- options_spx |>
    dplyr::mutate(
      date = as.Date(date),
      month = lubridate::ceiling_date(date, unit = "month") - lubridate::days(1)
    ) |>
    dplyr::group_by(date, month) |>
    dplyr::summarise(
      atm_iv = mean(impl_volatility[abs(delta) == 50], na.rm = TRUE),
      put_25_iv = mean(impl_volatility[delta == -25 & cp_flag == "P"], na.rm = TRUE),
      call_25_iv = mean(impl_volatility[delta == 25 & cp_flag == "C"], na.rm = TRUE),
      put_10_iv = mean(impl_volatility[delta == -10 & cp_flag == "P"], na.rm = TRUE),
      call_10_iv = mean(impl_volatility[delta == 10 & cp_flag == "C"], na.rm = TRUE),
      atm_dispersion = mean(dispersion[abs(delta) == 50], na.rm = TRUE),
      put_25_dispersion = mean(dispersion[delta == -25 & cp_flag == "P"], na.rm = TRUE),
      mean_dispersion = mean(dispersion, na.rm = TRUE),
      .groups = "drop"
    ) |>
    dplyr::mutate(
      skew_25 = put_25_iv - call_25_iv,
      downside_skew = put_25_iv - atm_iv,
      smile_curvature_25 = 0.5 * (put_25_iv + call_25_iv) - atm_iv,
      skew_10 = put_10_iv - call_10_iv,
      downside_skew_10 = put_10_iv - atm_iv,
      smile_curvature_10 = 0.5 * (put_10_iv + call_10_iv) - atm_iv
    )

  monthly_option_signals <- daily_option_signals |>
    dplyr::group_by(month) |>
    dplyr::summarise(
      atm_iv_eom = dplyr::last(atm_iv),
      put_25_iv_eom = dplyr::last(put_25_iv),
      call_25_iv_eom = dplyr::last(call_25_iv),
      skew_25_eom = dplyr::last(skew_25),
      downside_skew_eom = dplyr::last(downside_skew),
      smile_curvature_25_eom = dplyr::last(smile_curvature_25),
      skew_10_eom = dplyr::last(skew_10),
      downside_skew_10_eom = dplyr::last(downside_skew_10),
      smile_curvature_10_eom = dplyr::last(smile_curvature_10),
      atm_dispersion_eom = dplyr::last(atm_dispersion),
      put_25_dispersion_eom = dplyr::last(put_25_dispersion),
      mean_dispersion_eom = dplyr::last(mean_dispersion),
      atm_iv_month_avg = mean(atm_iv, na.rm = TRUE),
      skew_25_month_avg = mean(skew_25, na.rm = TRUE),
      smile_curvature_25_month_avg = mean(smile_curvature_25, na.rm = TRUE),
      mean_dispersion_month_avg = mean(mean_dispersion, na.rm = TRUE),
      .groups = "drop"
    ) |>
    dplyr::arrange(month) |>
    dplyr::mutate(
      implied_var_eom = atm_iv_eom^2,
      implied_var_month_avg = atm_iv_month_avg^2
    ) |>
    dplyr::left_join(
      dplyr::transmute(
        realized_vol_data,
        month,
        realized_var,
        realized_vol
      ),
      by = "month"
    ) |>
    dplyr::left_join(
      forward_var_forecasts,
      by = "month"
    ) |>
    dplyr::mutate(
      vrp_expost_eom = implied_var_eom - realized_var,
      vrp_expost_month_avg = implied_var_month_avg - realized_var,
      vrp_forward_eom = implied_var_eom - expected_next_realized_var,
      vrp_forward_month_avg = implied_var_month_avg - expected_next_realized_var
    ) |>
    dplyr::left_join(
      dplyr::transmute(
        realized_vol_data,
        month,
        next_month_realized_var = dplyr::lead(realized_var),
        next_month_realized_vol = dplyr::lead(realized_vol)
      ),
      by = "month"
    ) |>
    dplyr::mutate(
      vrp_eom = implied_var_eom - next_month_realized_var,
      vrp_month_avg = implied_var_month_avg - next_month_realized_var
    )

  if (lag_predictors) {
    monthly_option_signals <- lag_monthly_predictors(
      monthly_option_signals,
      date_col = "month"
    )
  }

  monthly_option_signals
}

build_monthly_model_dataset <- function(
  data_path = file.path("data", "raw", ""),
  start_date = as.Date("1972-01-31")
) {
  monthly_realized_vol <- build_monthly_spy_5min_vol(
    data_path = data_path,
    month_position = "end"
  ) |>
    dplyr::filter(month >= start_date) |>
    dplyr::mutate(
      vol_lag1 = dplyr::lag(realized_vol, 1),
      vol_lag3 = data.table::frollmean(dplyr::lag(realized_vol, 1), n = 3, align = "right"),
      vol_lag12 = data.table::frollmean(dplyr::lag(realized_vol, 1), n = 12, align = "right")
    )

  factor_data <- build_monthly_factor_matrix(
    data_path = data_path,
    start_date = start_date,
    lag_predictors = TRUE
  )

  option_data <- build_monthly_option_signals(
    data_path = data_path,
    realized_vol_data = monthly_realized_vol,
    lag_predictors = TRUE
  ) |>
    # Keep only forecasting-safe option signals. Variables that use realized
    # next-month variance directly are retained only for descriptive use.
    dplyr::select(month, dplyr::all_of(get_option_signal_names()))

  model_data <- monthly_realized_vol |>
    dplyr::inner_join(factor_data, by = c("month" = "date")) |>
    dplyr::left_join(option_data, by = "month") |>
    dplyr::arrange(month) |>
    dplyr::filter(!is.na(vol_lag1), !is.na(vol_lag3), !is.na(vol_lag12))

  list(
    monthly_realized_vol = monthly_realized_vol,
    factor_data = factor_data,
    option_data = option_data,
    model_data = model_data
  )
}

default_nw_lag <- function(n) {
  max(0L, floor(1.2 * n^(1 / 3)))
}

qlike_loss <- function(actual_var, forecast_var, eps = 1e-8) {
  actual_var <- pmax(actual_var, eps)
  forecast_var <- pmax(forecast_var, eps)
  loss_ratio <- actual_var / forecast_var
  loss_ratio - log(loss_ratio) - 1
}

newey_west_covariance <- function(X, residuals, lags = NULL) {
  X <- as.matrix(X)
  residuals <- as.numeric(residuals)
  n <- nrow(X)

  if (is.null(lags)) {
    lags <- default_nw_lag(n)
  }

  xtx_inv <- solve(crossprod(X))
  score_matrix <- X * residuals
  omega <- crossprod(score_matrix)

  if (lags > 0) {
    for (lag in seq_len(lags)) {
      weight <- 1 - lag / (lags + 1)
      gamma_lag <- crossprod(score_matrix[(lag + 1):n, , drop = FALSE], score_matrix[1:(n - lag), , drop = FALSE])
      omega <- omega + weight * (gamma_lag + t(gamma_lag))
    }
  }

  xtx_inv %*% omega %*% xtx_inv
}

newey_west_coefficient_test <- function(y, X, coef_index, lags = NULL) {
  X <- as.matrix(X)

  if (is.null(dim(X))) {
    X <- matrix(X, ncol = 1)
  }

  if (nrow(X) == 1 && length(y) > 1) {
    X <- matrix(
      rep(as.numeric(X[1, ]), each = length(y)),
      nrow = length(y),
      byrow = FALSE,
      dimnames = list(NULL, colnames(X))
    )
  }

  complete_index <- stats::complete.cases(cbind(y, X))
  y_clean <- y[complete_index]
  X_clean <- X[complete_index, , drop = FALSE]

  if (length(y_clean) <= ncol(X_clean)) {
    return(tibble::tibble(
      estimate = NA_real_,
      statistic = NA_real_,
      p_value = NA_real_
    ))
  }

  fit <- stats::lm.fit(x = X_clean, y = y_clean)
  covariance_matrix <- newey_west_covariance(X_clean, fit$residuals, lags = lags)
  standard_error <- sqrt(diag(covariance_matrix))[coef_index]
  estimate <- fit$coefficients[coef_index]
  statistic <- estimate / standard_error
  p_value <- 2 * stats::pnorm(abs(statistic), lower.tail = FALSE)

  tibble::tibble(
    estimate = estimate,
    statistic = statistic,
    p_value = p_value
  )
}

dm_test <- function(loss_model, loss_benchmark, lags = NULL) {
  loss_data <- tibble::tibble(
    diff = loss_model - loss_benchmark
  ) |>
    tidyr::drop_na()

  if (nrow(loss_data) <= 5) {
    return(tibble::tibble(
      mean_loss_diff = NA_real_,
      statistic = NA_real_,
      p_value = NA_real_
    ))
  }

  dm_fit <- newey_west_coefficient_test(
    y = loss_data$diff,
    X = matrix(1, nrow = nrow(loss_data), ncol = 1, dimnames = list(NULL, "(Intercept)")),
    coef_index = 1,
    lags = lags
  )

  tibble::tibble(
    mean_loss_diff = mean(loss_data$diff),
    statistic = dm_fit$statistic,
    p_value = dm_fit$p_value
  )
}

forecast_encompassing_test <- function(actual, candidate_forecast, benchmark_forecast, lags = NULL) {
  test_data <- tibble::tibble(
    y = actual - benchmark_forecast,
    x = candidate_forecast - benchmark_forecast
  ) |>
    tidyr::drop_na()

  if (nrow(test_data) <= 5 || stats::sd(test_data$x) == 0) {
    return(tibble::tibble(
      beta = NA_real_,
      statistic = NA_real_,
      p_value = NA_real_
    ))
  }

  encompassing_fit <- newey_west_coefficient_test(
    y = test_data$y,
    X = cbind("(Intercept)" = 1, x = test_data$x),
    coef_index = 2,
    lags = lags
  )

  tibble::tibble(
    beta = encompassing_fit$estimate,
    statistic = encompassing_fit$statistic,
    p_value = encompassing_fit$p_value
  )
}
