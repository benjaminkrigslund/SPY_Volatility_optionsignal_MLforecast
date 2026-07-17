# Selected Forecasting and VRP Tables

This file collects compact Markdown versions of the key tables used in the forecasting and economic-value discussion.

## VRP Economic-Value Quality Checks

| check_name | passed | detail |
| --- | --- | --- |
| Forecast origin strictly precedes target | TRUE | All VRP signals use implied variance at origin_date and realized variance at target_date. |
| Positive implied variance | TRUE | Rows with missing or non-positive implied variance are removed before strategy construction. |
| Forecasts converted to variance units | TRUE | level_rv_squared_to_variance, historical_mean_variance, implied_variance_as_forecast used before constructing IV_t - E_t[RV_{t+1}]. |
| Past-only thresholds and scaling | TRUE | Strategies using thresholds or scaled positions compute quantiles/standard deviations from signal values dated strictly before the current origin month. |
| Common OOS dates by scenario | TRUE | Common-date enforcement is applied within each forecast source / target scale / IV measure scenario; 14 scenarios retained, with 120 to 191 common origin-target dates. |
| Threshold strategy warm-up produces no trades | TRUE | If a past-only threshold or rolling volatility estimate is unavailable, position is set to zero. |

## VRP Short-Only Exit Strategy: Model Ranking

Scenario: main forecast panel, log RV, rolling 120, implied_var_eom, normalized payoff, cost_per_turnover = 0.001.

| rank | model_group | model | information_set | sharpe_net | ceq_gain_vs_always_short_gamma3_annualized | max_drawdown_diff_vs_always_short | pct_months_traded | avg_turnover | hit_ratio |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | ML | Random Forest | HAR+Macro+Option | 3.307 | 0.589 | 0 | 0.981 | 0.045 | 0.916 |
| 2 | ML | Neural Network | HAR+Macro+Option | 3.025 | 0.25 | 0 | 0.839 | 0.252 | 0.8 |
| 3 | Combination | Equal Weight | HAR+Macro | 3.107 | 0.24 | 0 | 0.935 | 0.123 | 0.871 |
| 4 | ML | Elastic Net | HAR+Option | 3.054 | 0 | 0 | 1 | 0.006 | 0.923 |
| 5 | ML | Random Forest | HAR+Option | 3.054 | 0 | 0 | 1 | 0.006 | 0.923 |
| 6 | Stacked | Stacked Random Forest | Multiple | 3.023 | -0.061 | 0 | 0.994 | 0.019 | 0.916 |
| 7 | Stacked | Stacked Elastic Net | Multiple | 3.018 | -0.066 | 0 | 0.994 | 0.019 | 0.916 |
| 8 | Combination | Random Forest EW | Multiple | 2.995 | -0.115 | 0 | 0.987 | 0.032 | 0.91 |
| 9 | ML | Neural Network | HAR+Macro | 2.842 | -0.151 | 0.675 | 0.845 | 0.258 | 0.794 |
| 10 | ML | Random Forest | HAR+Macro | 2.877 | -0.16 | -0.002 | 0.89 | 0.174 | 0.826 |
| 11 | ML | Random Forest | HAR | 2.964 | -0.17 | 0 | 0.981 | 0.045 | 0.903 |
| 12 | Combination | Elastic Net EW | Multiple | 2.948 | -0.194 | 0 | 0.981 | 0.045 | 0.903 |
| 13 | Combination | Equal Weight | HAR | 2.924 | -0.244 | 0 | 0.974 | 0.058 | 0.897 |
| 14 | Combination | Equal Weight | Multiple | 2.918 | -0.251 | 0 | 0.974 | 0.058 | 0.897 |
| 15 | ML | Elastic Net | HAR+Macro | 2.905 | -0.281 | 0 | 0.968 | 0.071 | 0.89 |
| 16 | Combination | Equal Weight | HAR+Option | 2.901 | -0.294 | 0 | 0.961 | 0.084 | 0.884 |
| 17 | ML | Elastic Net | HAR+Macro+Option | 2.887 | -0.31 | 0 | 0.968 | 0.071 | 0.89 |
| 18 | Combination | Equal Weight | HAR+Macro+Option | 2.874 | -0.337 | 0 | 0.961 | 0.084 | 0.884 |
| 19 | Benchmark | OLS HAR | HAR | 2.847 | -0.393 | 0 | 0.955 | 0.084 | 0.877 |
| 20 | ML | PCA | HAR | 2.847 | -0.393 | 0 | 0.955 | 0.084 | 0.877 |
| 21 | ML | PCA | HAR+Option | 2.845 | -0.395 | 0 | 0.955 | 0.071 | 0.877 |
| 22 | Combination | PCA EW | Multiple | 2.811 | -0.457 | 0 | 0.948 | 0.058 | 0.871 |
| 23 | ML | PCA | HAR+Macro | 2.811 | -0.457 | 0 | 0.948 | 0.058 | 0.871 |
| 24 | ML | PCA | HAR+Macro+Option | 2.811 | -0.457 | 0 | 0.948 | 0.058 | 0.871 |
| 25 | ML | Neural Network | HAR | 2.81 | -0.469 | 0 | 0.942 | 0.11 | 0.865 |
| 26 | ML | Elastic Net | HAR | 2.744 | -0.578 | 0 | 0.935 | 0.058 | 0.858 |
| 27 | Combination | Neural Network EW | Multiple | 2.688 | -0.699 | 0 | 0.91 | 0.187 | 0.832 |
| 28 | Naive | IV as RV Forecast | Option | NA | -0.932 | 3.463 | 0 | 0 | NA |
| 29 | Naive | Historical Mean RV | Historical RV | 1.447 | -0.973 | 2.227 | 0.258 | 0.168 | 0.31 |
| 30 | ML | Neural Network | HAR+Option | 2.461 | -1.09 | 0 | 0.852 | 0.265 | 0.787 |

