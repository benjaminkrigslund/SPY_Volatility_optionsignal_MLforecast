# Reasonable VRP Strategy Benchmark Table

Scenario: main forecast panel, log RV, rolling 120, implied_var_eom, normalized payoff, cost_per_turnover = 0.001.

The HAR rows are same-rule forecast-timing benchmarks. Always-short volatility is the hard unconditional economic benchmark. Positive CEQ gains mean the row beats that benchmark under the stated risk aversion.

| Forecast group | Strategy | N specs | Avg Sharpe | CEQ gain vs HAR γ=3 | Share > HAR γ=3 | CEQ gain vs ASV γ=3 | CEQ gain vs ASV γ=5 | Share > ASV γ=3 | DD diff vs ASV | Avg traded |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Always-short benchmark | Always short volatility |  1 | 3.054 | NA | NA |  0.000 |  0.000 | NA | 0.000 | 1.000 |
| HAR forecast benchmark | Short-only exit |  1 | 2.847 | 0.000 | 0.000 | -0.393 | -0.467 | 0.000 | 0.000 | 0.955 |
| HAR forecast benchmark | Scaled short-only |  1 | 1.391 | 0.000 | 0.000 | -0.774 |  1.358 | 0.000 | 1.940 | 0.800 |
| All individual ML forecasts | Short-only exit | 16 | 2.890 | 0.138 | 0.562 | -0.254 | -0.210 | 0.125 | 0.042 | 0.938 |
| All individual ML forecasts | Scaled short-only | 16 | 1.819 | 0.229 | 0.688 | -0.544 |  1.281 | 0.062 | 1.930 | 0.786 |
| Forecast combinations | Short-only exit |  9 | 2.907 | 0.131 | 0.778 | -0.261 | -0.281 | 0.111 | 0.000 | 0.959 |
| Forecast combinations | Scaled short-only |  9 | 1.886 | 0.259 | 0.889 | -0.515 |  1.276 | 0.000 | 1.926 | 0.805 |
| Stacked combinations | Short-only exit |  2 | 3.020 | 0.329 | 1.000 | -0.063 | -0.074 | 0.000 | 0.000 | 0.994 |
| Stacked combinations | Scaled short-only |  2 | 2.317 | 0.552 | 1.000 | -0.222 |  1.284 | 0.000 | 1.842 | 0.839 |
