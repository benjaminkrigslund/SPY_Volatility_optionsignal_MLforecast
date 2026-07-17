# Main Forecast Model Interpretation

Scope:
- Individual model diagnostics focus on the 120-month rolling log-RV HAR+Option specification.
- Elastic Net selection is reported as non-zero coefficient frequency across rolling refits.
- Random Forest does not have linear coefficients, so its table reports impurity importance and how often a variable appears in the top five within a refit.
- Stacked forecast diagnostics use the available all-model meta-combination selection files, filtered to the 16 individual forecasts used as candidates in the current main-table stacked forecasts.

Interpretation summary:
- Elastic Net keeps the three HAR lags by construction, but the option variables most persistently selected are option-implied variance/volatility level measures and dispersion measures. That says the gain is not just a richer autoregressive HAR; it is mainly forward-looking option information about expected variance and volatility disagreement.
- Random Forest puts the strongest importance on the option volatility surface: put 25-delta IV, ATM IV, total implied variance, and call 25-delta IV are almost always among the top variables. The short HAR lag still matters, but the longer HAR lags are much less central in the RF ranking.
- In the stacked combinations, the meta models lean heavily toward option-augmented forecasts, especially PCA HAR+Option, RF HAR+Option, NN HAR+Macro+Option, and several ENET/RF macro-option variants. This is consistent with the main table: the best standalone model is Elastic Net HAR+Option, but combinations also harvest useful signal from nonlinear and dimension-reduction forecasts.

## Elastic Net HAR+Option Variable Selection

|variable                      |feature_group | selected_refits| selection_rate| mean_abs_coefficient| median_abs_coefficient| latest_abs_coefficient|
|:-----------------------------|:-------------|---------------:|--------------:|--------------------:|----------------------:|----------------------:|
|realized vol                  |HAR           |             237|        1.00000|              0.19059|                0.18944|                0.25309|
|3-month mean of realized vol  |HAR           |             237|        1.00000|              0.11723|                0.09296|                0.01979|
|12-month mean of realized vol |HAR           |             237|        1.00000|              0.05693|                0.02913|                0.00817|
|call 25 iv eom                |Option        |             205|        0.86498|              0.12917|                0.12546|                0.16520|
|atm iv eom                    |Option        |             203|        0.85654|              0.10827|                0.09894|                0.04146|
|put 25 dispersion eom         |Option        |             187|        0.78903|              0.10118|                0.08954|                0.00912|
|implied var month avg         |Option        |             185|        0.78059|              0.18085|                0.19254|                0.15848|
|mean dispersion eom           |Option        |             177|        0.74684|              0.03250|                0.02746|                0.03458|
|smile curvature 25 month avg  |Option        |             174|        0.73418|              0.05113|                0.05011|                0.00252|
|put 25 iv eom                 |Option        |             169|        0.71308|              0.05542|                0.04513|                0.03351|
|atm dispersion eom            |Option        |             161|        0.67932|              0.10111|                0.09047|                0.01958|
|smile curvature 25 eom        |Option        |             161|        0.67932|              0.06587|                0.06243|                0.00363|

## Random Forest HAR+Option Variable Importance

|variable                      |feature_group | refits_used| top5_refits| top5_rate| mean_importance| median_importance| latest_importance| mean_rank|
|:-----------------------------|:-------------|-----------:|-----------:|---------:|---------------:|-----------------:|-----------------:|---------:|
|put 25 iv eom                 |Option        |         217|         216|   0.99539|         1.91174|           1.99253|           1.90260|   2.02765|
|atm iv eom                    |Option        |         217|         216|   0.99539|         1.80977|           1.75651|           2.73043|   2.73733|
|implied var eom               |Option        |         217|         201|   0.92627|         1.84028|           1.70247|           2.65082|   2.62673|
|call 25 iv eom                |Option        |         217|         198|   0.91244|         1.72806|           1.53216|           2.36912|   3.51613|
|realized vol                  |HAR           |         217|          77|   0.35484|         1.25963|           1.28504|           1.65487|   6.74194|
|atm dispersion eom            |Option        |         217|          56|   0.25806|         1.04147|           0.94474|           0.54288|   8.38249|
|implied var month avg         |Option        |         217|          35|   0.16129|         1.00304|           0.91084|           1.47811|   9.35945|
|skew 10 eom                   |Option        |         217|          27|   0.12442|         0.89870|           0.96093|           0.51149|  10.43318|
|downside skew 10 eom          |Option        |         217|          14|   0.06452|         0.60744|           0.55739|           0.30518|  15.57143|
|vrp forward eom               |Option        |         217|          10|   0.04608|         0.77477|           0.70924|           1.37921|  11.69124|
|downside skew eom             |Option        |         217|          10|   0.04608|         0.79912|           0.78729|           0.37438|  12.75115|
|12-month mean of realized vol |HAR           |         217|           8|   0.03687|         0.41229|           0.39626|           0.57103|  18.42396|