## Scaled Short-Only VRP: Breakeven Risk Aversion vs Always Short

Rows are sorted by the risk-aversion level at which the scaled short-only strategy overtakes always-short volatility in CEQ.

| model | information_set | sharpe_net | ceq_gain_gamma3 | max_drawdown_diff | gamma_breakeven_vs_asv | pct_months_traded |
| --- | --- | --- | --- | --- | --- | --- |
| Elastic Net | HAR+Option | 2.659 | 0.147 | 1.949 | 2.8 | 0.845 |
| Neural Network | HAR+Macro+Option | 2.254 | -0.209 | 1.942 | 3.25 | 0.723 |
| Stacked Elastic Net | Multiple | 2.307 | -0.202 | 1.941 | 3.26 | 0.839 |
| Random Forest | HAR+Macro+Option | 2.368 | -0.19 | 1.823 | 3.26 | 0.826 |
| Equal Weight | HAR+Macro+Option | 2.275 | -0.222 | 1.941 | 3.28 | 0.806 |
| Neural Network | HAR+Macro | 2.059 | -0.301 | 1.941 | 3.31 | 0.697 |
| Stacked Random Forest | Multiple | 2.326 | -0.241 | 1.744 | 3.33 | 0.839 |
| Random Forest EW | Multiple | 2.247 | -0.265 | 1.941 | 3.34 | 0.832 |
| Random Forest | HAR+Option | 2.367 | -0.248 | 1.684 | 3.37 | 0.845 |
| Random Forest | HAR | 2.084 | -0.399 | 1.942 | 3.48 | 0.826 |
| Equal Weight | HAR+Macro | 1.821 | -0.486 | 1.94 | 3.49 | 0.781 |
| Equal Weight | Multiple | 1.92 | -0.471 | 1.941 | 3.51 | 0.819 |
| Random Forest | HAR+Macro | 2.026 | -0.449 | 1.941 | 3.53 | 0.735 |
| Neural Network EW | Multiple | 1.957 | -0.51 | 1.836 | 3.6 | 0.761 |
| Elastic Net EW | Multiple | 1.725 | -0.61 | 1.94 | 3.63 | 0.826 |
| Elastic Net | HAR | 1.546 | -0.671 | 1.94 | 3.64 | 0.781 |
| PCA | HAR+Option | 1.621 | -0.675 | 1.94 | 3.68 | 0.8 |
| OLS HAR | HAR | 1.391 | -0.774 | 1.94 | 3.73 | 0.8 |
| PCA | HAR | 1.391 | -0.774 | 1.94 | 3.73 | 0.8 |
| Elastic Net | HAR+Macro | 1.405 | -0.779 | 1.94 | 3.74 | 0.813 |
| Equal Weight | HAR | 1.451 | -0.768 | 1.94 | 3.74 | 0.819 |
| PCA EW | Multiple | 1.459 | -0.779 | 1.94 | 3.76 | 0.794 |
| Equal Weight | HAR+Option | 2.116 | -0.527 | 1.916 | 3.77 | 0.806 |
| Neural Network | HAR+Option | 1.617 | -0.74 | 2.228 | 3.79 | 0.697 |
| PCA | HAR+Macro+Option | 1.585 | -0.756 | 1.94 | 3.8 | 0.794 |
| PCA | HAR+Macro | 1.331 | -0.849 | 1.94 | 3.81 | 0.794 |
| Historical Mean RV | Historical RV | 1.005 | -0.977 | 2.227 | 3.87 | 0.213 |
| Neural Network | HAR | 1.237 | -0.963 | 1.94 | 3.94 | 0.787 |
| Elastic Net | HAR+Macro+Option | 1.552 | -0.856 | 1.849 | 3.95 | 0.813 |

