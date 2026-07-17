# Selected Forecasts: Error Time-Series Summary

| plot_order | plot_group | plot_label | model_mae | har_mae | mae_gain_vs_har | model_mse | har_mse | mse_gain_vs_har | final_cumulative_abs_error_gain_vs_har | final_cumulative_sq_error_gain_vs_har |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | Individual models | Elastic Net \| HAR+Option | 0.029 | 0.039 | 0.01 | 0.002 | 0.014 | 0.012 | 1.501 | 1.838 |
| 2 | Individual models | Random Forest \| HAR+Option | 0.029 | 0.039 | 0.01 | 0.002 | 0.014 | 0.011 | 1.57 | 1.722 |
| 3 | Individual models | Random Forest \| HAR+Macro+Option | 0.03 | 0.039 | 0.009 | 0.003 | 0.014 | 0.011 | 1.325 | 1.683 |
| 4 | Individual models | Neural Network \| HAR+Macro+Option | 0.04 | 0.039 | -0.001 | 0.003 | 0.014 | 0.01 | -0.131 | 1.552 |
| 5 | Info-set equal weights | Equal Weight \| HAR | 0.037 | 0.039 | 0.001 | 0.011 | 0.014 | 0.003 | 0.225 | 0.399 |
| 6 | Info-set equal weights | Equal Weight \| HAR+Option | 0.032 | 0.039 | 0.007 | 0.002 | 0.014 | 0.011 | 1.085 | 1.731 |
| 7 | Info-set equal weights | Equal Weight \| HAR+Macro | 0.036 | 0.039 | 0.003 | 0.006 | 0.014 | 0.007 | 0.393 | 1.147 |
| 8 | Info-set equal weights | Equal Weight \| HAR+Macro+Option | 0.033 | 0.039 | 0.006 | 0.004 | 0.014 | 0.01 | 0.896 | 1.5 |
| 9 | Method equal weights | Elastic Net EW \| Multiple | 0.034 | 0.039 | 0.005 | 0.006 | 0.014 | 0.007 | 0.757 | 1.146 |
| 10 | Method equal weights | PCA EW \| Multiple | 0.038 | 0.039 | 0.001 | 0.013 | 0.014 | 0.001 | 0.111 | 0.134 |
| 11 | Method equal weights | Random Forest EW \| Multiple | 0.029 | 0.039 | 0.009 | 0.003 | 0.014 | 0.011 | 1.469 | 1.687 |
| 12 | Method equal weights | Neural Network EW \| Multiple | 0.037 | 0.039 | 0.002 | 0.004 | 0.014 | 0.009 | 0.309 | 1.443 |
| 13 | All-model forecast combinations | Equal Weight \| All ML | 0.032 | 0.039 | 0.007 | 0.005 | 0.014 | 0.009 | 1.028 | 1.357 |
| 14 | All-model forecast combinations | Stacked Random Forest | 0.028 | 0.039 | 0.011 | 0.003 | 0.014 | 0.011 | 1.713 | 1.706 |
| 15 | All-model forecast combinations | Stacked Elastic Net | 0.032 | 0.039 | 0.007 | 0.003 | 0.014 | 0.01 | 1.084 | 1.559 |
