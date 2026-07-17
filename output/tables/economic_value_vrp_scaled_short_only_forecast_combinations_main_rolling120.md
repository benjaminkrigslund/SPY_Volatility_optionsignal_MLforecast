# Scaled Short-Only VRP Strategy: All Forecast Specifications Ranked by Sharpe

Scenario: main forecast panel, log RV, rolling 120, implied_var_eom, normalized payoff, cost_per_turnover = 0.001.

This table reports every available forecast specification under the same scaled short-only VRP strategy. Rows are sorted by annualized net Sharpe ratio. Undefined Sharpe ratios are placed at the bottom.

All CEQ gains are measured relative to the HAR scaled short-only benchmark using the same trading rule.

## Strategy

At the end of month t, implied variance is observable from the option market, while next-month realized variance is unknown. Each forecast is used to form an ex-ante variance risk premium signal:

```text
vrp_signal_t = implied_var_t - forecast_var_{t+1}
```

The scaled short-only position is:

```text
raw_position_t = vrp_signal_t / rolling_sd(vrp_signal)
position_t     = max(min(raw_position_t, 1), 0)
```

The strategy can be partly short volatility, fully short volatility, or out of the trade, but it cannot go long volatility.

## Timing and Payoff Assumptions

| Object | Timing / calculation |
| --- | --- |
| Implied variance | Observed at the end of month t using implied_var_eom |
| Forecast variance | Model forecast for realized variance in month t+1, converted to variance units before comparison |
| Rolling signal volatility | Computed only from past VRP signals dated before month t |
| Short-vol payoff | implied_var_t - realized_var_{t+1} |
| Normalized gross return | position_t * (implied_var_t - realized_var_{t+1}) / implied_var_t |
| Net return | gross_return_t - 0.001 * abs(position_t - position_{t-1}) |

These are normalized variance-payoff units, not literal fully implemented option-portfolio returns.

## Specification Types

| Specification type | Meaning |
| --- | --- |
| individual | One individual ML forecast specification |
| infoset_EW | Equal-weight average across ML methods within one information set |
| method_EW | Equal-weight average across information sets within one model family |
| all_EW | Equal-weight average across the broader ML x information-set forecast panel |
| stacked | Meta-model forecast combination estimated from the forecast panel |
| naive | Simple non-ML benchmark forecast |

## Column Definitions

| Column | Calculation / meaning |
| --- | --- |
| Sharpe rank | Overall rank by annualized net Sharpe ratio |
| Section | Forecast family grouping |
| Forecast specification | Forecast used to construct the VRP signal |
| Specification type | Forecast or combination design |
| Sharpe net | sqrt(12) * mean(net_return) / sd(net_return) |
| Ann. mean net | 12 * mean(net_return) |
| Ann. vol net | sqrt(12) * sd(net_return) |
| CEQ vs HAR gamma=3 | Annualized CEQ gain versus HAR scaled short-only timing at gamma = 3 |
| CEQ vs HAR gamma=5 | Annualized CEQ gain versus HAR scaled short-only timing at gamma = 5 |
| Traded | Fraction of months with positive short-vol exposure |
| Turnover | Average monthly absolute position change |

CEQ is calculated as:

```text
CEQ_gamma = mean(net_return) - (gamma / 2) * var(net_return)
```

## Results

