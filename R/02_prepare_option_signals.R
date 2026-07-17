#!/usr/bin/env Rscript

source(file.path("R", "00_packages.R"))
load_required_packages(c("data.table", "dplyr", "tidyr", "lubridate", "purrr"))
source(file.path("R", "functions", "framework", "00_config.R"))
source(file.path("R", "functions", "framework", "UTILS", "helpers.R"))
source(file.path("R", "functions", "framework", "DATA", "monthly_vol_target_utils.R"))

config <- create_config(base_dir = getwd())
ensure_dir(config$paths$processed_data_dir)

monthly_rv <- build_monthly_spy_5min_vol(
  data_path = file.path(config$paths$data_dir, ""),
  month_position = "end"
)

option_signals <- build_monthly_option_signals(
  data_path = file.path(config$paths$data_dir, ""),
  realized_vol_data = monthly_rv,
  lag_predictors = FALSE
)

data.table::fwrite(
  data.table::as.data.table(option_signals),
  file.path(config$paths$processed_data_dir, "monthly_option_predictors.csv")
)

message("Saved monthly option-implied predictors to data/processed/monthly_option_predictors.csv")
