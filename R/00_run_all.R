#!/usr/bin/env Rscript

source(file.path("R", "functions", "project_paths.R"))
setwd(find_project_root())

source(file.path("R", "00_packages.R"))

flag <- function(name, default = TRUE) {
  value <- Sys.getenv(name, if (isTRUE(default)) "true" else "false")
  identical(tolower(value), "true")
}

run_script <- function(path) {
  message("\n==> Running ", path)
  source(path, local = new.env(parent = globalenv()))
}

dir.create(file.path("data", "processed"), recursive = TRUE, showWarnings = FALSE)
dir.create(file.path("data", "processed", "forecast_panels"), recursive = TRUE, showWarnings = FALSE)
dir.create(file.path("output", "tables"), recursive = TRUE, showWarnings = FALSE)
dir.create(file.path("output", "figures"), recursive = TRUE, showWarnings = FALSE)
dir.create(file.path("robustness", "output", "tables"), recursive = TRUE, showWarnings = FALSE)
dir.create(file.path("robustness", "output", "figures"), recursive = TRUE, showWarnings = FALSE)

# Main paper workflow. The heavy rolling forecast script also writes the
# 60- and 180-month rolling-window robustness tables.
if (flag("RUN_COMPONENT_PREP", FALSE)) {
  run_script(file.path("R", "01_prepare_realized_variance.R"))
  run_script(file.path("R", "02_prepare_option_signals.R"))
  run_script(file.path("R", "03_prepare_macro_predictors.R"))
}

if (flag("RUN_BUILD_MASTER", TRUE)) {
  run_script(file.path("R", "04_build_master_dataset.R"))
}

if (flag("RUN_MAIN_FORECASTS", TRUE)) {
  run_script(file.path("R", "05_run_rolling_forecasts.R"))
}

if (flag("RUN_EXTENDED_COMBINATIONS", FALSE)) {
  run_script(file.path("R", "06_forecast_combinations.R"))
}

if (flag("RUN_FORECAST_EVALUATION", FALSE)) {
  run_script(file.path("R", "07_forecast_evaluation.R"))
}

if (flag("RUN_ECONOMIC_VALUE", TRUE)) {
  run_script(file.path("R", "08_economic_value_vrp.R"))
}

if (flag("RUN_TABLES_FIGURES", TRUE)) {
  run_script(file.path("R", "09_create_tables_figures.R"))
}

if (flag("RUN_EXTRA_ROBUSTNESS", FALSE)) {
  run_script(file.path("R", "10_robustness_checks.R"))
}

message("\nAll selected workflow steps finished.")