## Selected Forecasts: R2-OOS Time-Series Summary

| plot_order | plot_group | plot_label | final_cumulative_r2_oos_vs_har | min_cumulative_r2_oos_vs_har | max_cumulative_r2_oos_vs_har | final_rolling36_r2_oos_vs_har | min_rolling36_r2_oos_vs_har | max_rolling36_r2_oos_vs_har |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | Individual models | Elastic Net \| HAR+Option | 0.878 | -10.082 | 0.909 | 0.218 | -0.679 | 0.959 |
| 2 | Individual models | Random Forest \| HAR+Option | 0.823 | -7.751 | 0.854 | -0.176 | -0.224 | 0.961 |
| 3 | Individual models | Random Forest \| HAR+Macro+Option | 0.804 | -6.146 | 0.835 | -0.221 | -0.373 | 0.958 |
| 4 | Individual models | Neural Network \| HAR+Macro+Option | 0.741 | -17.998 | 0.83 | -0.954 | -4.182 | 0.916 |
| 5 | Equal-weight combinations | Equal Weight \| HAR+Option | 0.827 | -16.52 | 0.864 | -0.204 | -0.598 | 0.936 |
| 6 | Equal-weight combinations | Random Forest EW \| Multiple | 0.806 | -9.715 | 0.834 | -0.158 | -0.158 | 0.963 |
| 7 | Equal-weight combinations | Equal Weight \| All ML | 0.648 | -8.818 | 0.663 | 0.22 | -0.183 | 0.741 |
| 8 | Stacked combinations | Stacked Random Forest | 0.815 | -0.402 | 0.846 | -0.111 | -0.187 | 0.96 |
| 9 | Stacked combinations | Stacked Elastic Net | 0.745 | -9.316 | 0.769 | 0.088 | -0.459 | 0.869 |

## Selected Forecasts: Error Time-Series Summary

| plot_order | plot_group | plot_label | model_mae | har_mae | mae_gain_vs_har | model_mse | har_mse | mse_gain_vs_har | final_cumulative_abs_error_gain_vs_har | final_cumulative_sq_error_gain_vs_har |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | Individual models | Elastic Net \| HAR+Option | 0.029 | 0.039 | 0.01 | 0.002 | 0.014 | 0.012 | 1.501 | 1.838 |
| 2 | Individual models | Random Forest \| HAR+Option | 0.029 | 0.039 | 0.01 | 0.002 | 0.014 | 0.011 | 1.57 | 1.722 |
| 3 | Individual models | Random Forest \| HAR+Macro+Option | 0.03 | 0.039 | 0.009 | 0.003 | 0.014 | 0.011 | 1.325 | 1.683 |
| 4 | Individual models | Neural Network \| HAR+Macro+Option | 0.04 | 0.039 | -0.001 | 0.003 | 0.014 | 0.01 | -0.131 | 1.552 |
| 5 | Info-set equal weights | Equal Weight \| HAR | 0.037 | 0.039 | 0.001 | 0.011 | 0.014 | 0.003 | 0.225 | 0.399 |
| 6 | Info-set equal weights | Equal Weight \| HAR+Option | 0.032 | 0.039 | 0.007 | 0.002 | 0.014 | 0.011 | 1.085 | 1.731 |
| 7 | Info-set equal weights | Equal Weight \| HAR+Macro | 0.036 | 0.039 | 0.003 | 0.006 | 0.014 | 0.007 | 0.393 | 1.147 |
| 8 | Info-set equal weights | Equal Weight \| HAR+Macro+Option | 0.033 | 0.039 | 0.006 | 0.004 | 0.014 | 0.01 | 0.896 | 1.5 |
| 9 | Method equal weights | Elastic Net EW \| Multiple | 0.034 | 0.039 | 0.005 | 0.006 | 0.014 | 0.007 | 0.757 | 1.146 |
| 10 | Method equal weights | PCA EW \| Multiple | 0.038 | 0.039 | 0.001 | 0.013 | 0.014 | 0.001 | 0.111 | 0.134 |
| 11 | Method equal weights | Random Forest EW \| Multiple | 0.029 | 0.039 | 0.009 | 0.003 | 0.014 | 0.011 | 1.469 | 1.687 |
| 12 | Method equal weights | Neural Network EW \| Multiple | 0.037 | 0.039 | 0.002 | 0.004 | 0.014 | 0.009 | 0.309 | 1.443 |
| 13 | All-model forecast combinations | Equal Weight \| All ML | 0.032 | 0.039 | 0.007 | 0.005 | 0.014 | 0.009 | 1.028 | 1.357 |
| 14 | All-model forecast combinations | Stacked Random Forest | 0.028 | 0.039 | 0.011 | 0.003 | 0.014 | 0.011 | 1.713 | 1.706 |
| 15 | All-model forecast combinations | Stacked Elastic Net | 0.032 | 0.039 | 0.007 | 0.003 | 0.014 | 0.01 | 1.084 | 1.559 |

