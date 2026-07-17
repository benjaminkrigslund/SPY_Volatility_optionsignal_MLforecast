# Full VRP Economic-Value Ranking

Scenario: main forecast panel, log RV, rolling 120, implied_var_eom, normalized payoff, cost_per_turnover = 0.001.

| rank | model_group | model | information_set | strategy_type | strategy_category | sharpe_net | ceq_gain_vs_always_short_gamma3_annualized | max_drawdown_diff_vs_always_short | pct_months_traded | avg_turnover | annualized_mean_return_net | max_drawdown | worst_monthly_return | hit_ratio |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
|   1 | ML | Random Forest | HAR+Macro+Option | short_only_exit_when_negative | short_vol_risk_control |  3.3072 |  0.5889 |   0.0000 | 0.9806 | 0.0452 |  5.1287 |  -3.4630 | -2.7885 | 0.9161 |
|   2 | ML | Neural Network | HAR+Macro+Option | short_only_exit_when_negative | short_vol_risk_control |  3.0253 |  0.2502 |   0.0000 | 0.8387 | 0.2516 |  4.4972 |  -3.4630 | -2.7885 | 0.8000 |
|   3 | Combination | Equal Weight | HAR+Macro | short_only_exit_when_negative | short_vol_risk_control |  3.1071 |  0.2402 |   0.0000 | 0.9355 | 0.1226 |  4.8941 |  -3.4630 | -2.7885 | 0.8710 |
|   4 | ML | Random Forest | HAR+Macro+Option | binary_timing | long_short |  3.1671 |  0.2350 |   0.0000 | 1.0000 | 0.0839 |  5.1798 |  -3.4630 | -2.7885 | 0.9161 |
|   5 | ML | Elastic Net | HAR+Option | scaled_long_short | scaled |  2.6587 |  0.1471 |   1.9487 | 0.8452 | 0.1866 |  3.0382 |  -1.5143 | -1.0418 | 0.9226 |
|   6 | ML | Elastic Net | HAR+Option | scaled_short_only | scaled_short_vol_risk_control |  2.6587 |  0.1471 |   1.9487 | 0.8452 | 0.1866 |  3.0382 |  -1.5143 | -1.0418 | 0.9226 |
|   7 | ML | Elastic Net | HAR+Option | binary_timing | long_short |  3.0545 |  0.0000 |   0.0000 | 1.0000 | 0.0065 |  5.0777 |  -3.4630 | -2.7885 | 0.9226 |
|   8 | ML | Elastic Net | HAR+Option | short_only_exit_when_negative | short_vol_risk_control |  3.0545 |  0.0000 |   0.0000 | 1.0000 | 0.0065 |  5.0777 |  -3.4630 | -2.7885 | 0.9226 |
|   9 | ML | Random Forest | HAR+Option | binary_timing | long_short |  3.0545 |  0.0000 |   0.0000 | 1.0000 | 0.0065 |  5.0777 |  -3.4630 | -2.7885 | 0.9226 |
|  10 | ML | Random Forest | HAR+Option | short_only_exit_when_negative | short_vol_risk_control |  3.0545 |  0.0000 |   0.0000 | 1.0000 | 0.0065 |  5.0777 |  -3.4630 | -2.7885 | 0.9226 |
|  11 | Stacked | Stacked Random Forest | Multiple | short_only_exit_when_negative | short_vol_risk_control |  3.0227 | -0.0605 |   0.0000 | 0.9935 | 0.0194 |  5.0366 |  -3.4630 | -2.7885 | 0.9161 |
|  12 | Stacked | Stacked Elastic Net | Multiple | short_only_exit_when_negative | short_vol_risk_control |  3.0177 | -0.0659 |   0.0000 | 0.9935 | 0.0194 |  5.0238 |  -3.4630 | -2.7885 | 0.9161 |
|  13 | Combination | Random Forest EW | Multiple | short_only_exit_when_negative | short_vol_risk_control |  2.9949 | -0.1152 |   0.0000 | 0.9871 | 0.0323 |  5.0029 |  -3.4630 | -2.7885 | 0.9097 |
|  14 | ML | Neural Network | HAR+Macro | short_only_exit_when_negative | short_vol_risk_control |  2.8421 | -0.1508 |   0.6746 | 0.8452 | 0.2581 |  4.4361 |  -2.7885 | -2.7885 | 0.7935 |
|  15 | ML | Random Forest | HAR+Macro | short_only_exit_when_negative | short_vol_risk_control |  2.8770 | -0.1603 |  -0.0020 | 0.8903 | 0.1742 |  4.5899 |  -3.4650 | -2.7895 | 0.8258 |
|  16 | ML | Random Forest | HAR | short_only_exit_when_negative | short_vol_risk_control |  2.9639 | -0.1705 |   0.0000 | 0.9806 | 0.0452 |  4.9560 |  -3.4630 | -2.7885 | 0.9032 |
|  17 | Stacked | Stacked Random Forest | Multiple | binary_timing | long_short |  2.9680 | -0.1863 |   0.0000 | 1.0000 | 0.0323 |  4.9955 |  -3.4630 | -2.7885 | 0.9161 |
|  18 | ML | Random Forest | HAR+Macro+Option | scaled_short_only | scaled_short_vol_risk_control |  2.3681 | -0.1896 |   1.8225 | 0.8258 | 0.2177 |  2.7162 |  -1.6405 | -1.2338 | 0.9161 |
|  19 | Combination | Elastic Net EW | Multiple | short_only_exit_when_negative | short_vol_risk_control |  2.9476 | -0.1936 |   0.0000 | 0.9806 | 0.0452 |  4.9231 |  -3.4630 | -2.7885 | 0.9032 |
|  20 | Stacked | Stacked Elastic Net | Multiple | scaled_short_only | scaled_short_vol_risk_control |  2.3073 | -0.2022 |   1.9405 | 0.8387 | 0.2260 |  2.5213 |  -1.5225 | -1.2338 | 0.9161 |
|  21 | ML | Random Forest | HAR+Macro+Option | scaled_long_short | scaled |  2.3559 | -0.2064 |   1.8225 | 0.8452 | 0.2227 |  2.7081 |  -1.6405 | -1.2338 | 0.9161 |
|  22 | ML | Neural Network | HAR+Macro+Option | scaled_short_only | scaled_short_vol_risk_control |  2.2545 | -0.2089 |   1.9417 | 0.7226 | 0.2804 |  2.3413 |  -1.5213 | -1.2338 | 0.8000 |
|  23 | Combination | Equal Weight | HAR+Macro+Option | scaled_short_only | scaled_short_vol_risk_control |  2.2748 | -0.2224 |   1.9407 | 0.8065 | 0.2525 |  2.4503 |  -1.5223 | -1.2338 | 0.8839 |
|  24 | Stacked | Stacked Random Forest | Multiple | scaled_short_only | scaled_short_vol_risk_control |  2.3257 | -0.2411 |   1.7435 | 0.8387 | 0.2008 |  2.6736 |  -1.7195 | -1.2338 | 0.9161 |
|  25 | Stacked | Stacked Elastic Net | Multiple | binary_timing | long_short |  2.9418 | -0.2437 |   0.0000 | 1.0000 | 0.0323 |  4.9700 |  -3.4630 | -2.7885 | 0.9161 |
|  26 | Combination | Equal Weight | HAR | short_only_exit_when_negative | short_vol_risk_control |  2.9244 | -0.2439 |   0.0000 | 0.9742 | 0.0581 |  4.9005 |  -3.4630 | -2.7885 | 0.8968 |
|  27 | ML | Random Forest | HAR+Option | scaled_long_short | scaled |  2.3667 | -0.2477 |   1.6839 | 0.8452 | 0.1880 |  2.8313 |  -1.7791 | -1.2338 | 0.9226 |
|  28 | ML | Random Forest | HAR+Option | scaled_short_only | scaled_short_vol_risk_control |  2.3667 | -0.2477 |   1.6839 | 0.8452 | 0.1880 |  2.8313 |  -1.7791 | -1.2338 | 0.9226 |
|  29 | Stacked | Stacked Random Forest | Multiple | scaled_long_short | scaled |  2.3201 | -0.2486 |   1.7435 | 0.8452 | 0.2021 |  2.6694 |  -1.7195 | -1.2338 | 0.9161 |
|  30 | Combination | Equal Weight | Multiple | short_only_exit_when_negative | short_vol_risk_control |  2.9176 | -0.2514 |   0.0000 | 0.9742 | 0.0581 |  4.8836 |  -3.4630 | -2.7885 | 0.8968 |
|  31 | Combination | Random Forest EW | Multiple | scaled_short_only | scaled_short_vol_risk_control |  2.2471 | -0.2651 |   1.9415 | 0.8323 | 0.2201 |  2.4491 |  -1.5215 | -1.2338 | 0.9097 |
|  32 | Combination | Random Forest EW | Multiple | scaled_long_short | scaled |  2.2395 | -0.2747 |   1.9415 | 0.8452 | 0.2221 |  2.4435 |  -1.5215 | -1.2338 | 0.9097 |
|  33 | ML | Elastic Net | HAR+Macro | short_only_exit_when_negative | short_vol_risk_control |  2.9047 | -0.2807 |   0.0000 | 0.9677 | 0.0710 |  4.8726 |  -3.4630 | -2.7885 | 0.8903 |
|  34 | Combination | Equal Weight | HAR+Option | short_only_exit_when_negative | short_vol_risk_control |  2.9012 | -0.2938 |   0.0000 | 0.9613 | 0.0839 |  4.8764 |  -3.4630 | -2.7885 | 0.8839 |
|  35 | ML | Neural Network | HAR+Macro | scaled_short_only | scaled_short_vol_risk_control |  2.0590 | -0.3012 |   1.9415 | 0.6968 | 0.2670 |  1.8746 |  -1.5216 | -1.2338 | 0.7935 |
|  36 | ML | Elastic Net | HAR+Macro+Option | short_only_exit_when_negative | short_vol_risk_control |  2.8871 | -0.3099 |   0.0000 | 0.9677 | 0.0710 |  4.8425 |  -3.4630 | -2.7885 | 0.8903 |
|  37 | Combination | Equal Weight | HAR+Macro+Option | short_only_exit_when_negative | short_vol_risk_control |  2.8741 | -0.3373 |   0.0000 | 0.9613 | 0.0839 |  4.8284 |  -3.4630 | -2.7885 | 0.8839 |
|  38 | Combination | Random Forest EW | Multiple | binary_timing | long_short |  2.8995 | -0.3377 |   0.0000 | 1.0000 | 0.0581 |  4.9282 |  -3.4630 | -2.7885 | 0.9097 |
|  39 | Stacked | Stacked Elastic Net | Multiple | scaled_long_short | scaled |  2.2033 | -0.3462 |   1.2463 | 0.8452 | 0.2389 |  2.4675 |  -2.2167 | -1.2338 | 0.9161 |
|  40 | Benchmark | OLS HAR | HAR | short_only_exit_when_negative | short_vol_risk_control |  2.8474 | -0.3926 |   0.0000 | 0.9548 | 0.0839 |  4.7969 |  -3.4630 | -2.7885 | 0.8774 |
|  41 | ML | PCA | HAR | short_only_exit_when_negative | short_vol_risk_control |  2.8474 | -0.3926 |   0.0000 | 0.9548 | 0.0839 |  4.7969 |  -3.4630 | -2.7885 | 0.8774 |
|  42 | ML | PCA | HAR+Option | short_only_exit_when_negative | short_vol_risk_control |  2.8454 | -0.3950 |   0.0000 | 0.9548 | 0.0710 |  4.7924 |  -3.4630 | -2.7885 | 0.8774 |
|  43 | ML | Random Forest | HAR | scaled_short_only | scaled_short_vol_risk_control |  2.0843 | -0.3990 |   1.9415 | 0.8258 | 0.2322 |  2.1912 |  -1.5215 | -1.2338 | 0.9032 |
|  44 | Combination | Equal Weight | HAR+Macro+Option | scaled_long_short | scaled |  2.1380 | -0.4074 |   1.2465 | 0.8452 | 0.2747 |  2.3732 |  -2.2165 | -1.2338 | 0.8839 |
|  45 | ML | Random Forest | HAR+Macro | scaled_short_only | scaled_short_vol_risk_control |  2.0259 | -0.4488 |   1.9414 | 0.7355 | 0.2286 |  2.1087 |  -1.5216 | -1.2338 | 0.8258 |
|  46 | ML | PCA | HAR+Macro | short_only_exit_when_negative | short_vol_risk_control |  2.8107 | -0.4568 |   0.0000 | 0.9484 | 0.0581 |  4.7378 |  -3.4630 | -2.7885 | 0.8710 |
|  47 | ML | PCA | HAR+Macro+Option | short_only_exit_when_negative | short_vol_risk_control |  2.8107 | -0.4568 |   0.0000 | 0.9484 | 0.0581 |  4.7378 |  -3.4630 | -2.7885 | 0.8710 |
|  48 | Combination | PCA EW | Multiple | short_only_exit_when_negative | short_vol_risk_control |  2.8107 | -0.4568 |   0.0000 | 0.9484 | 0.0581 |  4.7378 |  -3.4630 | -2.7885 | 0.8710 |
|  49 | ML | Neural Network | HAR | short_only_exit_when_negative | short_vol_risk_control |  2.8099 | -0.4687 |   0.0000 | 0.9419 | 0.1097 |  4.7498 |  -3.4630 | -2.7885 | 0.8645 |
|  50 | Combination | Equal Weight | Multiple | scaled_short_only | scaled_short_vol_risk_control |  1.9205 | -0.4712 |   1.9405 | 0.8194 | 0.2335 |  1.8437 |  -1.5225 | -1.2338 | 0.8968 |
|  51 | ML | Random Forest | HAR | scaled_long_short | scaled |  2.0267 | -0.4741 |   1.9415 | 0.8452 | 0.2436 |  2.1562 |  -1.5215 | -1.2338 | 0.9032 |
|  52 | ML | Elastic Net | HAR+Option | short_only_threshold_half_sd | short_vol_risk_control |  2.3135 | -0.4824 |   1.6367 | 0.5806 | 0.2710 |  3.0399 |  -1.8263 | -1.8263 | 0.9226 |
|  53 | ML | Elastic Net | HAR+Option | threshold_half_sd_long_short | long_short_threshold |  2.3135 | -0.4824 |   1.6367 | 0.5806 | 0.2710 |  3.0399 |  -1.8263 | -1.8263 | 0.9226 |
|  54 | Combination | Equal Weight | HAR+Macro | scaled_short_only | scaled_short_vol_risk_control |  1.8212 | -0.4857 |   1.9405 | 0.7806 | 0.2295 |  1.5897 |  -1.5225 | -1.2338 | 0.8710 |
|  55 | ML | Random Forest | HAR+Macro+Option | short_only_threshold_half_sd | short_vol_risk_control |  2.1814 | -0.4971 |   1.9419 | 0.5032 | 0.2581 |  2.6515 |  -1.5211 | -1.2338 | 0.9161 |
|  56 | ML | Random Forest | HAR+Macro+Option | threshold_half_sd_long_short | long_short_threshold |  2.1814 | -0.4971 |   1.9419 | 0.5032 | 0.2581 |  2.6515 |  -1.5211 | -1.2338 | 0.9161 |
|  57 | Combination | Neural Network EW | Multiple | scaled_short_only | scaled_short_vol_risk_control |  1.9568 | -0.5098 |   1.8361 | 0.7613 | 0.2845 |  2.0181 |  -1.6269 | -1.2338 | 0.8323 |
|  58 | Combination | Equal Weight | HAR+Option | scaled_short_only | scaled_short_vol_risk_control |  2.1157 | -0.5271 |   1.9164 | 0.8065 | 0.2459 |  2.5005 |  -1.5466 | -1.2338 | 0.8839 |
|  59 | ML | Random Forest | HAR | binary_timing | long_short |  2.8071 | -0.5469 |   0.0000 | 1.0000 | 0.0839 |  4.8344 |  -3.4630 | -2.7885 | 0.9032 |
|  60 | Combination | Equal Weight | HAR+Macro+Option | short_only_threshold_half_sd | short_vol_risk_control |  2.1219 | -0.5577 |   1.9409 | 0.4774 | 0.3226 |  2.5629 |  -1.5221 | -1.2338 | 0.8839 |
|  61 | ML | Elastic Net | HAR | short_only_exit_when_negative | short_vol_risk_control |  2.7437 | -0.5778 |   0.0000 | 0.9355 | 0.0581 |  4.6345 |  -3.4630 | -2.7885 | 0.8581 |
|  62 | Stacked | Stacked Random Forest | Multiple | short_only_threshold_half_sd | short_vol_risk_control |  2.1132 | -0.5804 |   1.9399 | 0.4903 | 0.2710 |  2.5691 |  -1.5231 | -1.2338 | 0.9161 |
|  63 | Stacked | Stacked Random Forest | Multiple | threshold_half_sd_long_short | long_short_threshold |  2.1132 | -0.5804 |   1.9399 | 0.4903 | 0.2710 |  2.5691 |  -1.5231 | -1.2338 | 0.9161 |
|  64 | Combination | Elastic Net EW | Multiple | scaled_short_only | scaled_short_vol_risk_control |  1.7253 | -0.6097 |   1.9405 | 0.8258 | 0.2058 |  1.5787 |  -1.5226 | -1.2338 | 0.9032 |
|  65 | Combination | Equal Weight | Multiple | scaled_long_short | scaled |  1.8063 | -0.6125 |   1.2463 | 0.8452 | 0.2475 |  1.7854 |  -2.2167 | -1.2338 | 0.8968 |
|  66 | Combination | Equal Weight | HAR+Macro | scaled_long_short | scaled |  1.6534 | -0.6697 |   1.2462 | 0.8452 | 0.2607 |  1.5042 |  -2.2168 | -1.2338 | 0.8710 |
|  67 | ML | Elastic Net | HAR | scaled_short_only | scaled_short_vol_risk_control |  1.5456 | -0.6713 |   1.9403 | 0.7806 | 0.1997 |  1.2636 |  -1.5227 | -1.2338 | 0.8581 |
|  68 | ML | PCA | HAR+Option | scaled_short_only | scaled_short_vol_risk_control |  1.6210 | -0.6752 |   1.9404 | 0.8000 | 0.1853 |  1.4386 |  -1.5227 | -1.2338 | 0.8774 |
|  69 | Combination | Elastic Net EW | Multiple | binary_timing | long_short |  2.7444 | -0.6924 |   0.0000 | 1.0000 | 0.0839 |  4.7685 |  -3.4630 | -2.7885 | 0.9032 |
|  70 | Combination | Neural Network EW | Multiple | short_only_exit_when_negative | short_vol_risk_control |  2.6883 | -0.6990 |   0.0000 | 0.9097 | 0.1871 |  4.5719 |  -3.4630 | -2.7885 | 0.8323 |
|  71 | Combination | Equal Weight | HAR+Macro+Option | threshold_half_sd_long_short | long_short_threshold |  2.0356 | -0.7022 |   1.2466 | 0.4839 | 0.3355 |  2.5090 |  -2.2164 | -1.2338 | 0.8839 |
|  72 | Stacked | Stacked Elastic Net | Multiple | short_only_threshold_half_sd | short_vol_risk_control |  1.9906 | -0.7040 |   1.9409 | 0.4645 | 0.2968 |  2.3890 |  -1.5221 | -1.2338 | 0.9161 |
|  73 | ML | Neural Network | HAR+Macro+Option | short_only_threshold_half_sd | short_vol_risk_control |  1.9393 | -0.7110 |   1.9419 | 0.4387 | 0.3355 |  2.2619 |  -1.5211 | -1.2338 | 0.8000 |
|  74 | ML | Random Forest | HAR+Macro | scaled_long_short | scaled |  1.8517 | -0.7333 |   1.9414 | 0.8452 | 0.2820 |  2.0655 |  -1.5216 | -1.2338 | 0.8258 |
|  75 | ML | Neural Network | HAR+Option | scaled_short_only | scaled_short_vol_risk_control |  1.6172 | -0.7399 |   2.2279 | 0.6968 | 0.2685 |  1.5233 |  -1.2351 | -1.2348 | 0.7871 |
|  76 | Combination | Elastic Net EW | Multiple | scaled_long_short | scaled |  1.6110 | -0.7478 |   1.2462 | 0.8452 | 0.2199 |  1.5201 |  -2.2168 | -1.2338 | 0.9032 |
|  77 | ML | PCA | HAR+Macro+Option | scaled_short_only | scaled_short_vol_risk_control |  1.5853 | -0.7558 |   1.9405 | 0.7935 | 0.1844 |  1.4747 |  -1.5225 | -1.2338 | 0.8710 |
|  78 | Combination | Random Forest EW | Multiple | short_only_threshold_half_sd | short_vol_risk_control |  1.9299 | -0.7571 |   1.9419 | 0.4516 | 0.2968 |  2.2932 |  -1.5211 | -1.2338 | 0.9097 |
|  79 | Combination | Random Forest EW | Multiple | threshold_half_sd_long_short | long_short_threshold |  1.9299 | -0.7571 |   1.9419 | 0.4516 | 0.2968 |  2.2932 |  -1.5211 | -1.2338 | 0.9097 |
|  80 | Combination | Equal Weight | HAR | scaled_short_only | scaled_short_vol_risk_control |  1.4505 | -0.7676 |   1.9404 | 0.8194 | 0.1951 |  1.2119 |  -1.5226 | -1.2338 | 0.8968 |
|  81 | Benchmark | OLS HAR | HAR | scaled_short_only | scaled_short_vol_risk_control |  1.3914 | -0.7740 |   1.9403 | 0.8000 | 0.1770 |  1.1057 |  -1.5227 | -1.2338 | 0.8774 |
|  82 | ML | PCA | HAR | scaled_short_only | scaled_short_vol_risk_control |  1.3914 | -0.7740 |   1.9403 | 0.8000 | 0.1770 |  1.1057 |  -1.5227 | -1.2338 | 0.8774 |
|  83 | ML | Elastic Net | HAR+Macro | scaled_short_only | scaled_short_vol_risk_control |  1.4054 | -0.7786 |   1.9404 | 0.8129 | 0.1787 |  1.1389 |  -1.5227 | -1.2338 | 0.8903 |
|  84 | Combination | PCA EW | Multiple | scaled_short_only | scaled_short_vol_risk_control |  1.4591 | -0.7787 |   1.9404 | 0.7935 | 0.1748 |  1.2440 |  -1.5226 | -1.2338 | 0.8710 |
|  85 | ML | Random Forest | HAR+Option | short_only_threshold_half_sd | short_vol_risk_control |  2.1006 | -0.7869 |   1.9399 | 0.5419 | 0.2839 |  2.7881 |  -1.5231 | -1.5131 | 0.9226 |
|  86 | ML | Random Forest | HAR+Option | threshold_half_sd_long_short | long_short_threshold |  2.1006 | -0.7869 |   1.9399 | 0.5419 | 0.2839 |  2.7881 |  -1.5231 | -1.5131 | 0.9226 |
|  87 | Combination | Equal Weight | HAR | binary_timing | long_short |  2.7024 | -0.7913 |   0.0000 | 1.0000 | 0.1097 |  4.7234 |  -3.4630 | -2.7885 | 0.8968 |
|  88 | ML | Elastic Net | HAR+Option | short_only_threshold_one_sd | short_vol_risk_control |  1.6506 | -0.7983 |   2.4212 | 0.3097 | 0.2452 |  1.6704 |  -1.0418 | -1.0418 | 0.9226 |
|  89 | ML | Elastic Net | HAR+Option | threshold_one_sd_long_short | long_short_threshold |  1.6506 | -0.7983 |   2.4212 | 0.3097 | 0.2452 |  1.6704 |  -1.0418 | -1.0418 | 0.9226 |
|  90 | Combination | Equal Weight | HAR+Macro | binary_timing | long_short |  2.6912 | -0.8176 |   0.0000 | 1.0000 | 0.2387 |  4.7106 |  -3.4630 | -2.7885 | 0.8710 |
|  91 | ML | Elastic Net | HAR | scaled_long_short | scaled |  1.4046 | -0.8214 |   1.2461 | 0.8452 | 0.2162 |  1.1930 |  -2.2169 | -1.2338 | 0.8581 |
|  92 | ML | PCA | HAR+Option | scaled_long_short | scaled |  1.4929 | -0.8256 |   1.2461 | 0.8452 | 0.2023 |  1.3700 |  -2.2169 | -1.2338 | 0.8774 |
|  93 | Combination | Equal Weight | HAR+Option | scaled_long_short | scaled |  1.9267 | -0.8290 |   1.9164 | 0.8452 | 0.2957 |  2.3666 |  -1.5466 | -1.2338 | 0.8839 |
|  94 | Stacked | Stacked Elastic Net | Multiple | threshold_half_sd_long_short | long_short_threshold |  1.9071 | -0.8462 |   1.2466 | 0.4710 | 0.3097 |  2.3352 |  -2.2164 | -1.2338 | 0.9161 |
|  95 | ML | PCA | HAR+Macro | scaled_short_only | scaled_short_vol_risk_control |  1.3309 | -0.8492 |   1.9404 | 0.7935 | 0.1716 |  1.0908 |  -1.5226 | -1.2338 | 0.8710 |
|  96 | ML | Elastic Net | HAR+Macro+Option | scaled_short_only | scaled_short_vol_risk_control |  1.5517 | -0.8564 |   1.8492 | 0.8129 | 0.2100 |  1.5253 |  -1.6138 | -1.2338 | 0.8903 |
|  97 | Combination | Equal Weight | Multiple | binary_timing | long_short |  2.6715 | -0.8649 |   0.0000 | 1.0000 | 0.1097 |  4.6896 |  -3.4630 | -2.7885 | 0.8968 |
|  98 | ML | Neural Network | HAR+Macro | short_only_threshold_half_sd | short_vol_risk_control |  1.5882 | -0.8754 |   1.9419 | 0.2968 | 0.3226 |  1.6225 |  -1.5211 | -1.2338 | 0.7935 |
|  99 | Combination | Equal Weight | HAR+Option | binary_timing | long_short |  2.6585 | -0.8961 |   0.0000 | 1.0000 | 0.1613 |  4.6751 |  -3.4630 | -2.7885 | 0.8839 |
| 100 | Combination | Equal Weight | HAR | scaled_long_short | scaled |  1.3261 | -0.9083 |   1.2462 | 0.8452 | 0.2115 |  1.1477 |  -2.2168 | -1.2338 | 0.8968 |
| 101 | Benchmark | OLS HAR | HAR | scaled_long_short | scaled |  1.2627 | -0.9119 |   1.2461 | 0.8452 | 0.1927 |  1.0420 |  -2.2169 | -1.2338 | 0.8774 |
| 102 | ML | PCA | HAR | scaled_long_short | scaled |  1.2627 | -0.9119 |   1.2461 | 0.8452 | 0.1927 |  1.0420 |  -2.2169 | -1.2338 | 0.8774 |
| 103 | ML | Elastic Net | HAR+Macro | binary_timing | long_short |  2.6514 | -0.9134 |   0.0000 | 1.0000 | 0.1355 |  4.6675 |  -3.4630 | -2.7885 | 0.8903 |
| 104 | ML | PCA | HAR+Macro+Option | scaled_long_short | scaled |  1.4558 | -0.9181 |   1.2462 | 0.8452 | 0.2012 |  1.3985 |  -2.2168 | -1.2338 | 0.8710 |
| 105 | ML | Elastic Net | HAR+Macro | scaled_long_short | scaled |  1.2750 | -0.9213 |   1.2461 | 0.8452 | 0.1954 |  1.0724 |  -2.2169 | -1.2338 | 0.8903 |
| 106 | Combination | PCA EW | Multiple | scaled_long_short | scaled |  1.3324 | -0.9250 |   1.2461 | 0.8452 | 0.1909 |  1.1760 |  -2.2169 | -1.2338 | 0.8710 |
| 107 | Naive | IV as RV Forecast | Option | binary_timing | long_short | NA | -0.9324 |   3.4630 | 0.0000 | 0.0000 |  0.0000 |   0.0000 |  0.0000 | NA |
| 108 | Naive | IV as RV Forecast | Option | scaled_long_short | scaled | NA | -0.9324 |   3.4630 | 0.0000 | 0.0000 |  0.0000 |   0.0000 |  0.0000 | NA |
| 109 | Naive | IV as RV Forecast | Option | scaled_short_only | scaled_short_vol_risk_control | NA | -0.9324 |   3.4630 | 0.0000 | 0.0000 |  0.0000 |   0.0000 |  0.0000 | NA |
| 110 | Naive | IV as RV Forecast | Option | short_only_exit_when_negative | short_vol_risk_control | NA | -0.9324 |   3.4630 | 0.0000 | 0.0000 |  0.0000 |   0.0000 |  0.0000 | NA |
| 111 | Naive | IV as RV Forecast | Option | short_only_threshold_half_sd | short_vol_risk_control | NA | -0.9324 |   3.4630 | 0.0000 | 0.0000 |  0.0000 |   0.0000 |  0.0000 | NA |
| 112 | Naive | IV as RV Forecast | Option | short_only_threshold_one_sd | short_vol_risk_control | NA | -0.9324 |   3.4630 | 0.0000 | 0.0000 |  0.0000 |   0.0000 |  0.0000 | NA |
| 113 | Naive | IV as RV Forecast | Option | threshold_half_sd_long_short | long_short_threshold | NA | -0.9324 |   3.4630 | 0.0000 | 0.0000 |  0.0000 |   0.0000 |  0.0000 | NA |
| 114 | Naive | IV as RV Forecast | Option | threshold_one_sd_long_short | long_short_threshold | NA | -0.9324 |   3.4630 | 0.0000 | 0.0000 |  0.0000 |   0.0000 |  0.0000 | NA |
| 115 | Naive | IV as RV Forecast | Option | threshold_quantile_25_75 | long_short_threshold | NA | -0.9324 |   3.4630 | 0.0000 | 0.0000 |  0.0000 |   0.0000 |  0.0000 | NA |
| 116 | ML | Neural Network | HAR+Macro | scaled_long_short | scaled |  1.5367 | -0.9334 |   1.9415 | 0.8452 | 0.3724 |  1.5753 |  -1.5216 | -1.2338 | 0.7935 |
| 117 | ML | Neural Network | HAR | scaled_short_only | scaled_short_vol_risk_control |  1.2374 | -0.9629 |   1.9405 | 0.7871 | 0.1937 |  1.0503 |  -1.5226 | -1.2338 | 0.8645 |
| 118 | Naive | Historical Mean RV | Historical RV | short_only_exit_when_negative | short_vol_risk_control |  1.4472 | -0.9729 |   2.2272 | 0.2581 | 0.1677 |  1.4356 |  -1.2358 | -1.2348 | 0.3097 |
| 119 | ML | Random Forest | HAR+Macro | short_only_threshold_half_sd | short_vol_risk_control |  1.6726 | -0.9736 |   1.9419 | 0.3871 | 0.2581 |  1.9053 |  -1.5211 | -1.2338 | 0.8258 |
| 120 | Naive | Historical Mean RV | Historical RV | scaled_short_only | scaled_short_vol_risk_control |  1.0046 | -0.9770 |   2.2272 | 0.2129 | 0.1174 |  0.7147 |  -1.2358 | -1.2348 | 0.3097 |
| 121 | Combination | Neural Network EW | Multiple | scaled_long_short | scaled |  1.6099 | -0.9931 |   1.2465 | 0.8452 | 0.3697 |  1.7866 |  -2.2165 | -1.2338 | 0.8323 |
| 122 | ML | PCA | HAR+Macro | scaled_long_short | scaled |  1.2015 | -0.9949 |   1.2462 | 0.8452 | 0.1868 |  1.0214 |  -2.2168 | -1.2338 | 0.8710 |
| 123 | ML | Elastic Net | HAR+Macro+Option | scaled_long_short | scaled |  1.4426 | -1.0068 |   1.2464 | 0.8452 | 0.2263 |  1.4583 |  -2.2167 | -1.2338 | 0.8903 |
| 124 | ML | Random Forest | HAR | short_only_threshold_half_sd | short_vol_risk_control |  1.6438 | -1.0106 |   1.9419 | 0.3871 | 0.2968 |  1.8763 |  -1.5211 | -1.2338 | 0.9032 |
| 125 | ML | Elastic Net | HAR+Macro+Option | binary_timing | long_short |  2.5979 | -1.0432 |   0.0000 | 1.0000 | 0.1355 |  4.6074 |  -3.4630 | -2.7885 | 0.8903 |
| 126 | ML | Neural Network | HAR+Macro+Option | scaled_long_short | scaled |  1.7144 | -1.0586 |   1.9417 | 0.8452 | 0.4067 |  2.0784 |  -1.5213 | -1.2338 | 0.8000 |
| 127 | Combination | Equal Weight | HAR+Option | short_only_threshold_half_sd | short_vol_risk_control |  1.8633 | -1.0793 |   1.9419 | 0.5032 | 0.3226 |  2.4531 |  -1.5211 | -1.5131 | 0.8839 |
| 128 | ML | Neural Network | HAR+Option | short_only_exit_when_negative | short_vol_risk_control |  2.4611 | -1.0898 |   0.0000 | 0.8516 | 0.2645 |  4.1898 |  -3.4630 | -2.7885 | 0.7871 |
| 129 | Naive | Historical Mean RV | Historical RV | short_only_threshold_half_sd | short_vol_risk_control |  0.8602 | -1.0952 |   2.2272 | 0.1161 | 0.1032 |  0.6223 |  -1.2358 | -1.2348 | 0.3097 |
| 130 | ML | Random Forest | HAR | threshold_half_sd_long_short | long_short_threshold |  1.5906 | -1.0967 |   1.9419 | 0.3935 | 0.3097 |  1.8376 |  -1.5211 | -1.2338 | 0.9032 |
| 131 | Combination | Equal Weight | HAR+Macro+Option | binary_timing | long_short |  2.5731 | -1.1040 |   0.0000 | 1.0000 | 0.1613 |  4.5791 |  -3.4630 | -2.7885 | 0.8839 |
| 132 | Combination | Neural Network EW | Multiple | short_only_threshold_half_sd | short_vol_risk_control |  1.5672 | -1.1188 |   1.9409 | 0.3677 | 0.3613 |  1.8063 |  -1.5221 | -1.2338 | 0.8323 |
| 133 | ML | Neural Network | HAR+Macro | short_only_threshold_one_sd | short_vol_risk_control |  0.8417 | -1.1681 |   1.9399 | 0.1226 | 0.1677 |  0.6449 |  -1.5231 | -1.2338 | 0.7935 |
| 134 | ML | Neural Network | HAR+Option | short_only_threshold_one_sd | short_vol_risk_control |  0.8079 | -1.1698 |   2.2272 | 0.1032 | 0.1290 |  0.6057 |  -1.2358 | -1.2348 | 0.7871 |
| 135 | Naive | Historical Mean RV | Historical RV | short_only_threshold_one_sd | short_vol_risk_control |  0.6286 | -1.1753 |   2.2272 | 0.0774 | 0.1161 |  0.4169 |  -1.2358 | -1.2348 | 0.3097 |
| 136 | ML | Neural Network | HAR+Option | short_only_threshold_half_sd | short_vol_risk_control |  1.2851 | -1.1790 |   2.2272 | 0.2581 | 0.2839 |  1.3085 |  -1.2358 | -1.2348 | 0.7871 |
| 137 | Combination | Equal Weight | Multiple | short_only_threshold_half_sd | short_vol_risk_control |  1.4395 | -1.1937 |   1.9409 | 0.3226 | 0.3355 |  1.6062 |  -1.5221 | -1.2338 | 0.8968 |
| 138 | ML | Neural Network | HAR+Macro+Option | short_only_threshold_one_sd | short_vol_risk_control |  1.2010 | -1.1952 |   1.9399 | 0.2194 | 0.2194 |  1.1764 |  -1.5231 | -1.2338 | 0.8000 |
| 139 | ML | Neural Network | HAR | scaled_long_short | scaled |  1.0384 | -1.2074 |   1.2462 | 0.8452 | 0.2209 |  0.9311 |  -2.2168 | -1.2338 | 0.8645 |
| 140 | ML | Elastic Net | HAR | short_only_threshold_one_sd | short_vol_risk_control |  0.3507 | -1.2224 |   1.9389 | 0.0581 | 0.0903 |  0.2006 |  -1.5241 | -1.2338 | 0.8581 |
| 141 | ML | Elastic Net | HAR+Macro | short_only_threshold_one_sd | short_vol_risk_control |  0.3507 | -1.2224 |   1.9389 | 0.0581 | 0.0903 |  0.2006 |  -1.5241 | -1.2338 | 0.8903 |
| 142 | Benchmark | OLS HAR | HAR | short_only_threshold_one_sd | short_vol_risk_control |  0.3507 | -1.2224 |   1.9389 | 0.0581 | 0.0903 |  0.2006 |  -1.5241 | -1.2338 | 0.8774 |
| 143 | ML | PCA | HAR | short_only_threshold_one_sd | short_vol_risk_control |  0.3507 | -1.2224 |   1.9389 | 0.0581 | 0.0903 |  0.2006 |  -1.5241 | -1.2338 | 0.8774 |
| 144 | ML | PCA | HAR+Macro | short_only_threshold_one_sd | short_vol_risk_control |  0.3507 | -1.2224 |   1.9389 | 0.0581 | 0.0903 |  0.2006 |  -1.5241 | -1.2338 | 0.8710 |
| 145 | ML | Random Forest | HAR+Macro+Option | short_only_threshold_one_sd | short_vol_risk_control |  1.2994 | -1.2284 |   1.9399 | 0.2581 | 0.2710 |  1.3690 |  -1.5231 | -1.2338 | 0.9161 |
| 146 | ML | Random Forest | HAR+Macro+Option | threshold_one_sd_long_short | long_short_threshold |  1.2994 | -1.2284 |   1.9399 | 0.2581 | 0.2710 |  1.3690 |  -1.5231 | -1.2338 | 0.9161 |
| 147 | ML | Random Forest | HAR+Macro | threshold_half_sd_long_short | long_short_threshold |  1.6207 | -1.2305 |   1.9419 | 0.4000 | 0.2839 |  2.0106 |  -1.5211 | -1.2338 | 0.8258 |
| 148 | Stacked | Stacked Elastic Net | Multiple | short_only_threshold_one_sd | short_vol_risk_control |  1.1528 | -1.2307 |   1.9389 | 0.2129 | 0.2452 |  1.1215 |  -1.5241 | -1.2338 | 0.9161 |
| 149 | Combination | Equal Weight | HAR+Macro | short_only_threshold_one_sd | short_vol_risk_control |  0.4282 | -1.2318 |   1.9389 | 0.0645 | 0.1032 |  0.2620 |  -1.5241 | -1.2338 | 0.8710 |
| 150 | Combination | Equal Weight | HAR | short_only_threshold_one_sd | short_vol_risk_control |  0.3126 | -1.2362 |   1.9389 | 0.0516 | 0.0774 |  0.1770 |  -1.5241 | -1.2338 | 0.8968 |
| 151 | Benchmark | OLS HAR | HAR | binary_timing | long_short |  2.5185 | -1.2396 |   0.0000 | 1.0000 | 0.1613 |  4.5162 |  -3.4630 | -2.7885 | 0.8774 |
| 152 | ML | PCA | HAR | binary_timing | long_short |  2.5185 | -1.2396 |   0.0000 | 1.0000 | 0.1613 |  4.5162 |  -3.4630 | -2.7885 | 0.8774 |
| 153 | Combination | Equal Weight | HAR+Option | short_only_threshold_one_sd | short_vol_risk_control |  1.1985 | -1.2400 |   1.9399 | 0.2516 | 0.2323 |  1.2025 |  -1.5231 | -1.2338 | 0.8839 |
| 154 | ML | Random Forest | HAR+Option | short_only_threshold_one_sd | short_vol_risk_control |  1.3277 | -1.2413 |   1.9399 | 0.2710 | 0.2323 |  1.4291 |  -1.5231 | -1.2338 | 0.9226 |
| 155 | ML | Random Forest | HAR+Option | threshold_one_sd_long_short | long_short_threshold |  1.3277 | -1.2413 |   1.9399 | 0.2710 | 0.2323 |  1.4291 |  -1.5231 | -1.2338 | 0.9226 |
| 156 | ML | Neural Network | HAR | short_only_threshold_one_sd | short_vol_risk_control |  0.3920 | -1.2420 |   1.9389 | 0.0581 | 0.0903 |  0.2365 |  -1.5241 | -1.2338 | 0.8645 |
| 157 | Combination | Random Forest EW | Multiple | short_only_threshold_one_sd | short_vol_risk_control |  1.1825 | -1.2463 |   1.9399 | 0.2194 | 0.2323 |  1.1802 |  -1.5231 | -1.2338 | 0.9097 |
| 158 | Combination | Random Forest EW | Multiple | threshold_one_sd_long_short | long_short_threshold |  1.1825 | -1.2463 |   1.9399 | 0.2194 | 0.2323 |  1.1802 |  -1.5231 | -1.2338 | 0.9097 |
| 159 | ML | PCA | HAR+Option | binary_timing | long_short |  2.5108 | -1.2589 |   0.0000 | 1.0000 | 0.1355 |  4.5071 |  -3.4630 | -2.7885 | 0.8774 |
| 160 | Stacked | Stacked Random Forest | Multiple | short_only_threshold_one_sd | short_vol_risk_control |  1.2167 | -1.2813 |   1.9399 | 0.2581 | 0.2194 |  1.2601 |  -1.5231 | -1.2338 | 0.9161 |
| 161 | Stacked | Stacked Random Forest | Multiple | threshold_one_sd_long_short | long_short_threshold |  1.2167 | -1.2813 |   1.9399 | 0.2581 | 0.2194 |  1.2601 |  -1.5231 | -1.2338 | 0.9161 |
| 162 | ML | Random Forest | HAR | short_only_threshold_one_sd | short_vol_risk_control |  1.0560 | -1.2874 |   1.9399 | 0.1935 | 0.1677 |  1.0058 |  -1.5231 | -1.2338 | 0.9032 |
| 163 | ML | Random Forest | HAR | threshold_one_sd_long_short | long_short_threshold |  1.0560 | -1.2874 |   1.9399 | 0.1935 | 0.1677 |  1.0058 |  -1.5231 | -1.2338 | 0.9032 |
| 164 | ML | Random Forest | HAR+Macro | short_only_threshold_one_sd | short_vol_risk_control |  0.9828 | -1.2947 |   1.5422 | 0.1871 | 0.1806 |  0.9024 |  -1.9208 | -1.2338 | 0.8258 |
| 165 | ML | Random Forest | HAR+Macro | threshold_one_sd_long_short | long_short_threshold |  0.9828 | -1.2947 |   1.5422 | 0.1871 | 0.1806 |  0.9024 |  -1.9208 | -1.2338 | 0.8258 |
| 166 | Combination | Equal Weight | Multiple | threshold_half_sd_long_short | long_short_threshold |  1.3632 | -1.3253 |   1.2466 | 0.3290 | 0.3484 |  1.5524 |  -2.2164 | -1.2338 | 0.8968 |
| 167 | ML | Neural Network | HAR+Macro | threshold_one_sd_long_short | long_short_threshold |  0.7014 | -1.3260 |   1.9399 | 0.1419 | 0.2065 |  0.5589 |  -1.5231 | -1.2338 | 0.7935 |
| 168 | Combination | Equal Weight | HAR+Option | threshold_half_sd_long_short | long_short_threshold |  1.7363 | -1.3271 |   1.5805 | 0.5226 | 0.3613 |  2.3478 |  -1.8825 | -1.5131 | 0.8839 |
| 169 | Combination | Elastic Net EW | Multiple | short_only_threshold_half_sd | short_vol_risk_control |  1.1928 | -1.3319 |   1.9409 | 0.2774 | 0.3097 |  1.2514 |  -1.5221 | -1.2338 | 0.9032 |
| 170 | ML | Elastic Net | HAR | threshold_one_sd_long_short | long_short_threshold |  0.2425 | -1.3351 |   1.2436 | 0.0645 | 0.1032 |  0.1468 |  -2.2194 | -1.2338 | 0.8581 |
| 171 | ML | Elastic Net | HAR+Macro | threshold_one_sd_long_short | long_short_threshold |  0.2425 | -1.3351 |   1.2436 | 0.0645 | 0.1032 |  0.1468 |  -2.2194 | -1.2338 | 0.8903 |
| 172 | Benchmark | OLS HAR | HAR | threshold_one_sd_long_short | long_short_threshold |  0.2425 | -1.3351 |   1.2436 | 0.0645 | 0.1032 |  0.1468 |  -2.2194 | -1.2338 | 0.8774 |
| 173 | ML | PCA | HAR | threshold_one_sd_long_short | long_short_threshold |  0.2425 | -1.3351 |   1.2436 | 0.0645 | 0.1032 |  0.1468 |  -2.2194 | -1.2338 | 0.8774 |
| 174 | ML | PCA | HAR+Macro | threshold_one_sd_long_short | long_short_threshold |  0.2425 | -1.3351 |   1.2436 | 0.0645 | 0.1032 |  0.1468 |  -2.2194 | -1.2338 | 0.8710 |
| 175 | Combination | Equal Weight | HAR+Macro | short_only_threshold_half_sd | short_vol_risk_control |  1.1884 | -1.3417 |   1.9409 | 0.2645 | 0.2839 |  1.2499 |  -1.5221 | -1.2338 | 0.8710 |
| 176 | Combination | Equal Weight | HAR+Macro | threshold_one_sd_long_short | long_short_threshold |  0.3235 | -1.3453 |   1.2436 | 0.0710 | 0.1161 |  0.2081 |  -2.2194 | -1.2338 | 0.8710 |
| 177 | Combination | Equal Weight | HAR | threshold_one_sd_long_short | long_short_threshold |  0.2054 | -1.3486 |   1.2436 | 0.0581 | 0.0903 |  0.1232 |  -2.2194 | -1.2338 | 0.8968 |
| 178 | ML | PCA | HAR+Macro+Option | short_only_threshold_half_sd | short_vol_risk_control |  1.1880 | -1.3496 |   1.9409 | 0.2710 | 0.2194 |  1.2539 |  -1.5221 | -1.2338 | 0.8710 |
| 179 | Stacked | Stacked Elastic Net | Multiple | threshold_one_sd_long_short | long_short_threshold |  1.0709 | -1.3557 |   1.2446 | 0.2194 | 0.2581 |  1.0677 |  -2.2184 | -1.2338 | 0.9161 |
| 180 | Combination | Equal Weight | HAR+Macro+Option | short_only_threshold_one_sd | short_vol_risk_control |  1.0230 | -1.3639 |   1.9389 | 0.2129 | 0.2710 |  0.9991 |  -1.5241 | -1.2338 | 0.8839 |
| 181 | Combination | Equal Weight | HAR+Option | threshold_one_sd_long_short | long_short_threshold |  1.1082 | -1.3739 |   1.3483 | 0.2645 | 0.2581 |  1.1366 |  -2.1148 | -1.2338 | 0.8839 |
| 182 | ML | PCA | HAR+Option | short_only_threshold_half_sd | short_vol_risk_control |  1.0807 | -1.3974 |   1.9389 | 0.2516 | 0.2323 |  1.1059 |  -1.5241 | -1.2338 | 0.8774 |
| 183 | ML | Elastic Net | HAR+Macro+Option | short_only_threshold_half_sd | short_vol_risk_control |  1.1228 | -1.3984 |   1.9409 | 0.2581 | 0.2710 |  1.1741 |  -1.5221 | -1.2338 | 0.8903 |
| 184 | Combination | Neural Network EW | Multiple | short_only_threshold_one_sd | short_vol_risk_control |  0.6431 | -1.3993 |   1.5873 | 0.1226 | 0.1935 |  0.5222 |  -1.8757 | -1.2338 | 0.8323 |
| 185 | ML | PCA | HAR+Macro | short_only_threshold_half_sd | short_vol_risk_control |  0.9346 | -1.4049 |   1.9409 | 0.2065 | 0.2194 |  0.8911 |  -1.5221 | -1.2338 | 0.8710 |
| 186 | ML | Elastic Net | HAR+Macro+Option | short_only_threshold_one_sd | short_vol_risk_control |  0.5532 | -1.4059 |   1.9389 | 0.1097 | 0.1290 |  0.4292 |  -1.5241 | -1.2338 | 0.8903 |
| 187 | ML | Neural Network | HAR | short_only_threshold_half_sd | short_vol_risk_control |  0.9048 | -1.4162 |   1.9409 | 0.2000 | 0.2452 |  0.8548 |  -1.5221 | -1.2338 | 0.8645 |
| 188 | ML | PCA | HAR+Option | short_only_threshold_one_sd | short_vol_risk_control |  0.4126 | -1.4279 |   1.9389 | 0.0903 | 0.1161 |  0.3005 |  -1.5241 | -1.2338 | 0.8774 |
| 189 | ML | PCA | HAR+Macro+Option | short_only_threshold_one_sd | short_vol_risk_control |  0.4452 | -1.4290 |   1.9389 | 0.0903 | 0.1290 |  0.3306 |  -1.5241 | -1.2338 | 0.8710 |
| 190 | Combination | PCA EW | Multiple | short_only_threshold_one_sd | short_vol_risk_control |  0.2628 | -1.4378 |   1.9389 | 0.0710 | 0.0903 |  0.1773 |  -1.5241 | -1.2338 | 0.8710 |
| 191 | ML | Neural Network | HAR | binary_timing | long_short |  2.4395 | -1.4391 |   0.0000 | 1.0000 | 0.2129 |  4.4220 |  -3.4630 | -2.7885 | 0.8645 |
| 192 | ML | Elastic Net | HAR+Macro | short_only_threshold_half_sd | short_vol_risk_control |  0.8164 | -1.4447 |   1.9389 | 0.1871 | 0.1935 |  0.7484 |  -1.5241 | -1.2338 | 0.8903 |
| 193 | ML | Elastic Net | HAR | short_only_threshold_half_sd | short_vol_risk_control |  0.8237 | -1.4480 |   1.9389 | 0.1806 | 0.1935 |  0.7594 |  -1.5241 | -1.2338 | 0.8581 |
| 194 | Combination | Elastic Net EW | Multiple | short_only_threshold_one_sd | short_vol_risk_control |  0.4011 | -1.4502 |   1.9389 | 0.0839 | 0.1161 |  0.2954 |  -1.5241 | -1.2338 | 0.9032 |
| 195 | Combination | Equal Weight | Multiple | short_only_threshold_one_sd | short_vol_risk_control |  0.5044 | -1.4505 |   1.9389 | 0.0968 | 0.1419 |  0.3931 |  -1.5241 | -1.2338 | 0.8968 |
| 196 | Combination | PCA EW | Multiple | short_only_threshold_half_sd | short_vol_risk_control |  0.9427 | -1.4550 |   1.9389 | 0.2258 | 0.2065 |  0.9266 |  -1.5241 | -1.2338 | 0.8710 |
| 197 | Benchmark | OLS HAR | HAR | short_only_threshold_half_sd | short_vol_risk_control |  0.7443 | -1.4552 |   1.9389 | 0.1677 | 0.1548 |  0.6613 |  -1.5241 | -1.2338 | 0.8774 |
| 198 | ML | PCA | HAR | short_only_threshold_half_sd | short_vol_risk_control |  0.7443 | -1.4552 |   1.9389 | 0.1677 | 0.1548 |  0.6613 |  -1.5241 | -1.2338 | 0.8774 |
| 199 | ML | Neural Network | HAR | threshold_one_sd_long_short | long_short_threshold |  0.1842 | -1.4582 |   1.2436 | 0.0774 | 0.1161 |  0.1210 |  -2.2194 | -1.2338 | 0.8645 |
| 200 | Combination | Elastic Net EW | Multiple | threshold_half_sd_long_short | long_short_threshold |  1.1171 | -1.4586 |   1.2466 | 0.2839 | 0.3226 |  1.1976 |  -2.2164 | -1.2338 | 0.9032 |
| 201 | Combination | Neural Network EW | Multiple | threshold_half_sd_long_short | long_short_threshold |  1.3671 | -1.4651 |   1.2466 | 0.4000 | 0.4258 |  1.6485 |  -2.2164 | -1.2338 | 0.8323 |
| 202 | ML | PCA | HAR+Macro+Option | threshold_half_sd_long_short | long_short_threshold |  1.1129 | -1.4765 |   1.2456 | 0.2774 | 0.2323 |  1.2000 |  -2.2174 | -1.2338 | 0.8710 |
| 203 | Combination | Equal Weight | HAR+Macro+Option | threshold_one_sd_long_short | long_short_threshold |  0.9452 | -1.4872 |   1.2446 | 0.2194 | 0.2839 |  0.9453 |  -2.2184 | -1.2338 | 0.8839 |
| 204 | ML | PCA | HAR+Macro | binary_timing | long_short |  2.4195 | -1.4904 |   0.0000 | 1.0000 | 0.1097 |  4.3979 |  -3.4630 | -2.7885 | 0.8710 |
| 205 | ML | PCA | HAR+Macro+Option | binary_timing | long_short |  2.4195 | -1.4904 |   0.0000 | 1.0000 | 0.1097 |  4.3979 |  -3.4630 | -2.7885 | 0.8710 |
| 206 | Combination | PCA EW | Multiple | binary_timing | long_short |  2.4195 | -1.4904 |   0.0000 | 1.0000 | 0.1097 |  4.3979 |  -3.4630 | -2.7885 | 0.8710 |
| 207 | Combination | Equal Weight | HAR+Macro | threshold_half_sd_long_short | long_short_threshold |  1.0974 | -1.4905 |   1.2466 | 0.2774 | 0.3097 |  1.1819 |  -2.2164 | -1.2338 | 0.8710 |
| 208 | Combination | Equal Weight | HAR | short_only_threshold_half_sd | short_vol_risk_control |  0.8425 | -1.5033 |   1.9409 | 0.2065 | 0.2194 |  0.8077 |  -1.5221 | -1.2338 | 0.8968 |
| 209 | ML | Neural Network | HAR+Macro | threshold_half_sd_long_short | long_short_threshold |  1.1744 | -1.5177 |   1.9419 | 0.3484 | 0.4129 |  1.3255 |  -1.5211 | -1.2338 | 0.7935 |
| 210 | ML | Elastic Net | HAR+Macro+Option | threshold_one_sd_long_short | long_short_threshold |  0.4681 | -1.5217 |   1.2436 | 0.1161 | 0.1419 |  0.3753 |  -2.2194 | -1.2338 | 0.8903 |
| 211 | ML | PCA | HAR+Option | threshold_half_sd_long_short | long_short_threshold |  1.0056 | -1.5224 |   1.2436 | 0.2581 | 0.2452 |  1.0521 |  -2.2194 | -1.2338 | 0.8774 |
| 212 | ML | Elastic Net | HAR+Macro+Option | threshold_half_sd_long_short | long_short_threshold |  1.0486 | -1.5241 |   1.2466 | 0.2645 | 0.2839 |  1.1203 |  -2.2164 | -1.2338 | 0.8903 |
| 213 | ML | PCA | HAR+Macro | threshold_half_sd_long_short | long_short_threshold |  0.8570 | -1.5269 |   1.2456 | 0.2129 | 0.2323 |  0.8372 |  -2.2174 | -1.2338 | 0.8710 |
| 214 | ML | PCA | HAR+Option | threshold_one_sd_long_short | long_short_threshold |  0.3266 | -1.5419 |   1.2436 | 0.0968 | 0.1290 |  0.2467 |  -2.2194 | -1.2338 | 0.8774 |
| 215 | ML | PCA | HAR+Macro+Option | threshold_one_sd_long_short | long_short_threshold |  0.3597 | -1.5434 |   1.2436 | 0.0968 | 0.1419 |  0.2768 |  -2.2194 | -1.2338 | 0.8710 |
| 216 | Combination | PCA EW | Multiple | threshold_one_sd_long_short | long_short_threshold |  0.1756 | -1.5502 |   1.2436 | 0.0774 | 0.1032 |  0.1235 |  -2.2194 | -1.2338 | 0.8710 |
| 217 | Combination | Elastic Net EW | Multiple | threshold_one_sd_long_short | long_short_threshold |  0.3165 | -1.5642 |   1.2436 | 0.0903 | 0.1290 |  0.2415 |  -2.2194 | -1.2338 | 0.9032 |
| 218 | ML | Elastic Net | HAR+Macro | threshold_half_sd_long_short | long_short_threshold |  0.7385 | -1.5648 |   1.2436 | 0.1935 | 0.2065 |  0.6946 |  -2.2194 | -1.2338 | 0.8903 |
| 219 | Combination | Equal Weight | Multiple | threshold_one_sd_long_short | long_short_threshold |  0.4214 | -1.5657 |   1.2436 | 0.1032 | 0.1548 |  0.3393 |  -2.2194 | -1.2338 | 0.8968 |
| 220 | ML | Elastic Net | HAR | threshold_half_sd_long_short | long_short_threshold |  0.7461 | -1.5682 |   1.2436 | 0.1871 | 0.2065 |  0.7056 |  -2.2194 | -1.2338 | 0.8581 |
| 221 | Benchmark | OLS HAR | HAR | threshold_half_sd_long_short | long_short_threshold |  0.6657 | -1.5741 |   1.2436 | 0.1742 | 0.1677 |  0.6075 |  -2.2194 | -1.2338 | 0.8774 |
| 222 | ML | PCA | HAR | threshold_half_sd_long_short | long_short_threshold |  0.6657 | -1.5741 |   1.2436 | 0.1742 | 0.1677 |  0.6075 |  -2.2194 | -1.2338 | 0.8774 |
| 223 | Combination | PCA EW | Multiple | threshold_half_sd_long_short | long_short_threshold |  0.8676 | -1.5775 |   1.2436 | 0.2323 | 0.2194 |  0.8728 |  -2.2194 | -1.2338 | 0.8710 |
| 224 | Combination | Equal Weight | HAR | threshold_half_sd_long_short | long_short_threshold |  0.7679 | -1.6242 |   1.2456 | 0.2129 | 0.2323 |  0.7539 |  -2.2174 | -1.2338 | 0.8968 |
| 225 | Combination | Neural Network EW | Multiple | threshold_one_sd_long_short | long_short_threshold |  0.4631 | -1.6455 |   0.3014 | 0.1419 | 0.2323 |  0.3987 |  -3.1616 | -1.2338 | 0.8323 |
| 226 | ML | Neural Network | HAR | threshold_half_sd_long_short | long_short_threshold |  0.7499 | -1.6505 |   1.2456 | 0.2194 | 0.2710 |  0.7392 |  -2.2174 | -1.2338 | 0.8645 |
| 227 | ML | Neural Network | HAR+Macro+Option | threshold_half_sd_long_short | long_short_threshold |  1.5229 | -1.6606 |   1.9419 | 0.4968 | 0.4516 |  2.0859 |  -1.5211 | -1.2338 | 0.8000 |
| 228 | ML | Neural Network | HAR+Macro+Option | threshold_one_sd_long_short | long_short_threshold |  0.9021 | -1.6737 |   1.9399 | 0.2516 | 0.2839 |  0.9609 |  -1.5231 | -1.2338 | 0.8000 |
| 229 | ML | Neural Network | HAR+Option | scaled_long_short | scaled |  0.9268 | -1.7618 |   1.5810 | 0.8452 | 0.4263 |  1.0326 |  -1.8820 | -1.2354 | 0.7871 |
| 230 | ML | Neural Network | HAR+Option | threshold_one_sd_long_short | long_short_threshold |  0.3204 | -1.8277 |   0.8822 | 0.1548 | 0.2323 |  0.2841 |  -2.5808 | -1.2348 | 0.7871 |
| 231 | ML | Elastic Net | HAR | binary_timing | long_short |  2.2556 | -1.9204 |  -1.2050 | 1.0000 | 0.1097 |  4.1913 |  -4.6680 | -2.7885 | 0.8581 |
| 232 | ML | Random Forest | HAR+Macro | binary_timing | long_short |  2.1880 | -2.1025 |  -0.4715 | 1.0000 | 0.3419 |  4.1021 |  -3.9345 | -2.7905 | 0.8258 |
| 233 | ML | Neural Network | HAR+Option | threshold_half_sd_long_short | long_short_threshold |  0.7506 | -2.1340 |   1.0740 | 0.3355 | 0.4258 |  0.8854 |  -2.3890 | -1.2358 | 0.7871 |
| 234 | Combination | Neural Network EW | Multiple | binary_timing | long_short |  2.1616 | -2.1739 |   0.0000 | 1.0000 | 0.3677 |  4.0662 |  -3.4630 | -2.7885 | 0.8323 |
| 235 | ML | Neural Network | HAR+Macro+Option | binary_timing | long_short |  2.0536 | -2.4721 |   0.0000 | 1.0000 | 0.4968 |  3.9167 |  -3.4630 | -2.7885 | 0.8000 |
| 236 | ML | Neural Network | HAR+Macro | binary_timing | long_short |  1.9682 | -2.7132 |   0.5548 | 1.0000 | 0.5097 |  3.7945 |  -2.9082 | -2.7885 | 0.7935 |
| 237 | Naive | Historical Mean RV | Historical RV | threshold_quantile_25_75 | long_short_threshold |  0.3264 | -3.1882 |  -5.5381 | 0.4516 | 0.2968 |  0.4374 |  -9.0011 | -1.2338 | 0.3097 |
| 238 | ML | Neural Network | HAR+Option | binary_timing | long_short |  1.6485 | -3.6486 |   0.0000 | 1.0000 | 0.5226 |  3.3019 |  -3.4630 | -2.7885 | 0.7871 |
| 239 | Naive | Historical Mean RV | Historical RV | threshold_one_sd_long_short | long_short_threshold | -0.1986 | -4.1422 |  -6.9911 | 0.2581 | 0.2452 | -0.2776 | -10.4541 | -1.2348 | 0.3097 |
| 240 | ML | Neural Network | HAR+Macro+Option | threshold_quantile_25_75 | long_short_threshold |  0.1203 | -4.2140 |  -3.2960 | 0.4774 | 0.5355 |  0.1828 |  -6.7590 | -1.2338 | 0.8000 |
| 241 | Combination | Neural Network EW | Multiple | threshold_quantile_25_75 | long_short_threshold | -0.3445 | -4.2510 | -11.3414 | 0.4452 | 0.4839 | -0.4744 | -14.8045 | -1.2338 | 0.8323 |
| 242 | ML | Neural Network | HAR+Macro | threshold_quantile_25_75 | long_short_threshold | -0.1642 | -4.3759 |  -7.6641 | 0.4710 | 0.5355 | -0.2400 | -11.1271 | -1.2338 | 0.7935 |
| 243 | ML | Elastic Net | HAR+Macro+Option | threshold_quantile_25_75 | long_short_threshold | -0.1505 | -4.6026 | -10.9992 | 0.5097 | 0.4323 | -0.2279 | -14.4622 | -1.2338 | 0.8903 |
| 244 | ML | Random Forest | HAR+Macro | threshold_quantile_25_75 | long_short_threshold | -0.2901 | -4.7567 | -12.8955 | 0.5355 | 0.3806 | -0.4360 | -16.3586 | -1.2338 | 0.8258 |
| 245 | ML | Elastic Net | HAR+Option | threshold_quantile_25_75 | long_short_threshold |  0.1573 | -4.8298 | -10.9535 | 0.5226 | 0.4065 |  0.2619 | -14.4165 | -0.7298 | 0.9226 |
| 246 | ML | PCA | HAR+Option | threshold_quantile_25_75 | long_short_threshold |  0.1110 | -4.9686 |  -8.0884 | 0.4968 | 0.4000 |  0.1862 | -11.5514 | -1.2338 | 0.8774 |
| 247 | Stacked | Stacked Random Forest | Multiple | threshold_quantile_25_75 | long_short_threshold |  0.0831 | -5.0325 |  -6.8914 | 0.4968 | 0.4581 |  0.1397 | -10.3544 | -1.2338 | 0.9161 |
| 248 | Stacked | Stacked Elastic Net | Multiple | threshold_quantile_25_75 | long_short_threshold |  0.1163 | -5.0673 |  -6.8351 | 0.5032 | 0.4452 |  0.1977 | -10.2981 | -1.2338 | 0.9161 |
| 249 | ML | Neural Network | HAR+Option | threshold_quantile_25_75 | long_short_threshold | -0.5932 | -5.0958 | -14.6210 | 0.5613 | 0.5742 | -0.8780 | -18.0841 | -1.2358 | 0.7871 |
| 250 | ML | PCA | HAR+Macro+Option | threshold_quantile_25_75 | long_short_threshold |  0.0375 | -5.2120 |  -7.5318 | 0.5032 | 0.3871 |  0.0639 | -10.9949 | -1.2338 | 0.8710 |
| 251 | Combination | Random Forest EW | Multiple | threshold_quantile_25_75 | long_short_threshold | -0.0420 | -5.2552 | -10.1868 | 0.5032 | 0.4323 | -0.0707 | -13.6499 | -1.2338 | 0.9097 |
| 252 | ML | Elastic Net | HAR | threshold_quantile_25_75 | long_short_threshold | -0.0332 | -5.2579 |  -9.1361 | 0.5097 | 0.4065 | -0.0560 | -12.5991 | -1.2338 | 0.8581 |
| 253 | ML | Random Forest | HAR+Macro+Option | threshold_quantile_25_75 | long_short_threshold | -0.0602 | -5.3050 |  -9.9629 | 0.5097 | 0.3806 | -0.1016 | -13.4259 | -1.2338 | 0.9161 |
| 254 | Combination | Elastic Net EW | Multiple | threshold_quantile_25_75 | long_short_threshold | -0.0460 | -5.3091 |  -9.1361 | 0.5097 | 0.4194 | -0.0779 | -12.5991 | -1.2338 | 0.9032 |
| 255 | Combination | PCA EW | Multiple | threshold_quantile_25_75 | long_short_threshold | -0.1119 | -5.3390 |  -9.3235 | 0.4968 | 0.4452 | -0.1877 | -12.7865 | -1.2338 | 0.8710 |
| 256 | Combination | Equal Weight | HAR+Macro+Option | threshold_quantile_25_75 | long_short_threshold | -0.0103 | -5.3996 |  -9.5957 | 0.5097 | 0.4581 | -0.0177 | -13.0587 | -1.2338 | 0.8839 |
| 257 | Combination | Equal Weight | HAR+Macro | threshold_quantile_25_75 | long_short_threshold | -0.2288 | -5.4035 | -11.1868 | 0.5097 | 0.4839 | -0.3779 | -14.6498 | -1.2338 | 0.8710 |
| 258 | Combination | Equal Weight | HAR | threshold_quantile_25_75 | long_short_threshold | -0.1236 | -5.4089 | -10.1477 | 0.4903 | 0.4710 | -0.2086 | -13.6108 | -1.2338 | 0.8968 |
| 259 | ML | PCA | HAR+Macro | threshold_quantile_25_75 | long_short_threshold | -0.1199 | -5.4126 |  -8.7148 | 0.5161 | 0.4452 | -0.2025 | -12.1778 | -1.2338 | 0.8710 |
| 260 | ML | Random Forest | HAR+Option | threshold_quantile_25_75 | long_short_threshold | -0.1712 | -5.4203 | -11.0413 | 0.5097 | 0.4065 | -0.2866 | -14.5043 | -1.2338 | 0.9226 |
| 261 | ML | Elastic Net | HAR+Macro | threshold_quantile_25_75 | long_short_threshold | -0.1654 | -5.4584 |  -9.5298 | 0.5097 | 0.4452 | -0.2784 | -12.9928 | -1.2338 | 0.8903 |
| 262 | Benchmark | OLS HAR | HAR | threshold_quantile_25_75 | long_short_threshold | -0.1786 | -5.4683 |  -9.5298 | 0.5032 | 0.4581 | -0.3002 | -12.9928 | -1.2338 | 0.8774 |
| 263 | ML | PCA | HAR | threshold_quantile_25_75 | long_short_threshold | -0.1786 | -5.4683 |  -9.5298 | 0.5032 | 0.4581 | -0.3002 | -12.9928 | -1.2338 | 0.8774 |
| 264 | Combination | Equal Weight | Multiple | threshold_quantile_25_75 | long_short_threshold | -0.1899 | -5.5219 | -11.8735 | 0.5032 | 0.4194 | -0.3204 | -15.3365 | -1.2338 | 0.8968 |
| 265 | Combination | Equal Weight | HAR+Option | threshold_quantile_25_75 | long_short_threshold | -0.1702 | -5.5362 |  -9.8228 | 0.5161 | 0.4839 | -0.2887 | -13.2858 | -1.2348 | 0.8839 |
| 266 | ML | Random Forest | HAR | threshold_quantile_25_75 | long_short_threshold | -0.1511 | -5.7311 | -10.5320 | 0.5290 | 0.4452 | -0.2627 | -13.9950 | -1.2338 | 0.9032 |
| 267 | ML | Neural Network | HAR | threshold_quantile_25_75 | long_short_threshold | -0.2937 | -5.9415 | -10.1290 | 0.5355 | 0.5871 | -0.5088 | -13.5920 | -1.2338 | 0.8645 |
| 268 | Naive | Historical Mean RV | Historical RV | scaled_long_short | scaled | -0.8709 | -6.2874 | -20.6127 | 0.8452 | 0.2941 | -1.4120 | -24.0757 | -1.2350 | 0.3097 |
| 269 | Naive | Historical Mean RV | Historical RV | threshold_half_sd_long_short | long_short_threshold | -1.0751 | -7.0092 | -24.1773 | 0.6129 | 0.3032 | -1.8127 | -27.6404 | -1.2348 | 0.3097 |
| 270 | Naive | Historical Mean RV | Historical RV | binary_timing | long_short | -1.0382 | -9.9152 | -30.5177 | 1.0000 | 0.3419 | -2.2065 | -33.9807 | -1.2358 | 0.3097 |
