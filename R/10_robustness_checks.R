#!/usr/bin/env Rscript

source(file.path("R", "00_packages.R"))
load_required_packages(c("data.table", "glmnet", "ranger", "nnet", "knitr", "MCS"))

run_script <- function(path) {
  message("Running ", path)
  source(path, local = new.env(parent = globalenv()))
}

# R/05_run_rolling_forecasts.R generates the 60- and 180-month rolling-window
# tables. The scripts below rebuild additional diagnostics and MCS checks.
robustness_scripts <- c(
  file.path("robustness", "scripts", "run_har_augmented_common155_mcs.R"),
  file.path("robustness", "scripts", "run_har_augmented_common155_mcs_subsets.R"),
  file.path("robustness", "scripts", "run_har_augmented_rankings_robustness.R"),
  file.path("robustness", "scripts", "05_run_model_universe_qlike_tuned.R")
)

for (script in robustness_scripts[file.exists(robustness_scripts)]) {
  run_script(script)
}

message("Robustness scripts complete.")
