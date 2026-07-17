# Models Adding Information Beyond OLS HAR

Rolling-120 common sample. Encompassing regression:

```text
actual volatility = alpha + beta_HAR * HAR forecast + beta_model * model forecast + error
```

A model is marked as adding information beyond HAR when `model_p_given_har < 0.05`.

At 5%, 24 of 27 tested models add information beyond OLS HAR.
At 10%, 24 of 27 tested models add information beyond OLS HAR.

## Adds Information Beyond HAR at 5%

|model                 |information_set  |forecast_type |   n| model_coef_given_har| model_t_given_har| model_p_given_har| har_p_given_model| r2_oos_vs_har| qlike_gain_vs_har|
|:---------------------|:----------------|:-------------|---:|--------------------:|-----------------:|-----------------:|-----------------:|-------------:|-----------------:|
|Elastic Net           |HAR+Option       |individual    | 155|               0.9987|            13.090|         0.0000000|         0.1238000|       0.87790|          0.128100|
|Elastic Net EW        |Multiple         |method_EW     | 155|               2.3050|            11.670|         0.0000000|         0.0000000|       0.54760|          0.088970|
|Equal Weight          |Multiple         |all_EW        | 155|               1.8300|            10.080|         0.0000000|         0.0000000|       0.64850|          0.087680|
|Equal Weight          |HAR+Option       |infoset_EW    | 155|               0.9498|             9.564|         0.0000000|         0.0183800|       0.82700|          0.086530|
|Equal Weight          |HAR+Macro+Option |infoset_EW    | 155|               1.0940|             9.138|         0.0000000|         0.0000000|       0.71650|          0.097640|
|Random Forest         |HAR+Option       |individual    | 155|               0.9765|             8.234|         0.0000000|         0.8107000|       0.82270|          0.065840|
|Neural Network        |HAR+Macro+Option |individual    | 155|               0.5052|             8.190|         0.0000000|         0.0027340|       0.74120|         -0.018750|
|Elastic Net           |HAR+Macro+Option |individual    | 155|               1.1340|             8.061|         0.0000000|         0.0000000|       0.35300|          0.036950|
|Stacked Random Forest |Multiple         |stacked       | 155|               1.0660|             7.962|         0.0000000|         0.9434000|       0.81480|          0.015510|
|Stacked Elastic Net   |Multiple         |stacked       | 155|               1.2450|             7.881|         0.0000000|         0.0000018|       0.74470|          0.062620|
|Neural Network EW     |Multiple         |method_EW     | 155|               0.7799|             7.716|         0.0000000|         0.0001598|       0.68920|          0.045450|
|Random Forest EW      |Multiple         |method_EW     | 155|               1.1000|             7.082|         0.0000000|         0.5950000|       0.80590|          0.030620|
|PCA                   |HAR+Option       |individual    | 155|               1.2180|             6.970|         0.0000000|         0.0000001|       0.40010|          0.075070|
|Random Forest         |HAR+Macro+Option |individual    | 155|               0.9346|             6.867|         0.0000000|         0.3414000|       0.80390|          0.037080|
|Random Forest         |HAR              |individual    | 155|               0.8361|             5.852|         0.0000000|         0.1618000|       0.78640|         -0.033370|
|PCA                   |HAR+Macro+Option |individual    | 155|               0.9406|             5.428|         0.0000002|         0.0000228|       0.18260|          0.063660|
|PCA EW                |Multiple         |method_EW     | 155|               1.8940|             5.393|         0.0000003|         0.0000021|       0.06397|          0.062280|
|Neural Network        |HAR+Macro        |individual    | 155|               0.3485|             4.650|         0.0000072|         0.0186700|       0.66520|         -0.267200|
|Neural Network        |HAR+Option       |individual    | 155|               0.2185|             4.494|         0.0000138|         0.0001438|       0.36640|         -1.967000|
|Equal Weight          |HAR+Macro        |infoset_EW    | 155|               0.9624|             4.284|         0.0000325|         0.0023480|       0.54790|         -0.026670|
|Random Forest         |HAR+Macro        |individual    | 155|               0.6745|             3.540|         0.0005318|         0.0169900|       0.75340|         -0.129300|
|Equal Weight          |HAR              |infoset_EW    | 155|               1.6840|             3.512|         0.0005864|         0.0019490|       0.19050|          0.002909|
|Elastic Net           |HAR              |individual    | 155|               2.1320|             2.246|         0.0261800|         0.0436200|       0.37710|         -0.014140|
|PCA                   |HAR+Macro        |individual    | 155|              -0.9386|            -2.181|         0.0307300|         0.0153000|      -0.49390|         -0.021680|

## Does Not Add Information Beyond HAR at 5%

|model          |information_set |forecast_type |   n| model_coef_given_har| model_t_given_har| model_p_given_har| har_p_given_model| r2_oos_vs_har| qlike_gain_vs_har|
|:--------------|:---------------|:-------------|---:|--------------------:|-----------------:|-----------------:|-----------------:|-------------:|-----------------:|
|Neural Network |HAR             |individual    | 155|              -0.2444|            -1.461|            0.1460|         0.0519000|     -1.862000|         -0.043880|
|Elastic Net    |HAR+Macro       |individual    | 155|               0.7024|             1.023|            0.3081|         0.4219000|      0.001176|         -0.002665|
|PCA            |HAR             |individual    | 155|                   NA|                NA|                NA|         0.0003329|      0.000000|          0.000000|
