#!/usr/bin/env Rscript

source(file.path("R", "00_packages.R"))
load_required_packages(c("data.table", "knitr", "MCS"))

run_script <- function(path) {
  message("Running ", path)
  source(path, local = new.env(parent = globalenv()))
}

evaluation_scripts <- c(
  file.path("R", "09_create_final_selected_table.R"),
  file.path("R", "paper", "result_scripts", "run_dm_qlike_vs_har_log_rolling.R"),
  file.path("R", "paper", "result_scripts", "run_har_augmented_combo_leaderboard_common155.R")
)

for (script in evaluation_scripts[file.exists(evaluation_scripts)]) {
  run_script(script)
}

message("Forecast-evaluation scripts complete.")
