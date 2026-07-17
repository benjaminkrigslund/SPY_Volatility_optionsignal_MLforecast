# Scaled Short-Only VRP Strategy: Investor Utility Gain, Gamma = 3

Scenario: main forecast panel, log RV, rolling 120, implied_var_eom, normalized payoff, cost_per_turnover = 0.001.

The main investor-utility figure is the expanding CEQ gain versus the HAR scaled short-only benchmark. This is the cleanest plot to use with the table because it uses the same certainty-equivalent logic:

```text
CEQ_gamma = mean(net_return) - (gamma / 2) * var(net_return)
```

The plotted value is annualized and computed recursively using only returns observed up to each date. A value above zero means that, up to that point in the out-of-sample period, the model-timed strategy has delivered higher mean-variance utility than the HAR-timed strategy for an investor with gamma = 3.

![Expanding CEQ gain, gamma 3](economic_value_vrp_scaled_short_only_expanding_ceq_gain_gamma3_vs_har_all_models.png)

The second figure shows cumulative realized quadratic-utility-flow gains:

```text
utility_t = net_return_t - (gamma / 2) * net_return_t^2
utility_gain_t = utility_t - utility_HAR,t
```

This is useful as a path diagnostic, but it is more sensitive to large monthly payoff realizations than the table CEQ. For the paper, the expanding CEQ figure above is the more direct companion to the reported utility results.

![Cumulative utility gain, gamma 3](economic_value_vrp_scaled_short_only_cumulative_utility_gain_gamma3_vs_har_all_models.png)

The grey lines show all other forecast specifications. The colored lines highlight the top Sharpe-ranked specifications plus the all-ML equal-weight combination.
