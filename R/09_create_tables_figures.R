#!/usr/bin/env Rscript

source(file.path("R", "00_packages.R"))
load_required_packages(c("data.table", "ggplot2", "knitr"))

run_script <- function(path) {
  message("Running ", path)
  source(path, local = new.env(parent = globalenv()))
}

paper_output_scripts <- c(
  file.path("R", "09_create_final_selected_table.R"),
  file.path("R", "09_create_forecast_error_figures.R"),
  file.path("R", "09_create_r2oos_figures.R"),
  file.path("R", "09_create_model_interpretation.R"),
  file.path("R", "paper", "result_scripts", "plot_scaled_short_only_utility_gain_gamma3.R")
)

for (script in paper_output_scripts[file.exists(paper_output_scripts)]) {
  run_script(script)
}

if (identical(tolower(Sys.getenv("EXPORT_WORD_TABLES", "false")), "true")) {
  load_required_packages(c("officer", "flextable"))
  run_script(file.path("R", "paper", "export_main_forecast_table_word.R"))
  run_script(file.path("R", "paper", "export_main_forecast_model_interpretation_word.R"))
  run_script(file.path("R", "paper", "export_encompassing_tests_word.R"))
}

message("Final table and figure scripts complete.")
