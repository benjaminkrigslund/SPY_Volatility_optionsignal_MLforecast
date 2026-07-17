library(data.table)

source(file.path("R", "functions", "framework", "00_config.R"))
source(file.path("R", "functions", "framework", "UTILS", "helpers.R"))

config <- create_config(base_dir = getwd())

input_files <- c(
  "combo_equal_weight_ml_h_o_m_log_rolling_evaluation.csv",
  "equal_weight_extended_ml_combos_log_rolling_vs_har_evaluation.csv",
  "combo_of_family_winners_log_rolling_evaluation.csv",
  "family_combo_equal_weight_h_o_m_log_rolling_evaluation.csv",
  "rf_log_rolling_har_o_m_evaluation.csv",
  "combo_meta_ml_x_dataset_log_rolling_vs_har.csv",
  "stacked_ml_on_20_clean_forecasts_log_rolling_vs_har_evaluation.csv",
  "stacked_ml_on_35_extended_forecasts_log_rolling_vs_har_evaluation.csv"
)

required_cols <- c(
  "specification", "forecast_id", "n_oos", "n_common", "oos_r2", "oos_r2_vs_har",
  "qlike", "qlike_combo", "qlike_gain_vs_har", "combo_group", "combo_family",
  "avg_n_members", "median_n_members", "n_members"
)

read_combo_file <- function(file_name, results_dir) {
  path <- file.path(results_dir, file_name)
  if (!file.exists(path)) {
    stop("Missing combo result file: ", path)
  }

  dt <- fread(path)
  for (col in setdiff(required_cols, names(dt))) {
    dt[, (col) := NA]
  }
  dt[, source_file := file_name]
  dt[]
}

classify_combo_type <- function(forecast_id, source_file, combo_group) {
  data.table::fcase(
    grepl("^stacked_", forecast_id), "Stacked Forecasts",
    grepl("^combo_meta_", forecast_id), "Meta Combination",
    source_file == "equal_weight_extended_ml_combos_log_rolling_vs_har_evaluation.csv" &
      combo_group == "all_extended_ml_x_dataset", "Equal Weight: Full Extended Panel",
    source_file == "equal_weight_extended_ml_combos_log_rolling_vs_har_evaluation.csv" &
      combo_group == "within_ml_method_across_extended_datasets", "Equal Weight: By ML Method Across Datasets",
    source_file == "equal_weight_extended_ml_combos_log_rolling_vs_har_evaluation.csv" &
      combo_group == "within_dataset_across_ml_methods", "Equal Weight: By Dataset Across ML Methods",
    source_file == "combo_equal_weight_ml_h_o_m_log_rolling_evaluation.csv", "Equal Weight: ML Universe Blocks",
    source_file == "family_combo_equal_weight_h_o_m_log_rolling_evaluation.csv", "Equal Weight: Within Family",
    source_file == "combo_of_family_winners_log_rolling_evaluation.csv", "Equal Weight: Family Winners",
    source_file == "rf_log_rolling_har_o_m_evaluation.csv", "Equal Weight: RF Only",
    default = "Other Combo"
  )
}

all_results <- rbindlist(
  lapply(input_files, read_combo_file, results_dir = config$paths$results_dir),
  fill = TRUE,
  use.names = TRUE
)

combo_results <- all_results[
  grepl("combo|stacked", forecast_id, ignore.case = TRUE) |
    grepl("Equal weight|Family winner|stacked", specification, ignore.case = TRUE)
]

leaderboard <- combo_results[
  ,
  .(
    combo_name = fifelse(!is.na(specification), specification, forecast_id),
    forecast_id = forecast_id,
    combo_type = classify_combo_type(forecast_id, source_file, combo_group),
    n_eval = fifelse(!is.na(n_oos), as.integer(n_oos), as.integer(n_common)),
    oos_r2 = fifelse(!is.na(oos_r2), as.numeric(oos_r2), as.numeric(oos_r2_vs_har)),
    qlike = fifelse(!is.na(qlike), as.numeric(qlike), as.numeric(qlike_combo)),
    qlike_gain_vs_har = as.numeric(qlike_gain_vs_har),
    n_members = fifelse(!is.na(n_members), as.integer(n_members), as.integer(median_n_members)),
    source_file = source_file
  )
]

leaderboard <- unique(leaderboard, by = c("combo_name", "forecast_id", "source_file"))
leaderboard <- leaderboard[is.finite(oos_r2) & is.finite(qlike)]
leaderboard[, rank_oos_r2 := data.table::frank(-oos_r2, ties.method = "min")]
leaderboard[, rank_qlike := data.table::frank(qlike, ties.method = "min")]
setorder(leaderboard, rank_oos_r2, rank_qlike, combo_name)

output_results <- file.path(config$paths$results_dir, "combo_leaderboard_overview.csv")
output_output <- file.path(config$paths$output_dir, "combo_leaderboard_overview.csv")

ensure_dir(config$paths$output_dir)
fwrite(leaderboard, output_results)
fwrite(leaderboard, output_output)

message("Saved combo leaderboard to: ", output_results)
message("Saved combo leaderboard copy to: ", output_output)
print(leaderboard)
