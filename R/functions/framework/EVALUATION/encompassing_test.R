forecast_encompassing_test <- function(actual, forecast_a, forecast_b) {
  test_df <- data.frame(
    actual = as.numeric(actual),
    forecast_a = as.numeric(forecast_a),
    forecast_b = as.numeric(forecast_b)
  )
  finite_rows <- stats::complete.cases(test_df) &
    is.finite(test_df$actual) &
    is.finite(test_df$forecast_a) &
    is.finite(test_df$forecast_b)
  test_df <- test_df[finite_rows, , drop = FALSE]

  if (nrow(test_df) < 10L) {
    return(data.table::data.table(
      coefficient = NA_real_,
      std_error = NA_real_,
      statistic = NA_real_,
      p_value = NA_real_,
      n = nrow(test_df)
    ))
  }

  fit <- stats::lm(actual ~ forecast_a + forecast_b, data = test_df)
  coef_table <- summary(fit)$coefficients

  if (!"forecast_b" %in% rownames(coef_table)) {
    return(data.table::data.table(
      coefficient = NA_real_,
      std_error = NA_real_,
      statistic = NA_real_,
      p_value = NA_real_,
      n = nrow(test_df)
    ))
  }

  data.table::data.table(
    coefficient = coef_table["forecast_b", "Estimate"],
    std_error = coef_table["forecast_b", "Std. Error"],
    statistic = coef_table["forecast_b", "t value"],
    p_value = coef_table["forecast_b", "Pr(>|t|)"],
    n = nrow(test_df)
  )
}
