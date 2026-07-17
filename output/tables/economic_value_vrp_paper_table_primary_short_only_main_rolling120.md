# Primary VRP Timing Paper Table

Primary rule: short volatility when IV_t - forecast_RV_{t+1} > 0; otherwise hold cash. Scenario: main forecast panel, log RV, rolling 120, implied_var_eom, normalized payoff, cost_per_turnover = 0.001.

Rows average across all available information sets within each method group. This avoids selecting the best individual model-strategy pair ex post.

| Method group | N specs | Avg Sharpe net | Median Sharpe net | Avg CEQ gain | Median CEQ gain | Avg DD diff | Avg traded | Avg turnover | Share CEQ > ASV | Share DD better |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Benchmark: always short volatility | 1 | 3.054 | 3.054 |  0.000 |  0.000 |  0.000 | 1.000 | 0.006 | NA | NA |
| HAR benchmark timing | 1 | 2.847 | 2.847 | -0.393 | -0.393 |  0.000 | 0.955 | 0.084 | 0.000 | 0.0 |
| Historical mean RV timing | 1 | 1.447 | 1.447 | -0.973 | -0.973 |  2.227 | 0.258 | 0.168 | 0.000 | 1.0 |
| ML: Elastic Net | 4 | 2.897 | 2.896 | -0.292 | -0.295 |  0.000 | 0.968 | 0.052 | 0.000 | 0.0 |
| ML: PCA | 4 | 2.829 | 2.828 | -0.425 | -0.426 |  0.000 | 0.952 | 0.068 | 0.000 | 0.0 |
| ML: Random Forest | 4 | 3.051 | 3.009 |  0.065 | -0.080 | -0.001 | 0.963 | 0.068 | 0.250 | 0.0 |
| ML: Neural Network | 4 | 2.785 | 2.826 | -0.365 | -0.310 |  0.169 | 0.869 | 0.221 | 0.250 | 0.5 |
| Forecast combinations | 9 | 2.907 | 2.918 | -0.261 | -0.251 |  0.000 | 0.959 | 0.081 | 0.111 | 0.0 |
| Stacked forecast combinations | 2 | 3.020 | 3.020 | -0.063 | -0.063 |  0.000 | 0.994 | 0.019 | 0.000 | 0.0 |
