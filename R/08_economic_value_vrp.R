#!/usr/bin/env Rscript

source(file.path("R", "00_packages.R"))
load_required_packages(c("data.table", "ggplot2"))
source(file.path("R", "functions", "framework", "00_config.R"))
source(file.path("R", "functions", "framework", "EVALUATION", "economic_value_vrp_strategy.R"))

config <- create_config(base_dir = getwd())
dir.create(config$paths$output_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(config$paths$figures_dir, recursive = TRUE, showWarnings = FALSE)

run_default_vrp_economic_evaluation(base_dir = getwd())

source(
  file.path("R", "paper", "result_scripts", "plot_scaled_short_only_utility_gain_gamma3.R"),
  local = new.env(parent = globalenv())
)

message("VRP economic-value evaluation complete.")
