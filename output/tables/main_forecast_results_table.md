# Main Forecast Results Table

Main table design:
- Rolling 120-month log-RV window only in the reported rows.
- Common 155-date sample for every rolling individual, equal-weight, and stacked forecast.
- `model` combines the model name and forecast type; `members` is placed next to it.
- The table is sorted by `rank_r2_oos`; `rank_qlike` is reported as a statistical ranking but is not used for sorting.
- `rmse_gain_vs_har` is OLS HAR RMSE minus model RMSE, so positive values mean lower RMSE than HAR.
- QLIKE is reported only as gain versus HAR.
- `r2_oos_60_vs_har` and `r2_oos_180_vs_har` report the same specification's OOS R2 versus OLS HAR under 60- and 180-month rolling log-RV windows using each robustness run's available OOS sample.

| rank_r2_oos| rank_qlike|model                           | members|information_set  | n_oos| rmse_gain_vs_har| r2_oos_vs_har| qlike_gain_vs_har| r2_oos_60_vs_har| r2_oos_180_vs_har|
|-----------:|----------:|:-------------------------------|-------:|:----------------|-----:|----------------:|-------------:|-----------------:|----------------:|-----------------:|
|           1|          1|Elastic Net (Individual)        |       1|HAR+Option       |   155|          0.07561|       0.87795|           0.12806|          0.69822|           0.55819|
|           2|          5|Equal Weight (Info-set EW)      |       4|HAR+Option       |   155|          0.06788|       0.82701|           0.08653|          0.85217|           0.41787|
|           3|          7|Random Forest (Individual)      |       1|HAR+Option       |   155|          0.06728|       0.82274|           0.06584|          0.94920|           0.48720|
|           4|         15|Stacked Random Forest (Stacked) |      16|Multiple         |   155|          0.06620|       0.81483|           0.01551|          0.94269|           0.41065|
|           5|         14|Random Forest EW (Method EW)    |       4|Multiple         |   155|          0.06501|       0.80587|           0.03062|          0.95101|           0.44483|
|           6|         12|Random Forest (Individual)      |       1|HAR+Macro+Option |   155|          0.06474|       0.80385|           0.03708|          0.94583|           0.45218|
|           7|         24|Random Forest (Individual)      |       1|HAR              |   155|          0.06250|       0.78640|          -0.03337|          0.88316|           0.32469|
|           8|         26|Random Forest (Individual)      |       1|HAR+Macro        |   155|          0.05850|       0.75336|          -0.12930|          0.88002|           0.26018|
|           9|          9|Stacked Elastic Net (Stacked)   |      16|Multiple         |   155|          0.05749|       0.74467|           0.06262|          0.82958|           0.49362|
|          10|         21|Neural Network (Individual)     |       1|HAR+Macro+Option |   155|          0.05710|       0.74123|          -0.01875|          0.94108|           0.20316|
|          11|          2|Equal Weight (Info-set EW)      |       4|HAR+Macro+Option |   155|          0.05433|       0.71647|           0.09764|          0.87125|           0.41995|
|          12|         11|Neural Network EW (Method EW)   |       4|Multiple         |   155|          0.05143|       0.68924|           0.04545|          0.94215|           0.28584|
|          13|         27|Neural Network (Individual)     |       1|HAR+Macro        |   155|          0.04896|       0.66515|          -0.26723|          0.88841|          -0.15545|
|          14|          4|Equal Weight (All EW)           |      16|Multiple         |   155|          0.04731|       0.64845|           0.08768|          0.81394|           0.42441|
|          15|         23|Equal Weight (Info-set EW)      |       4|HAR+Macro        |   155|          0.03808|       0.54793|          -0.02667|          0.60594|           0.19924|
|          16|          3|Elastic Net EW (Method EW)      |       4|Multiple         |   155|          0.03805|       0.54763|           0.08897|          0.63204|           0.43610|
|          17|          6|PCA (Individual)                |       1|HAR+Option       |   155|          0.02620|       0.40009|           0.07507|          0.26644|           0.03571|
|          18|         20|Elastic Net (Individual)        |       1|HAR              |   155|          0.02449|       0.37706|          -0.01414|          0.65707|           0.07126|
|          19|         28|Neural Network (Individual)     |       1|HAR+Option       |   155|          0.02371|       0.36638|          -1.96679|          0.85145|          -1.59401|
|          20|         13|Elastic Net (Individual)        |       1|HAR+Macro+Option |   155|          0.02273|       0.35295|           0.03695|          0.71368|           0.36291|
|          21|         16|Equal Weight (Info-set EW)      |       4|HAR              |   155|          0.01166|       0.19053|           0.00291|          0.74016|           0.28222|
|          22|          8|PCA (Individual)                |       1|HAR+Macro+Option |   155|          0.01114|       0.18259|           0.06366|          0.20811|           0.01414|
|          23|         10|PCA EW (Method EW)              |       4|Multiple         |   155|          0.00378|       0.06397|           0.06228|         -0.01721|           0.00555|
|          24|         19|Elastic Net (Individual)        |       1|HAR+Macro        |   155|          0.00007|       0.00118|          -0.00266|         -0.08090|           0.01195|
|          25|         17|OLS HAR (Individual)            |       1|HAR              |   155|          0.00000|       0.00000|           0.00000|          0.00000|           0.00000|
|          25|         17|PCA (Individual)                |       1|HAR              |   155|          0.00000|       0.00000|           0.00000|          0.00000|           0.00000|
|          27|         22|PCA (Individual)                |       1|HAR+Macro        |   155|         -0.02583|      -0.49391|          -0.02168|         -0.78571|          -0.07558|
|          28|         25|Neural Network (Individual)     |       1|HAR              |   155|         -0.08039|      -1.86215|          -0.04388|          0.73883|           0.33964|