| Sharpe rank | Section | Forecast specification | Specification type | Sharpe net | Ann. mean net | Ann. vol net | CEQ vs HAR gamma=3 | CEQ vs HAR gamma=5 | Traded | Turnover |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
|  1 | Individual ML models | Elastic Net (HAR+Option) | individual | 2.659 | 3.038 | 1.143 |  0.921 |  0.247 | 0.845 | 0.187 |
|  2 | Individual ML models | Random Forest (HAR+Macro+Option) | individual | 2.368 | 2.716 | 1.147 |  0.584 | -0.100 | 0.826 | 0.218 |
|  3 | Individual ML models | Random Forest (HAR+Option) | individual | 2.367 | 2.831 | 1.196 |  0.526 | -0.273 | 0.845 | 0.188 |
|  4 | Stacked forecasts | Stacked Random Forest (Multiple) | stacked | 2.326 | 2.674 | 1.150 |  0.533 | -0.157 | 0.839 | 0.201 |
|  5 | Stacked forecasts | Stacked Elastic Net (Multiple) | stacked | 2.307 | 2.521 | 1.093 |  0.572 |  0.009 | 0.839 | 0.226 |
|  6 | Forecast combinations | Equal Weight (HAR+Macro+Option) | infoset_EW | 2.275 | 2.450 | 1.077 |  0.552 |  0.023 | 0.806 | 0.253 |
|  7 | Individual ML models | Neural Network (HAR+Macro+Option) | individual | 2.254 | 2.341 | 1.038 |  0.565 |  0.118 | 0.723 | 0.280 |
|  8 | Forecast combinations | Random Forest EW (Multiple) | method_EW | 2.247 | 2.449 | 1.090 |  0.509 | -0.047 | 0.832 | 0.220 |
|  9 | Forecast combinations | Equal Weight (HAR+Option) | infoset_EW | 2.116 | 2.501 | 1.182 |  0.247 | -0.518 | 0.806 | 0.246 |
| 10 | Individual ML models | Random Forest (HAR) | individual | 2.084 | 2.191 | 1.051 |  0.375 | -0.099 | 0.826 | 0.232 |
| 11 | Individual ML models | Neural Network (HAR+Macro) | individual | 2.059 | 1.875 | 0.910 |  0.473 |  0.275 | 0.697 | 0.267 |
| 12 | Individual ML models | Random Forest (HAR+Macro) | individual | 2.026 | 2.109 | 1.041 |  0.325 | -0.127 | 0.735 | 0.229 |
| 13 | Forecast combinations | Neural Network EW (Multiple) | method_EW | 1.957 | 2.018 | 1.031 |  0.264 | -0.168 | 0.761 | 0.284 |
| 14 | Forecast combinations | All ML forecasts EW (Multiple) | all_EW | 1.920 | 1.844 | 0.960 |  0.303 |  0.013 | 0.819 | 0.233 |
| 15 | Forecast combinations | Equal Weight (HAR+Macro) | infoset_EW | 1.821 | 1.590 | 0.873 |  0.288 |  0.158 | 0.781 | 0.230 |
| 16 | Forecast combinations | Elastic Net EW (Multiple) | method_EW | 1.725 | 1.579 | 0.915 |  0.164 | -0.042 | 0.826 | 0.206 |
| 17 | Individual ML models | PCA (HAR+Option) | individual | 1.621 | 1.439 | 0.887 |  0.099 | -0.057 | 0.800 | 0.185 |
| 18 | Individual ML models | Neural Network (HAR+Option) | individual | 1.617 | 1.523 | 0.942 |  0.034 | -0.222 | 0.697 | 0.269 |
| 19 | Individual ML models | PCA (HAR+Macro+Option) | individual | 1.585 | 1.475 | 0.930 |  0.018 | -0.216 | 0.794 | 0.184 |
| 20 | Individual ML models | Elastic Net (HAR+Macro+Option) | individual | 1.552 | 1.525 | 0.983 | -0.082 | -0.417 | 0.813 | 0.210 |
| 21 | Individual ML models | Elastic Net (HAR) | individual | 1.546 | 1.264 | 0.818 |  0.103 |  0.066 | 0.781 | 0.200 |
| 22 | Forecast combinations | PCA EW (Multiple) | method_EW | 1.459 | 1.244 | 0.853 | -0.005 | -0.100 | 0.794 | 0.175 |
| 23 | Forecast combinations | Equal Weight (HAR) | infoset_EW | 1.451 | 1.212 | 0.835 |  0.006 | -0.060 | 0.819 | 0.195 |
| 24 | Individual ML models | Elastic Net (HAR+Macro) | individual | 1.405 | 1.139 | 0.810 | -0.005 | -0.030 | 0.813 | 0.179 |
| 25 | Benchmark | HAR scaled short-only | HAR benchmark | 1.391 | 1.106 | 0.795 |  0.000 |  0.000 | 0.800 | 0.177 |
| 26 | Individual ML models | PCA (HAR) | individual | 1.391 | 1.106 | 0.795 |  0.000 |  0.000 | 0.800 | 0.177 |
| 27 | Individual ML models | PCA (HAR+Macro) | individual | 1.331 | 1.091 | 0.820 | -0.075 | -0.115 | 0.794 | 0.172 |
| 28 | Individual ML models | Neural Network (HAR) | individual | 1.237 | 1.050 | 0.849 | -0.189 | -0.278 | 0.787 | 0.194 |
| 29 | Naive benchmarks | Historical Mean RV (Historical RV) | naive | 1.005 | 0.715 | 0.712 | -0.203 | -0.078 | 0.213 | 0.117 |
| 30 | Naive benchmarks | IV as RV Forecast (Option) | naive | NA | 0.000 | 0.000 | -0.158 |  0.473 | 0.000 | 0.000 |