## Stacked Forecast Candidate Set

|method         |information_set  |
|:--------------|:----------------|
|Elastic Net    |HAR              |
|Elastic Net    |HAR+Macro        |
|Elastic Net    |HAR+Macro+Option |
|Elastic Net    |HAR+Option       |
|Neural Network |HAR              |
|Neural Network |HAR+Macro        |
|Neural Network |HAR+Macro+Option |
|Neural Network |HAR+Option       |
|PCA            |HAR              |
|PCA            |HAR+Macro        |
|PCA            |HAR+Macro+Option |
|PCA            |HAR+Option       |
|Random Forest  |HAR              |
|Random Forest  |HAR+Macro        |
|Random Forest  |HAR+Macro+Option |
|Random Forest  |HAR+Option       |

## Stacked Elastic Net Selected Forecasts

|method         |information_set  | months_selected| selection_rate| mean_coefficient| share_positive| mean_abs_coefficient| latest_coefficient|
|:--------------|:----------------|---------------:|--------------:|----------------:|--------------:|--------------------:|------------------:|
|PCA            |HAR+Option       |             165|        0.80097|          0.08272|        0.99394|              0.08344|            0.05604|
|Neural Network |HAR+Macro+Option |             150|        0.72816|          0.06541|        1.00000|              0.06541|            0.04018|
|Random Forest  |HAR+Macro        |             124|        0.60194|          0.08237|        0.92742|              0.08301|           -0.01167|
|Elastic Net    |HAR+Macro+Option |             109|        0.52913|         -0.08140|        0.18349|              0.08502|            0.00167|
|Elastic Net    |HAR+Macro        |             107|        0.51942|          0.06671|        0.98131|              0.06776|            0.00127|
|Neural Network |HAR+Macro        |             103|        0.50000|         -0.00165|        0.52427|              0.03678|            0.01694|
|Neural Network |HAR              |              91|        0.44175|          0.01765|        0.81319|              0.03346|            0.06333|
|Random Forest  |HAR+Option       |              83|        0.40291|          0.08111|        1.00000|              0.08111|            0.00360|
|Elastic Net    |HAR+Option       |              74|        0.35922|          0.04753|        1.00000|              0.04753|            0.09280|
|PCA            |HAR+Macro+Option |              68|        0.33010|         -0.04290|        0.64706|              0.06770|            0.00642|
|Neural Network |HAR+Option       |              66|        0.32039|          0.00315|        0.54545|              0.01709|           -0.01801|
|Random Forest  |HAR              |              62|        0.30097|          0.00877|        0.37097|              0.05186|            0.01731|

## Stacked Random Forest Forecast Importance

|method         |information_set  | months_used| top5_months| top5_rate| mean_importance| median_importance| latest_importance| mean_rank|
|:--------------|:----------------|-----------:|-----------:|---------:|---------------:|-----------------:|-----------------:|---------:|
|PCA            |HAR+Option       |         190|         190|   0.92233|         2.51940|           2.25742|           3.79391|   1.41579|
|Random Forest  |HAR+Option       |         175|         117|   0.56796|         1.53883|           1.49671|           2.76103|   4.98286|
|Neural Network |HAR+Macro+Option |         155|         115|   0.55825|         1.40946|           1.30330|           1.31854|   3.74839|
|Elastic Net    |HAR              |         206|         112|   0.54369|         1.21582|           1.02254|           4.67357|   6.02427|
|Elastic Net    |HAR+Macro        |         180|         108|   0.52427|         1.17946|           1.13176|           1.29216|   5.07778|
|Elastic Net    |HAR+Option       |         195|          83|   0.40291|         1.20782|           0.64792|           3.71098|   7.74872|
|Random Forest  |HAR              |         206|          79|   0.38350|         1.15350|           0.99668|           4.91584|   6.88835|
|Random Forest  |HAR+Macro        |         180|          72|   0.34951|         1.01108|           0.84727|           0.65852|   7.43889|
|PCA            |HAR              |         206|          50|   0.24272|         1.14994|           1.02984|           4.87837|   6.89806|
|Random Forest  |HAR+Macro+Option |         155|          38|   0.18447|         0.96949|           1.07245|           0.98340|   7.90968|
|PCA            |HAR+Macro+Option |         170|          29|   0.14078|         0.88831|           0.87448|           0.75798|   8.26471|
|Elastic Net    |HAR+Macro+Option |         175|          21|   0.10194|         0.60349|           0.35013|           1.75263|  10.46286|
