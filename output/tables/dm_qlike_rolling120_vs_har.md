# DM Tests on QLIKE: Rolling 120 vs OLS HAR

Loss is QLIKE on variance, computed from volatility forecasts squared first.
Negative DM statistic means the model has lower QLIKE loss than HAR.
One-sided p-value tests the directional hypothesis that the model beats HAR.

| rank_dm_one_sided| rank_qlike_gain|model                 |information_set  |forecast_type |   n| qlike_gain_vs_har| dm_stat_model_minus_har| dm_p_two_sided| dm_p_one_sided_model_better|
|-----------------:|---------------:|:---------------------|:----------------|:-------------|---:|-----------------:|-----------------------:|--------------:|---------------------------:|
|                 1|               4|Equal Weight          |Multiple         |all_EW        | 155|            0.0877|                 -1.7092|         0.0874|                      0.0437|
|                 2|               1|Elastic Net           |HAR+Option       |individual    | 155|            0.1281|                 -1.5356|         0.1246|                      0.0623|
|                 3|               2|Equal Weight          |HAR+Macro+Option |infoset_EW    | 155|            0.0976|                 -1.4375|         0.1506|                      0.0753|
|                 4|               3|Elastic Net EW        |Multiple         |method_EW     | 155|            0.0890|                 -1.4132|         0.1576|                      0.0788|
|                 5|              10|PCA EW                |Multiple         |method_EW     | 155|            0.0623|                 -1.3436|         0.1791|                      0.0895|
|                 6|               7|Random Forest         |HAR+Option       |individual    | 155|            0.0658|                 -1.3144|         0.1887|                      0.0943|
|                 7|               9|Stacked Elastic Net   |Multiple         |stacked       | 155|            0.0626|                 -1.3124|         0.1894|                      0.0947|
|                 8|              14|Random Forest EW      |Multiple         |method_EW     | 155|            0.0306|                 -1.2437|         0.2136|                      0.1068|
|                 9|              12|Random Forest         |HAR+Macro+Option |individual    | 155|            0.0371|                 -1.2077|         0.2272|                      0.1136|
|                10|               5|Equal Weight          |HAR+Option       |infoset_EW    | 155|            0.0865|                 -1.1393|         0.2546|                      0.1273|
|                11|               6|PCA                   |HAR+Option       |individual    | 155|            0.0751|                 -1.1010|         0.2709|                      0.1354|
|                12|               8|PCA                   |HAR+Macro+Option |individual    | 155|            0.0637|                 -0.9665|         0.3338|                      0.1669|
|                13|              11|Neural Network EW     |Multiple         |method_EW     | 155|            0.0454|                 -0.6664|         0.5051|                      0.2526|
|                14|              13|Elastic Net           |HAR+Macro+Option |individual    | 155|            0.0370|                 -0.4774|         0.6331|                      0.3166|
|                15|              15|Stacked Random Forest |Multiple         |stacked       | 155|            0.0155|                 -0.3130|         0.7543|                      0.3771|
|                16|              16|Equal Weight          |HAR              |infoset_EW    | 155|            0.0029|                 -0.1736|         0.8622|                      0.4311|
|                17|              20|Neural Network        |HAR+Macro+Option |individual    | 155|           -0.0187|                  0.2104|         0.8334|                      0.5833|
|                18|              18|Elastic Net           |HAR+Macro        |individual    | 155|           -0.0027|                  0.3935|         0.6940|                      0.6530|
|                19|              24|Neural Network        |HAR              |individual    | 155|           -0.0439|                  0.8252|         0.4092|                      0.7954|
|                20|              22|Equal Weight          |HAR+Macro        |infoset_EW    | 155|           -0.0267|                  0.8820|         0.3778|                      0.8111|
|                21|              23|Random Forest         |HAR              |individual    | 155|           -0.0334|                  1.2031|         0.2289|                      0.8855|
|                22|              21|PCA                   |HAR+Macro        |individual    | 155|           -0.0217|                  1.3098|         0.1903|                      0.9049|
|                23|              25|Random Forest         |HAR+Macro        |individual    | 155|           -0.1293|                  1.3595|         0.1740|                      0.9130|
|                24|              27|Neural Network        |HAR+Option       |individual    | 155|           -1.9668|                  1.6974|         0.0896|                      0.9552|
|                25|              19|Elastic Net           |HAR              |individual    | 155|           -0.0141|                  2.1280|         0.0333|                      0.9833|
|                26|              26|Neural Network        |HAR+Macro        |individual    | 155|           -0.2672|                  3.2313|         0.0012|                      0.9994|
|                NA|              17|PCA                   |HAR              |individual    | 155|            0.0000|                      NA|             NA|                          NA|