## Elastic Net HAR+Option: Variable Selection Summary

Top variables by selection frequency and absolute coefficient magnitude.

| variable | variable_label | feature_group | selected_refits | selection_rate | mean_abs_coefficient | median_abs_coefficient | latest_abs_coefficient |
| --- | --- | --- | --- | --- | --- | --- | --- |
| har_rv_1m | realized_vol | har | 237 | 1 | 0.191 | 0.189 | 0.253 |
| har_rv_3m | 3-month mean of realized_vol | har | 237 | 1 | 0.117 | 0.093 | 0.02 |
| har_rv_12m | 12-month mean of realized_vol | har | 237 | 1 | 0.057 | 0.029 | 0.008 |
| call_25_iv_eom | call_25_iv_eom | option | 205 | 0.865 | 0.129 | 0.125 | 0.165 |
| atm_iv_eom | atm_iv_eom | option | 203 | 0.857 | 0.108 | 0.099 | 0.041 |
| put_25_dispersion_eom | put_25_dispersion_eom | option | 187 | 0.789 | 0.101 | 0.09 | 0.009 |
| implied_var_month_avg | implied_var_month_avg | option | 185 | 0.781 | 0.181 | 0.193 | 0.158 |
| mean_dispersion_eom | mean_dispersion_eom | option | 177 | 0.747 | 0.032 | 0.027 | 0.035 |
| smile_curvature_25_month_avg | smile_curvature_25_month_avg | option | 174 | 0.734 | 0.051 | 0.05 | 0.003 |
| put_25_iv_eom | put_25_iv_eom | option | 169 | 0.713 | 0.055 | 0.045 | 0.034 |
| atm_dispersion_eom | atm_dispersion_eom | option | 161 | 0.679 | 0.101 | 0.09 | 0.02 |
| smile_curvature_25_eom | smile_curvature_25_eom | option | 161 | 0.679 | 0.066 | 0.062 | 0.004 |
| vrp_forward_eom | vrp_forward_eom | option | 148 | 0.624 | 0.053 | 0.037 | 0.1 |
| mean_dispersion_month_avg | mean_dispersion_month_avg | option | 141 | 0.595 | 0.045 | 0.047 | 0.012 |
| skew_25_month_avg | skew_25_month_avg | option | 113 | 0.477 | 0.076 | 0.065 | 0.064 |
| smile_curvature_10_eom | smile_curvature_10_eom | option | 106 | 0.447 | 0.041 | 0.03 | 0.007 |
| implied_var_eom | implied_var_eom | option | 86 | 0.363 | 0.16 | 0.12 | 0.139 |
| skew_25_eom | skew_25_eom | option | 83 | 0.35 | 0.034 | 0.021 | 0.004 |
| downside_skew_10_eom | downside_skew_10_eom | option | 64 | 0.27 | 0.082 | 0.062 | 0.062 |
| skew_10_eom | skew_10_eom | option | 58 | 0.245 | 0.068 | 0.033 | 0.02 |
| vrp_forward_month_avg | vrp_forward_month_avg | option | 57 | 0.241 | 0.054 | 0.025 | 0.056 |
| atm_iv_month_avg | atm_iv_month_avg | option | 50 | 0.211 | 0.185 | 0.126 | 0.172 |
| downside_skew_eom | downside_skew_eom | option | 11 | 0.046 | 0.091 | 0.103 | 0.103 |

