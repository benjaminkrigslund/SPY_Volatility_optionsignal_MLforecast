evaluate_investor_utility <- function(forecast_df,
                                      realized_return = NULL,
                                      config = list(risk_aversion = 3, max_weight = 1)) {
  forecast_dt <- data.table::as.data.table(forecast_df)

  if (is.null(realized_return)) {
    return(list(
      summary = data.table::data.table(
        note = "Placeholder only: pass a realized return series and your portfolio rule to compute investor utility."
      ),
      details = data.table::data.table()
    ))
  }

  max_weight <- config$max_weight %||% 1
  gamma <- config$risk_aversion %||% 3

  forecast_dt[, realized_return := realized_return]
  forecast_dt[, weight := pmin(max_weight, pmax(0, 1 / pmax(forecast_level, 1e-8)))]
  forecast_dt[, portfolio_return := weight * realized_return]
  forecast_dt[, utility := portfolio_return - 0.5 * gamma * portfolio_return ^ 2]

  list(
    summary = forecast_dt[
      ,
      .(
        mean_return = mean(portfolio_return, na.rm = TRUE),
        sd_return = stats::sd(portfolio_return, na.rm = TRUE),
        mean_utility = mean(utility, na.rm = TRUE)
      ),
      by = .(forecast_id)
    ],
    details = forecast_dt[, .(target_date, forecast_id, weight, portfolio_return, utility)]
  )
}

