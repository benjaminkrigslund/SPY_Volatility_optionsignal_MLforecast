# Elastic Net HAR+Option: Variable Selection Summary

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
