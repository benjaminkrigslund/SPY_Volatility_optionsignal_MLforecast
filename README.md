# Economic Forecasting Project

This project forecasts monthly S&P 500 realized volatility / realized variance using HAR benchmarks, option-implied predictors, macro-financial predictors, machine-learning models, forecast combinations, and VRP economic-value timing strategies.

## Reproducible Workflow

Run the project from the repository root:

```r
source("R/00_run_all.R")
```

The master script:

1. Builds the final monthly master dataset.
2. Runs the main 120-month rolling log-RV forecast workflow.
3. Generates the 60- and 180-month rolling-window robustness tables from the same forecast script.
4. Runs the VRP economic-value evaluation.
5. Recreates final paper tables and figures.

Optional heavier diagnostics can be enabled with environment flags before running `R/00_run_all.R`:

```r
Sys.setenv(RUN_COMPONENT_PREP = "true")
Sys.setenv(RUN_EXTENDED_COMBINATIONS = "true")
Sys.setenv(RUN_FORECAST_EVALUATION = "true")
Sys.setenv(RUN_EXTRA_ROBUSTNESS = "true")
Sys.setenv(EXPORT_WORD_TABLES = "true")
source("R/00_run_all.R")
```

## Folder Structure

- `R/`: numbered scripts for the final workflow.
- `R/functions/`: reusable helpers and the modular forecasting framework.
- `R/paper/`: Word export scripts and supporting paper-output scripts.
- `data/raw/`: raw input files used to construct the monthly dataset.
- `data/processed/`: cleaned master data, feature dictionary, and main forecast panel.
- `output/tables/`: final tables used in the paper and appendix.
- `output/figures/`: final figures used in the paper and appendix.
- `robustness/`: robustness scripts and outputs.
- `docs/`: paper drafts, submission notes, and final checklist.

This upload package intentionally excludes exploratory material, archive/delete
candidates, local metadata, and bulky intermediate model artifacts that can be
regenerated from the workflow.

## Required R Packages

The required packages are listed in `R/00_packages.R`: `data.table`, `dplyr`, `tidyr`, `lubridate`, `purrr`, `glmnet`, `pls`, `ranger`, `nnet`, `ggplot2`, `knitr`, `MCS`, `openxlsx`, `officer`, and `flextable`.

To install missing packages automatically:

```r
Sys.setenv(INSTALL_MISSING_PACKAGES = "true")
source("R/00_packages.R")
```

## Required Input Data

The current raw inputs are in `data/raw/`. Confirm that these files are allowed to be submitted before creating the final ZIP, especially the option and factor data:

- `Options_data_SPX.csv`
- `SPY_daily_5min_vol.csv`
- `SPX_daily_returns_1925.csv`
- `[usa]_[all_factors]_[monthly]_[vw_cap].csv`
- `[usa]_[mkt]_[daily]_[vw_cap].csv`
- `(usa)_(mkt)_(monthly)_(vw_cap) 2.csv`
- `(usa)_(all_themes)_(monthly)_(vw_cap).csv`

If any raw data are proprietary, keep the code but remove the restricted raw files from the submission ZIP and document the data source in `data/README.md`.

## Final Outputs

Main final outputs are in:

- `output/tables/main_forecast_results_table_final_selected.md`
- `output/tables/main_forecast_results_table_final_selected.csv`
- `output/tables/main_forecast_model_interpretation.md`
- `output/tables/economic_value_vrp_paper_table_primary_short_only_main_rolling120.md`
- `output/figures/main_forecast_error_cumulative_sq_gain_selected.png`
- `output/figures/main_forecast_r2oos_cumulative_selected.png`
- `output/figures/economic_value_vrp_scaled_short_only_cumulative_utility_gain_gamma3_vs_har_all_models.png`

See `docs/final_submission_checklist.md` for the full submission checklist and human-review items.
