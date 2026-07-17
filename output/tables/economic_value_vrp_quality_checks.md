# VRP Economic-Value Quality Checks

| check_name | passed | detail |
| --- | --- | --- |
| Forecast origin strictly precedes target | TRUE | All VRP signals use implied variance at origin_date and realized variance at target_date. |
| Positive implied variance | TRUE | Rows with missing or non-positive implied variance are removed before strategy construction. |
| Forecasts converted to variance units | TRUE | level_rv_squared_to_variance, historical_mean_variance, implied_variance_as_forecast used before constructing IV_t - E_t[RV_{t+1}]. |
| Past-only thresholds and scaling | TRUE | Strategies using thresholds or scaled positions compute quantiles/standard deviations from signal values dated strictly before the current origin month. |
| Common OOS dates by scenario | TRUE | Common-date enforcement is applied within each forecast source / target scale / IV measure scenario; 14 scenarios retained, with 120 to 191 common origin-target dates. |
| Threshold strategy warm-up produces no trades | TRUE | If a past-only threshold or rolling volatility estimate is unavailable, position is set to zero. |
