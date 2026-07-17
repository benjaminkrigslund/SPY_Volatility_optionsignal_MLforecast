evaluate_forecasts <- function(actual = NULL, forecast_df, benchmark_forecast = NULL, config) {
  forecast_dt <- clean_forecast_table(forecast_df)

  if (!is.null(actual)) {
    forecast_dt[, actual_level := actual]
  }

  if (!is.null(benchmark_forecast)) {
    forecast_dt[, benchmark_forecast := benchmark_forecast]
  }

  forecast_dt[, se_model := (actual_level - forecast_level) ^ 2]
  forecast_dt[, se_benchmark := (actual_level - benchmark_forecast) ^ 2]
  forecast_dt[, qlike_model := qlike_loss_from_volatility(actual_level, forecast_level, eps = config$evaluation$qlike_epsilon)]
  forecast_dt[, qlike_benchmark := qlike_loss_from_volatility(actual_level, benchmark_forecast, eps = config$evaluation$qlike_epsilon)]

  summary_dt <- forecast_dt[
    ,
    .(
      n_oos = .N,
      mse_model = mean(se_model, na.rm = TRUE),
      mse_benchmark = mean(se_benchmark, na.rm = TRUE),
      oos_r2 = 1 - sum(se_model, na.rm = TRUE) / sum(se_benchmark, na.rm = TRUE),
      qlike = mean(qlike_model, na.rm = TRUE),
      qlike_benchmark = mean(qlike_benchmark, na.rm = TRUE)
    ),
    by = .(forecast_id, model_type, feature_set, target_type, window_type)
  ]

  dm_dt <- forecast_dt[
    ,
    {
      se_test <- dm_test(se_model, se_benchmark, horizon = config$evaluation$dm_horizon)
      qlike_test <- dm_test(qlike_model, qlike_benchmark, horizon = config$evaluation$dm_horizon)

      data.table::data.table(
        dm_se_stat = se_test$statistic,
        dm_se_p = se_test$p_value,
        dm_qlike_stat = qlike_test$statistic,
        dm_qlike_p = qlike_test$p_value
      )
    },
    by = .(forecast_id, model_type, feature_set, target_type, window_type)
  ]

  enc_dt <- forecast_dt[
    ,
    {
      enc <- forecast_encompassing_test(
        actual = actual_level,
        forecast_a = benchmark_forecast,
        forecast_b = forecast_level
      )

      data.table::data.table(
        encompassing_coef = enc$coefficient,
        encompassing_stat = enc$statistic,
        encompassing_p = enc$p_value
      )
    },
    by = .(forecast_id, model_type, feature_set, target_type, window_type)
  ]

  summary_dt <- merge(summary_dt, dm_dt, by = c("forecast_id", "model_type", "feature_set", "target_type", "window_type"), all.x = TRUE)
  summary_dt <- merge(summary_dt, enc_dt, by = c("forecast_id", "model_type", "feature_set", "target_type", "window_type"), all.x = TRUE)

  list(
    summary = summary_dt[],
    losses = forecast_dt[
      ,
      .(
        target_date,
        forecast_id,
        model_type,
        feature_set,
        target_type,
        window_type,
        actual_level,
        forecast_level,
        benchmark_forecast,
        se_model,
        se_benchmark,
        qlike_model,
        qlike_benchmark
      )
    ]
  )
}