## Random Forest HAR+Option: Variable Importance Summary

Top variables by average random-forest importance.

| variable | variable_label | feature_group | refits_used | top5_refits | top5_rate | mean_importance | median_importance | latest_importance | mean_rank |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| put_25_iv_eom | put_25_iv_eom | option | 217 | 216 | 0.995 | 1.912 | 1.993 | 1.903 | 2.028 |
| atm_iv_eom | atm_iv_eom | option | 217 | 216 | 0.995 | 1.81 | 1.757 | 2.73 | 2.737 |
| implied_var_eom | implied_var_eom | option | 217 | 201 | 0.926 | 1.84 | 1.702 | 2.651 | 2.627 |
| call_25_iv_eom | call_25_iv_eom | option | 217 | 198 | 0.912 | 1.728 | 1.532 | 2.369 | 3.516 |
| har_rv_1m | realized_vol | har | 217 | 77 | 0.355 | 1.26 | 1.285 | 1.655 | 6.742 |
| atm_dispersion_eom | atm_dispersion_eom | option | 217 | 56 | 0.258 | 1.041 | 0.945 | 0.543 | 8.382 |
| implied_var_month_avg | implied_var_month_avg | option | 217 | 35 | 0.161 | 1.003 | 0.911 | 1.478 | 9.359 |
| skew_10_eom | skew_10_eom | option | 217 | 27 | 0.124 | 0.899 | 0.961 | 0.511 | 10.433 |
| downside_skew_10_eom | downside_skew_10_eom | option | 217 | 14 | 0.065 | 0.607 | 0.557 | 0.305 | 15.571 |
| vrp_forward_eom | vrp_forward_eom | option | 217 | 10 | 0.046 | 0.775 | 0.709 | 1.379 | 11.691 |
| downside_skew_eom | downside_skew_eom | option | 217 | 10 | 0.046 | 0.799 | 0.787 | 0.374 | 12.751 |
| har_rv_12m | 12-month mean of realized_vol | har | 217 | 8 | 0.037 | 0.412 | 0.396 | 0.571 | 18.424 |
| har_rv_3m | 3-month mean of realized_vol | har | 217 | 7 | 0.032 | 0.794 | 0.745 | 0.67 | 12 |
| skew_25_eom | skew_25_eom | option | 217 | 4 | 0.018 | 0.864 | 0.884 | 0.517 | 10.235 |
| put_25_dispersion_eom | put_25_dispersion_eom | option | 217 | 3 | 0.014 | 0.673 | 0.662 | 0.495 | 13.977 |
| atm_iv_month_avg | atm_iv_month_avg | option | 217 | 2 | 0.009 | 0.939 | 0.869 | 1.267 | 10.194 |
| mean_dispersion_month_avg | mean_dispersion_month_avg | option | 217 | 1 | 0.005 | 0.533 | 0.518 | 0.451 | 15.521 |
| mean_dispersion_eom | mean_dispersion_eom | option | 217 | 0 | 0 | 0.565 | 0.551 | 0.498 | 14.244 |
| skew_25_month_avg | skew_25_month_avg | option | 217 | 0 | 0 | 0.447 | 0.436 | 0.384 | 17.76 |
| smile_curvature_25_eom | smile_curvature_25_eom | option | 217 | 0 | 0 | 0.42 | 0.44 | 0.61 | 17.825 |
| vrp_forward_month_avg | vrp_forward_month_avg | option | 217 | 0 | 0 | 0.372 | 0.358 | 0.603 | 19.074 |
| smile_curvature_10_eom | smile_curvature_10_eom | option | 217 | 0 | 0 | 0.354 | 0.367 | 0.605 | 20.171 |
| smile_curvature_25_month_avg | smile_curvature_25_month_avg | option | 217 | 0 | 0 | 0.338 | 0.36 | 0.352 | 20.737 |
