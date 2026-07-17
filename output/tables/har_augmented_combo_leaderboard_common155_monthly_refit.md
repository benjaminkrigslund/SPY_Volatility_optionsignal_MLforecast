# HAR-Augmented Leaderboard on Common 155-Date Stacking Sample (monthly_refit)

Common sample construction:
- 155 out-of-sample dates that are available for every HAR-augmented individual forecast and for both stacked forecasts.
- Information sets: `HAR`, `HAR + Option`, `HAR + Macro`, and `HAR + Option + Macro`.
- Baseline: OLS is estimated only on `HAR`, with `refit_every = 1`.
- Individual ML models: 4 methods on each information set (`Elastic Net`, `PCA`, `Random Forest`, `Neural Network`), giving 16 HAR-augmented ML forecasts.
- All base models in this table are re-estimated with `refit_every = 1` on a 120-month rolling window.
- Equal-weight combinations across ML within each information set.
- Equal-weight combinations across information sets within each ML method.
- One grand equal-weight forecast across all 16 HAR-augmented ML forecasts.
- Two stacked meta-forecasts on top of the same 16 forecasts: `Stacked RF` and `Stacked ENET`.
- The stacked layer is refit every month in this script.

| Rank OOS R2 vs HAR | Rank QLIKE | Model Type | Information Set | N | OOS R2 vs HAR | QLIKE | QLIKE Gain vs HAR | Members |
|---:|---:|---|---|---:|---:|---:|---:|---:|
| 1 | 5 | EW Neural Network | All HAR-augmented sets | 155 | 0.8750 | 0.2566 | 0.0774 | 4 |
| 2 | 1 | Elastic Net | HAR + Option | 155 | 0.8688 | 0.2224 | 0.1116 | 1 |
| 3 | 2 | EW Across ML | HAR + Option | 155 | 0.8576 | 0.2275 | 0.1064 | 4 |
| 4 | 8 | Random Forest | HAR + Option | 155 | 0.8227 | 0.2681 | 0.0658 | 1 |
| 5 | 10 | Stacked ENET | All 16 HAR-augmented ML forecasts | 155 | 0.8193 | 0.2710 | 0.0630 | 16 |
| 6 | 14 | Stacked RF | All 16 HAR-augmented ML forecasts | 155 | 0.8150 | 0.3163 | 0.0176 | 16 |
| 7 | 13 | EW Random Forest | All HAR-augmented sets | 155 | 0.8059 | 0.3033 | 0.0306 | 4 |
| 8 | 12 | Random Forest | HAR + Option + Macro | 155 | 0.8039 | 0.2969 | 0.0371 | 1 |
| 9 | 25 | Neural Network | HAR + Option + Macro | 155 | 0.7963 | 0.4390 | -0.1050 | 1 |
| 10 | 24 | Random Forest | HAR | 155 | 0.7864 | 0.3673 | -0.0334 | 1 |
| 11 | 20 | Neural Network | HAR | 155 | 0.7735 | 0.3482 | -0.0142 | 1 |
| 12 | 26 | Random Forest | HAR + Macro | 155 | 0.7534 | 0.4633 | -0.1293 | 1 |
| 13 | 3 | EW Full Panel | All HAR-augmented sets | 155 | 0.7247 | 0.2311 | 0.1029 | 16 |
| 14 | 4 | EW Across ML | HAR + Option + Macro | 155 | 0.7003 | 0.2474 | 0.0866 | 4 |
| 15 | 27 | Neural Network | HAR + Macro | 155 | 0.6919 | 0.6689 | -0.3349 | 1 |
| 16 | 15 | EW Across ML | HAR | 155 | 0.6659 | 0.3289 | 0.0051 | 4 |
| 17 | 6 | EW Elastic Net | All HAR-augmented sets | 155 | 0.5448 | 0.2585 | 0.0754 | 4 |
| 18 | 22 | EW Across ML | HAR + Macro | 155 | 0.5121 | 0.3550 | -0.0210 | 4 |
| 19 | 28 | Neural Network | HAR + Option | 155 | 0.4565 | 0.9743 | -0.6403 | 1 |
| 20 | 7 | PCA | HAR + Option | 155 | 0.4001 | 0.2589 | 0.0751 | 1 |
| 21 | 21 | Elastic Net | HAR | 155 | 0.3627 | 0.3494 | -0.0154 | 1 |
| 22 | 19 | Elastic Net | HAR + Option + Macro | 155 | 0.3238 | 0.3364 | -0.0024 | 1 |
| 23 | 9 | PCA | HAR + Option + Macro | 155 | 0.1826 | 0.2703 | 0.0637 | 1 |
| 24 | 11 | EW PCA | All HAR-augmented sets | 155 | 0.0640 | 0.2717 | 0.0623 | 4 |
| 25 | 16 | Elastic Net | HAR + Macro | 155 | 0.0024 | 0.3337 | 0.0003 | 1 |
| 26 | 17 | OLS | HAR | 155 | 0.0000 | 0.3340 | 0.0000 | 1 |
| 26 | 17 | PCA | HAR | 155 | 0.0000 | 0.3340 | 0.0000 | 1 |
| 28 | 23 | PCA | HAR + Macro | 155 | -0.4939 | 0.3557 | -0.0217 | 1 |
