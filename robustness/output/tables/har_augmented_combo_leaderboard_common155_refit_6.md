# HAR-Augmented Leaderboard on Common 155-Date Stacking Sample (refit_6)

Common sample construction:
- 155 out-of-sample dates that are available for every HAR-augmented individual forecast and for both stacked forecasts.
- Information sets: `HAR`, `HAR + Option`, `HAR + Macro`, and `HAR + Option + Macro`.
- Baseline: OLS is estimated only on `HAR`, with `refit_every = 6`.
- Individual ML models: 4 methods on each information set (`Elastic Net`, `PCA`, `Random Forest`, `Neural Network`), giving 16 HAR-augmented ML forecasts.
- All base models in this table are re-estimated with `refit_every = 6` on a 120-month rolling window.
- Equal-weight combinations across ML within each information set.
- Equal-weight combinations across information sets within each ML method.
- One grand equal-weight forecast across all 16 HAR-augmented ML forecasts.
- Two stacked meta-forecasts on top of the same 16 forecasts: `Stacked RF` and `Stacked ENET`.
- The stacked layer is refit every month in this script.

| Rank OOS R2 vs HAR | Rank QLIKE | Model Type | Information Set | N | OOS R2 vs HAR | QLIKE | QLIKE Gain vs HAR | Members |
|---:|---:|---|---|---:|---:|---:|---:|---:|
| 1 | 6 | Random Forest | HAR + Option | 155 | 0.6202 | 0.2747 | 0.0589 | 1 |
| 2 | 16 | Stacked RF | All 16 HAR-augmented ML forecasts | 155 | 0.5812 | 0.3399 | -0.0062 | 16 |
| 3 | 10 | EW Random Forest | All HAR-augmented sets | 155 | 0.5810 | 0.3124 | 0.0213 | 4 |
| 4 | 9 | Random Forest | HAR + Option + Macro | 155 | 0.5808 | 0.2991 | 0.0345 | 1 |
| 5 | 3 | EW Across ML | HAR + Option + Macro | 155 | 0.5503 | 0.2634 | 0.0703 | 4 |
| 6 | 21 | Random Forest | HAR | 155 | 0.5443 | 0.3781 | -0.0444 | 1 |
| 7 | 13 | Stacked ENET | All 16 HAR-augmented ML forecasts | 155 | 0.4923 | 0.3285 | 0.0051 | 16 |
| 8 | 8 | EW Full Panel | All HAR-augmented sets | 155 | 0.4918 | 0.2843 | 0.0494 | 16 |
| 9 | 22 | EW Across ML | HAR + Macro | 155 | 0.4792 | 0.3882 | -0.0546 | 4 |
| 10 | 23 | EW Neural Network | All HAR-augmented sets | 155 | 0.4757 | 0.4248 | -0.0911 | 4 |
| 11 | 25 | Neural Network | HAR | 155 | 0.4641 | 0.4903 | -0.1567 | 1 |
| 12 | 26 | Random Forest | HAR + Macro | 155 | 0.4537 | 0.4993 | -0.1657 | 1 |
| 13 | 17 | EW Across ML | HAR | 155 | 0.4531 | 0.3443 | -0.0106 | 4 |
| 14 | 24 | Neural Network | HAR + Option + Macro | 155 | 0.4175 | 0.4415 | -0.1079 | 1 |
| 15 | 11 | EW Across ML | HAR + Option | 155 | 0.2710 | 0.3129 | 0.0208 | 4 |
| 16 | 27 | Neural Network | HAR + Macro | 155 | 0.2691 | 0.9708 | -0.6371 | 1 |
| 17 | 12 | Elastic Net | HAR + Option + Macro | 155 | 0.2605 | 0.3226 | 0.0111 | 1 |
| 18 | 20 | Elastic Net | HAR + Macro | 155 | 0.1633 | 0.3530 | -0.0193 | 1 |
| 19 | 7 | EW Elastic Net | All HAR-augmented sets | 155 | 0.1538 | 0.2804 | 0.0533 | 4 |
| 20 | 4 | PCA | HAR + Option + Macro | 155 | 0.1092 | 0.2703 | 0.0634 | 1 |
| 21 | 5 | EW PCA | All HAR-augmented sets | 155 | 0.0754 | 0.2716 | 0.0621 | 4 |
| 22 | 18 | PCA | HAR + Macro | 155 | 0.0704 | 0.3506 | -0.0169 | 1 |
| 23 | 19 | Elastic Net | HAR | 155 | 0.0378 | 0.3509 | -0.0173 | 1 |
| 24 | 2 | PCA | HAR + Option | 155 | 0.0267 | 0.2628 | 0.0708 | 1 |
| 25 | 1 | Elastic Net | HAR + Option | 155 | 0.0076 | 0.2390 | 0.0946 | 1 |
| 26 | 14 | OLS | HAR | 155 | 0.0000 | 0.3337 | 0.0000 | 1 |
| 26 | 14 | PCA | HAR | 155 | 0.0000 | 0.3337 | 0.0000 | 1 |
| 28 | 28 | Neural Network | HAR + Option | 155 | -1.1796 | 6.8551 | -6.5214 | 1 |
