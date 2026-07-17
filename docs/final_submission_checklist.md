# Final Submission Checklist

## Main Scripts

- [ ] `R/00_run_all.R` - master workflow entry point.
- [ ] `R/00_packages.R` - package dependency check/loading.
- [ ] `R/01_prepare_realized_variance.R` - monthly RV/RV target.
- [ ] `R/02_prepare_option_signals.R` - option-implied predictors.
- [ ] `R/03_prepare_macro_predictors.R` - macro-financial predictors.
- [ ] `R/04_build_master_dataset.R` - final monthly master dataset.
- [ ] `R/05_run_rolling_forecasts.R` - main 120-month forecasts plus 60/180 robustness tables.
- [ ] `R/06_forecast_combinations.R` - extended combination diagnostics.
- [ ] `R/07_forecast_evaluation.R` - DM/QLIKE and supporting evaluation scripts.
- [ ] `R/08_economic_value_vrp.R` - VRP economic-value evaluation.
- [ ] `R/09_create_tables_figures.R` - final tables and figures.
- [ ] `R/10_robustness_checks.R` - extra robustness diagnostics.

## Appendix / Supporting Scripts

- [ ] `R/11_run_model_universe_experiment.R`
- [ ] `R/12_create_model_universe_report.R`
- [ ] `R/paper/result_scripts/`
- [ ] `robustness/scripts/`
- [ ] Word export scripts in `R/paper/`
- [ ] `docs/session_info.txt`

## Final Tables

- [ ] `output/tables/main_forecast_results_table_final_selected.md`
- [ ] `output/tables/main_forecast_results_table_final_selected.csv`
- [ ] `output/tables/main_forecast_model_interpretation.md`
- [ ] `output/tables/dm_qlike_rolling120_vs_har.md`
- [ ] `output/tables/encompassing_rolling120_vs_har.md`
- [ ] `output/tables/economic_value_vrp_paper_table_primary_short_only_main_rolling120.md`
- [ ] `output/tables/economic_value_vrp_scaled_short_only_forecast_combinations_main_rolling120.md`
- [ ] `output/tables/model_universe_main_paper_table.csv`

## Final Figures

- [ ] `output/figures/main_forecast_error_cumulative_sq_gain_selected.png`
- [ ] `output/figures/main_forecast_error_absolute_selected.png`
- [ ] `output/figures/main_forecast_r2oos_cumulative_selected.png`
- [ ] `output/figures/main_forecast_r2oos_rolling36_selected.png`
- [ ] `output/figures/economic_value_vrp_cumulative_returns.png`
- [ ] `output/figures/economic_value_vrp_drawdowns.png`
- [ ] `output/figures/economic_value_vrp_scaled_short_only_cumulative_utility_gain_gamma3_vs_har_all_models.png`

## Robustness Outputs

- [ ] `robustness/output/tables/main_forecast_results_table_rolling60.md`
- [ ] `robustness/output/tables/main_forecast_results_table_rolling180.md`
- [ ] `robustness/output/tables/dm_squared_error_rolling_windows_vs_har.csv`
- [ ] `robustness/output/tables/har_augmented_common155_mcs.md`
- [ ] `robustness/output/tables/har_augmented_common155_mcs_subsets.md`

## Data Files Required

- [ ] `data/raw/Options_data_SPX.csv`
- [ ] `data/raw/SPY_daily_5min_vol.csv`
- [ ] `data/raw/SPX_daily_returns_1925.csv`
- [ ] `data/raw/[usa]_[all_factors]_[monthly]_[vw_cap].csv`
- [ ] `data/raw/[usa]_[mkt]_[daily]_[vw_cap].csv`
- [ ] `data/raw/(usa)_(mkt)_(monthly)_(vw_cap) 2.csv`
- [ ] `data/raw/(usa)_(all_themes)_(monthly)_(vw_cap).csv`
- [ ] `data/processed/master_dataset.csv`
- [ ] `data/processed/master_feature_dictionary.csv`
- [ ] `data/processed/forecast_panels/main_forecast_forecast_panel.csv`

## Files Moved To Archive / Delete Candidates

- [ ] Duplicate master dataset: `archive_delete_candidates/duplicates/master_dataset_duplicate_from_RScript_02_DATA.csv`
- [ ] IDE metadata: `archive_delete_candidates/ide_metadata/Rproj.user/`
- [ ] Local history and OS metadata: `archive_delete_candidates/temp_files/.Rhistory`, `.DS_Store`, `OUTPUT_Rhistory`, `RScript_02_DS_Store`
- [ ] Word lock files: `archive_delete_candidates/temp_files/~$*.docx`
- [ ] Weirdly prefixed temporary outputs: `archive_delete_candidates/temp_files/*** ...`
- [ ] Empty legacy shells: `DATA_empty_legacy_dir`, `OUTPUT_empty_legacy_dir`, `RScript_02_empty_legacy_dir`, `R_quick_tests_empty_dir`, `scripts_empty_legacy_dir`, `Strategy_empty_dir`

## Human Review Before ZIP

- [ ] Confirm that raw data may legally be submitted. If not, exclude `data/raw/` and document source instructions.
- [ ] Run `source("R/00_run_all.R")` from a clean R session if time permits.
- [ ] Open the main Markdown/Word tables and confirm they match the paper text.
- [ ] Confirm `archive_delete_candidates/` should be excluded from the final examiner ZIP.
- [ ] Confirm exploratory material in `extra/` should be included only if useful for documentation.
