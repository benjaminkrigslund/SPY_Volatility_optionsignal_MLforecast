# HAR-Augmented Leaderboard on Common 155-Date Stacking Sample

Common sample construction:
- 155 out-of-sample dates that are available for every HAR-augmented individual forecast and for both stacked forecasts.
- Information sets: `HAR`, `HAR + Option`, `HAR + Macro`, and `HAR + Option + Macro`.
- Baseline: OLS is estimated only on `HAR`.
- Individual ML models: 5 methods on each information set (`Elastic Net`, `PCA`, `PLS`, `Random Forest`, `Neural Network`), giving 20 HAR-augmented ML forecasts.
- Equal-weight combinations across ML within each information set.
- Equal-weight combinations across information sets within each ML method.
- One grand equal-weight forecast across all 20 HAR-augmented ML forecasts.
- Two stacked meta-forecasts on top of the same 20 forecasts: `Stacked RF` and `Stacked ENET`.

| Rank OOS R2 vs HAR | Rank QLIKE | Model Type | Information Set | N | OOS R2 vs HAR | QLIKE | QLIKE Gain vs HAR | Members |
|---:|---:|---|---|---:|---:|---:|---:|---:|
| 1 | 2 | PLS | HAR + Option | 155 | 0.6828 | 0.2475 | 0.1149 | 1 |
| 2 | 7 | Stacked ENET | All 20 HAR-augmented ML forecasts | 155 | 0.6451 | 0.2717 | 0.0908 | 20 |
| 3 | 14 | Stacked RF | All 20 HAR-augmented ML forecasts | 155 | 0.5931 | 0.3196 | 0.0429 | 20 |
| 4 | 10 | Random Forest | HAR + Option | 155 | 0.5893 | 0.2861 | 0.0763 | 1 |
| 5 | 5 | EW Across ML | HAR + Option + Macro | 155 | 0.5891 | 0.2616 | 0.1009 | 5 |
| 6 | 11 | Elastic Net | HAR + Option + Macro | 155 | 0.5719 | 0.2876 | 0.0749 | 1 |
| 7 | 8 | EW Full Panel | All HAR-augmented sets | 155 | 0.5583 | 0.2778 | 0.0847 | 20 |
| 8 | 9 | EW PLS | All HAR-augmented sets | 155 | 0.5554 | 0.2811 | 0.0813 | 4 |
| 9 | 13 | Random Forest | HAR + Option + Macro | 155 | 0.5478 | 0.3160 | 0.0465 | 1 |
| 10 | 16 | EW Random Forest | All HAR-augmented sets | 155 | 0.5456 | 0.3290 | 0.0335 | 4 |
| 11 | 12 | EW PCA | All HAR-augmented sets | 155 | 0.5236 | 0.3106 | 0.0519 | 4 |
| 12 | 24 | Random Forest | HAR | 155 | 0.5087 | 0.3991 | -0.0366 | 1 |
| 13 | 3 | EW Across ML | HAR + Option | 155 | 0.5084 | 0.2482 | 0.1143 | 5 |
| 14 | 4 | PCA | HAR + Option | 155 | 0.5043 | 0.2513 | 0.1112 | 1 |
| 15 | 28 | Neural Network | HAR | 155 | 0.4798 | 0.4734 | -0.1109 | 1 |
| 16 | 25 | PCA | HAR | 155 | 0.4680 | 0.4308 | -0.0684 | 1 |
| 17 | 26 | EW Across ML | HAR + Macro | 155 | 0.4520 | 0.4540 | -0.0916 | 5 |
| 18 | 21 | EW Across ML | HAR | 155 | 0.4461 | 0.3868 | -0.0244 | 5 |
| 19 | 15 | PCA | HAR + Option + Macro | 155 | 0.4398 | 0.3257 | 0.0368 | 1 |
| 20 | 23 | PLS | HAR + Option + Macro | 155 | 0.4368 | 0.3908 | -0.0283 | 1 |
| 21 | 27 | Neural Network | HAR + Option + Macro | 155 | 0.4215 | 0.4543 | -0.0918 | 1 |
| 22 | 29 | Random Forest | HAR + Macro | 155 | 0.4097 | 0.5201 | -0.1576 | 1 |
| 23 | 1 | Elastic Net | HAR + Option | 155 | 0.3897 | 0.2349 | 0.1275 | 1 |
| 24 | 30 | PLS | HAR + Macro | 155 | 0.3815 | 0.5969 | -0.2344 | 1 |
| 25 | 22 | EW Neural Network | All HAR-augmented sets | 155 | 0.3636 | 0.3876 | -0.0252 | 4 |
| 26 | 6 | EW Elastic Net | All HAR-augmented sets | 155 | 0.3146 | 0.2636 | 0.0988 | 4 |
| 27 | 32 | PCA | HAR + Macro | 155 | 0.2830 | 0.7650 | -0.4026 | 1 |
| 28 | 31 | Neural Network | HAR + Macro | 155 | 0.1575 | 0.7598 | -0.3973 | 1 |
| 29 | 19 | PLS | HAR | 155 | 0.1555 | 0.3778 | -0.0153 | 1 |
| 30 | 20 | Elastic Net | HAR | 155 | 0.0215 | 0.3836 | -0.0212 | 1 |
| 31 | 18 | Elastic Net | HAR + Macro | 155 | 0.0020 | 0.3630 | -0.0005 | 1 |
| 32 | 17 | OLS | HAR | 155 | 0.0000 | 0.3625 | 0.0000 | 1 |
| 33 | 33 | Neural Network | HAR + Option | 155 | -2.1632 | 1.3313 | -0.9689 | 1 |
