#!/usr/bin/env Rscript

source(file.path("R", "00_packages.R"))
load_required_packages(c("data.table", "dplyr", "tidyr", "lubridate", "purrr"))
source(file.path("R", "functions", "framework", "00_config.R"))
source(file.path("R", "functions", "framework", "UTILS", "helpers.R"))
source(file.path("R", "functions", "framework", "DATA", "monthly_vol_target_utils.R"))

config <- create_config(base_dir = getwd())
ensure_dir(config$paths$processed_data_dir)

macro_predictors <- build_monthly_factor_matrix(
  data_path = file.path(config$paths$data_dir, ""),
  start_date = as.Date("1972-01-31"),
  lag_predictors = FALSE
)

data.table::fwrite(
  data.table::as.data.table(macro_predictors),
  file.path(config$paths$processed_data_dir, "monthly_macro_predictors.csv")
)

message("Saved monthly macro-financial predictors to data/processed/monthly_macro_predictors.csv")
