#!/usr/bin/env Rscript

source(file.path("R", "00_packages.R"))
load_required_packages(c("data.table", "dplyr", "tidyr", "lubridate", "purrr"))
source(file.path("R", "functions", "framework", "00_config.R"))
source(file.path("R", "functions", "framework", "UTILS", "helpers.R"))
source(file.path("R", "functions", "framework", "DATA", "build_master_dataset.R"))

config <- create_config(base_dir = getwd())
ensure_dir(config$paths$processed_data_dir)

build_master_dataset(
  data_path = config$paths$data_dir,
  output_path = config$paths$master_data,
  framework_copy_path = file.path(config$paths$processed_data_dir, "master_dataset.csv"),
  feature_dictionary_path = config$paths$feature_dictionary,
  start_date = as.Date("1972-01-31"),
  save_outputs = TRUE
)

message("Saved final monthly master dataset and feature dictionary in data/processed/")
