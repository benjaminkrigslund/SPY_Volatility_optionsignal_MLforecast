# Scaled Short-Only VRP Strategy: All Models

Scenario: main forecast panel, log RV, rolling 120, implied_var_eom, normalized payoff, cost_per_turnover = 0.001.

Rows are ranked by annualized CEQ gain versus the HAR scaled short-only timing benchmark at gamma = 3.

| Rank | Group | Model | Information set | Type | N | Sharpe | Ann. mean | Ann. vol | CEQ vs HAR γ=1 | CEQ vs HAR γ=3 | CEQ vs HAR γ=5 | Traded | Turnover | Hit ratio | Max DD | Worst month | DD diff vs HAR | DD diff vs ASV |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
|  1 | ML | Elastic Net | HAR+Option | individual | 155 | 2.659 | 3.038 | 1.143 |  1.595 |  0.921 |  0.247 | 0.845 | 0.187 | 0.923 | -1.514 | -1.042 |  0.008 | 1.949 |
|  2 | ML | Random Forest | HAR+Macro+Option | individual | 155 | 2.368 | 2.716 | 1.147 |  1.268 |  0.584 | -0.100 | 0.826 | 0.218 | 0.916 | -1.641 | -1.234 | -0.118 | 1.823 |
|  3 | Stacked | Stacked Elastic Net | Multiple | stacked | 155 | 2.307 | 2.521 | 1.093 |  1.134 |  0.572 |  0.009 | 0.839 | 0.226 | 0.916 | -1.522 | -1.234 |  0.000 | 1.941 |
|  4 | ML | Neural Network | HAR+Macro+Option | individual | 155 | 2.254 | 2.341 | 1.038 |  1.012 |  0.565 |  0.118 | 0.723 | 0.280 | 0.800 | -1.521 | -1.234 |  0.001 | 1.942 |
|  5 | Combination | Equal Weight | HAR+Macro+Option | infoset_EW | 155 | 2.275 | 2.450 | 1.077 |  1.080 |  0.552 |  0.023 | 0.806 | 0.253 | 0.884 | -1.522 | -1.234 |  0.000 | 1.941 |
|  6 | Stacked | Stacked Random Forest | Multiple | stacked | 155 | 2.326 | 2.674 | 1.150 |  1.223 |  0.533 | -0.157 | 0.839 | 0.201 | 0.916 | -1.720 | -1.234 | -0.197 | 1.744 |
|  7 | ML | Random Forest | HAR+Option | individual | 155 | 2.367 | 2.831 | 1.196 |  1.326 |  0.526 | -0.273 | 0.845 | 0.188 | 0.923 | -1.779 | -1.234 | -0.256 | 1.684 |
|  8 | Combination | Random Forest EW | Multiple | method_EW | 155 | 2.247 | 2.449 | 1.090 |  1.065 |  0.509 | -0.047 | 0.832 | 0.220 | 0.910 | -1.522 | -1.234 |  0.001 | 1.941 |
|  9 | ML | Neural Network | HAR+Macro | individual | 155 | 2.059 | 1.875 | 0.910 |  0.670 |  0.473 |  0.275 | 0.697 | 0.267 | 0.794 | -1.522 | -1.234 |  0.001 | 1.941 |
| 10 | ML | Random Forest | HAR | individual | 155 | 2.084 | 2.191 | 1.051 |  0.849 |  0.375 | -0.099 | 0.826 | 0.232 | 0.903 | -1.521 | -1.234 |  0.001 | 1.942 |
| 11 | ML | Random Forest | HAR+Macro | individual | 155 | 2.026 | 2.109 | 1.041 |  0.777 |  0.325 | -0.127 | 0.735 | 0.229 | 0.826 | -1.522 | -1.234 |  0.001 | 1.941 |
| 12 | Combination | Equal Weight | Multiple | all_EW | 155 | 1.920 | 1.844 | 0.960 |  0.593 |  0.303 |  0.013 | 0.819 | 0.233 | 0.897 | -1.522 | -1.234 |  0.000 | 1.941 |
| 13 | Combination | Equal Weight | HAR+Macro | infoset_EW | 155 | 1.821 | 1.590 | 0.873 |  0.419 |  0.288 |  0.158 | 0.781 | 0.230 | 0.871 | -1.523 | -1.234 |  0.000 | 1.940 |
| 14 | Combination | Neural Network EW | Multiple | method_EW | 155 | 1.957 | 2.018 | 1.031 |  0.696 |  0.264 | -0.168 | 0.761 | 0.284 | 0.832 | -1.627 | -1.234 | -0.104 | 1.836 |
| 15 | Combination | Equal Weight | HAR+Option | infoset_EW | 155 | 2.116 | 2.501 | 1.182 |  1.012 |  0.247 | -0.518 | 0.806 | 0.246 | 0.884 | -1.547 | -1.234 | -0.024 | 1.916 |
| 16 | Combination | Elastic Net EW | Multiple | method_EW | 155 | 1.725 | 1.579 | 0.915 |  0.370 |  0.164 | -0.042 | 0.826 | 0.206 | 0.903 | -1.523 | -1.234 |  0.000 | 1.940 |
| 17 | ML | Elastic Net | HAR | individual | 155 | 1.546 | 1.264 | 0.818 |  0.140 |  0.103 |  0.066 | 0.781 | 0.200 | 0.858 | -1.523 | -1.234 |  0.000 | 1.940 |
| 18 | ML | PCA | HAR+Option | individual | 155 | 1.621 | 1.439 | 0.887 |  0.255 |  0.099 | -0.057 | 0.800 | 0.185 | 0.877 | -1.523 | -1.234 |  0.000 | 1.940 |
| 19 | ML | Neural Network | HAR+Option | individual | 155 | 1.617 | 1.523 | 0.942 |  0.290 |  0.034 | -0.222 | 0.697 | 0.269 | 0.787 | -1.235 | -1.235 |  0.288 | 2.228 |
| 20 | ML | PCA | HAR+Macro+Option | individual | 155 | 1.585 | 1.475 | 0.930 |  0.252 |  0.018 | -0.216 | 0.794 | 0.184 | 0.871 | -1.523 | -1.234 |  0.000 | 1.940 |
| 21 | Combination | Equal Weight | HAR | infoset_EW | 155 | 1.451 | 1.212 | 0.835 |  0.073 |  0.006 | -0.060 | 0.819 | 0.195 | 0.897 | -1.523 | -1.234 |  0.000 | 1.940 |
| 22 | Benchmark | OLS HAR | HAR | individual | 155 | 1.391 | 1.106 | 0.795 |  0.000 |  0.000 |  0.000 | 0.800 | 0.177 | 0.877 | -1.523 | -1.234 |  0.000 | 1.940 |
| 23 | ML | PCA | HAR | individual | 155 | 1.391 | 1.106 | 0.795 |  0.000 |  0.000 |  0.000 | 0.800 | 0.177 | 0.877 | -1.523 | -1.234 |  0.000 | 1.940 |
| 24 | ML | Elastic Net | HAR+Macro | individual | 155 | 1.405 | 1.139 | 0.810 |  0.021 | -0.005 | -0.030 | 0.813 | 0.179 | 0.890 | -1.523 | -1.234 |  0.000 | 1.940 |
| 25 | Combination | PCA EW | Multiple | method_EW | 155 | 1.459 | 1.244 | 0.853 |  0.091 | -0.005 | -0.100 | 0.794 | 0.175 | 0.871 | -1.523 | -1.234 |  0.000 | 1.940 |
| 26 | ML | PCA | HAR+Macro | individual | 155 | 1.331 | 1.091 | 0.820 | -0.035 | -0.075 | -0.115 | 0.794 | 0.172 | 0.871 | -1.523 | -1.234 |  0.000 | 1.940 |
| 27 | ML | Elastic Net | HAR+Macro+Option | individual | 155 | 1.552 | 1.525 | 0.983 |  0.252 | -0.082 | -0.417 | 0.813 | 0.210 | 0.890 | -1.614 | -1.234 | -0.091 | 1.849 |
| 28 | ML | Neural Network | HAR | individual | 155 | 1.237 | 1.050 | 0.849 | -0.100 | -0.189 | -0.278 | 0.787 | 0.194 | 0.865 | -1.523 | -1.234 |  0.000 | 1.940 |
| 29 | Naive | Historical Mean RV | Historical RV | naive | 155 | 1.005 | 0.715 | 0.712 | -0.328 | -0.203 | -0.078 | 0.213 | 0.117 | 0.310 | -1.236 | -1.235 |  0.287 | 2.227 |
