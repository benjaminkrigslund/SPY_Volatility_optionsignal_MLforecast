# Defensible VRP Benchmark Comparison

Scenario: main forecast panel, log RV, rolling 120, implied_var_eom, normalized payoff, cost_per_turnover = 0.001.

This table uses two benchmarks: the same-rule HAR forecast strategy to test whether richer forecasts improve timing, and always-short volatility as the hard economic benchmark.

| Forecast group | Strategy | N specs | Avg Sharpe | Median Sharpe | Avg CEQ gain vs HAR | Share > HAR | Avg CEQ gain vs ASV | Share > ASV | Avg DD diff vs ASV | Avg traded |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Always-short benchmark | Always short volatility | 28 | 3.054 | 3.054 |  0.000 | 0.000 |  0.000 | 0.000 |  0.000 | 1.000 |
| HAR forecast benchmark | Short-only exit |  1 | 2.847 | 2.847 |  0.000 | 0.000 | -0.393 | 0.000 |  0.000 | 0.955 |
| HAR forecast benchmark | Scaled short-only |  1 | 1.391 | 1.391 |  0.000 | 0.000 | -0.774 | 0.000 |  1.940 | 0.800 |
| HAR forecast benchmark | Binary long/short |  1 | 2.519 | 2.519 |  0.000 | 0.000 | -1.240 | 0.000 |  0.000 | 1.000 |
| All individual ML forecasts | Short-only exit | 16 | 2.890 | 2.862 |  0.138 | 0.562 | -0.254 | 0.125 |  0.042 | 0.938 |
| All individual ML forecasts | Scaled short-only | 16 | 1.819 | 1.619 |  0.229 | 0.688 | -0.544 | 0.062 |  1.930 | 0.786 |
| All individual ML forecasts | Binary long/short | 16 | 2.485 | 2.475 | -0.138 | 0.375 | -1.378 | 0.062 | -0.070 | 1.000 |
| Forecast combinations | Short-only exit |  9 | 2.907 | 2.918 |  0.131 | 0.778 | -0.261 | 0.111 |  0.000 | 0.959 |
| Forecast combinations | Scaled short-only |  9 | 1.886 | 1.920 |  0.259 | 0.889 | -0.515 | 0.000 |  1.926 | 0.805 |
| Forecast combinations | Binary long/short |  9 | 2.614 | 2.672 |  0.221 | 0.778 | -1.019 | 0.000 |  0.000 | 1.000 |
| Stacked combinations | Short-only exit |  2 | 3.020 | 3.020 |  0.329 | 1.000 | -0.063 | 0.000 |  0.000 | 0.994 |
| Stacked combinations | Scaled short-only |  2 | 2.317 | 2.317 |  0.552 | 1.000 | -0.222 | 0.000 |  1.842 | 0.839 |
| Stacked combinations | Binary long/short |  2 | 2.955 | 2.955 |  1.025 | 1.000 | -0.215 | 0.000 |  0.000 | 1.000 |
