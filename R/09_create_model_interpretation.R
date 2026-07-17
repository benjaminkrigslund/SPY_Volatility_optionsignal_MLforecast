#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(data.table)
  library(knitr)
})

output_dir <- file.path(getwd(), "output", "tables")
results_dir <- file.path(getwd(), "data", "processed", "model_artifacts")
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

paths <- list(
  main_panel = file.path(getwd(), "data", "processed", "forecast_panels", "main_forecast_forecast_panel.csv"),
  feature_dictionary = file.path(getwd(), "data", "processed", "master_feature_dictionary.csv"),
  enet_har_o = file.path(results_dir, "har_augmented_common155_monthly_refit_enet_har_o_selection.csv"),
  rf_har_o = file.path(results_dir, "har_augmented_common155_monthly_refit_rf_har_o_importance.csv"),
  stacked_enet_raw = file.path(results_dir, "combo_meta_enet_picked_forecasts.csv"),
  stacked_rf_raw = file.path(results_dir, "combo_meta_rf_forecast_importance.csv")
)

missing_paths <- names(paths)[!file.exists(unlist(paths))]
if (length(missing_paths) > 0L) {
  stop(
    "Missing required interpretation inputs: ",
    paste(paste0(missing_paths, "=", unlist(paths)[missing_paths]), collapse = "; ")
  )
}

info_set_labels <- c(
  HAR = "HAR",
  HAR_O = "HAR+Option",
  HAR_M = "HAR+Macro",
  HAR_OM = "HAR+Macro+Option"
)

model_labels <- c(
  enet = "Elastic Net",
  pca = "PCA",
  rf = "Random Forest",
  nn = "Neural Network"
)

forecast_label <- function(forecast_id) {
  parts <- strsplit(forecast_id, "__", fixed = TRUE)[[1]]
  if (length(parts) < 2L) {
    return(forecast_id)
  }

  method <- model_labels[[parts[1]]] %||% parts[1]
  info_set <- info_set_labels[[parts[2]]] %||% parts[2]
  paste(method, info_set, sep = " | ")
}

forecast_method <- function(forecast_id) {
  parts <- strsplit(forecast_id, "__", fixed = TRUE)[[1]]
  model_labels[[parts[1]]] %||% parts[1]
}

forecast_info_set <- function(forecast_id) {
  parts <- strsplit(forecast_id, "__", fixed = TRUE)[[1]]
  info_set_labels[[parts[2]]] %||% parts[2]
}

pretty_variable <- function(x) {
  x <- gsub("_", " ", x, fixed = TRUE)
  trimws(gsub("[[:space:]]+", " ", x))
}

`%||%` <- function(x, y) {
  if (is.null(x) || length(x) == 0L || is.na(x)) y else x
}

dictionary <- fread(paths$feature_dictionary)
dictionary <- dictionary[, .(
  variable = feature_name,
  feature_group,
  source_name
)]

main_panel <- fread(paths$main_panel)
main_panel <- main_panel[rolling_window_months == 120L]

stacked_members <- unique(main_panel[
  forecast_id %in% c(
    "stacked_enet_on_har_augmented_forecasts_log_rolling",
    "stacked_rf_on_har_augmented_forecasts_log_rolling"
  ),
  combination_members
])

stacked_members <- stacked_members[!is.na(stacked_members)]
if (length(stacked_members) == 0L) {
  stop("Could not find stacked combination members in the main forecast panel.")
}

candidate_ids <- sort(unique(unlist(strsplit(stacked_members[1], " | ", fixed = TRUE))))

stacked_candidates <- data.table(
  individual_forecast = candidate_ids,
  forecast_label = vapply(candidate_ids, forecast_label, character(1)),
  method = vapply(candidate_ids, forecast_method, character(1)),
  information_set = vapply(candidate_ids, forecast_info_set, character(1))
)
setorder(stacked_candidates, method, information_set)

enet_har_o <- fread(paths$enet_har_o)
enet_har_o <- merge(enet_har_o, dictionary, by = "variable", all.x = TRUE)
enet_har_o[, `:=`(
  variable_label = fifelse(is.na(source_name), pretty_variable(variable), source_name),
  feature_group = fifelse(is.na(feature_group), "unknown", feature_group)
)]
setorder(enet_har_o, -selection_rate, -mean_abs_coefficient)

rf_har_o <- fread(paths$rf_har_o)
rf_har_o <- merge(rf_har_o, dictionary, by = "variable", all.x = TRUE)
rf_har_o[, `:=`(
  variable_label = fifelse(is.na(source_name), pretty_variable(variable), source_name),
  feature_group = fifelse(is.na(feature_group), "unknown", feature_group)
)]
setorder(rf_har_o, -top5_rate, mean_rank, -mean_importance)

stacked_enet_raw <- fread(paths$stacked_enet_raw)
stacked_enet_total_months <- uniqueN(stacked_enet_raw$target_date)
stacked_enet <- stacked_enet_raw[
  individual_forecast %in% candidate_ids
][
  ,
  .(
    months_selected = uniqueN(target_date),
    selection_rate = uniqueN(target_date) / stacked_enet_total_months,
    first_selected = min(as.Date(target_date)),
    last_selected = max(as.Date(target_date)),
    mean_coefficient = mean(coefficient, na.rm = TRUE),
    share_positive = mean(coefficient > 0, na.rm = TRUE),
    mean_abs_coefficient = mean(abs_coefficient, na.rm = TRUE),
    latest_coefficient = coefficient[which.max(as.Date(target_date))]
  ),
  by = individual_forecast
]
stacked_enet[, `:=`(
  forecast_label = vapply(individual_forecast, forecast_label, character(1)),
  method = vapply(individual_forecast, forecast_method, character(1)),
  information_set = vapply(individual_forecast, forecast_info_set, character(1))
)]
setcolorder(stacked_enet, c(
  "individual_forecast",
  "forecast_label",
  "method",
  "information_set",
  setdiff(names(stacked_enet), c("individual_forecast", "forecast_label", "method", "information_set"))
))
setorder(stacked_enet, -selection_rate, -mean_abs_coefficient)

stacked_rf_raw <- fread(paths$stacked_rf_raw)
stacked_rf_raw <- stacked_rf_raw[individual_forecast %in% candidate_ids]
stacked_rf_total_months <- uniqueN(stacked_rf_raw$target_date)
stacked_rf_raw[, rank_in_month := frank(-importance, ties.method = "min"), by = target_date]
stacked_rf <- stacked_rf_raw[
  ,
  .(
    months_used = uniqueN(target_date),
    top5_months = uniqueN(target_date[rank_in_month <= 5]),
    top5_rate = uniqueN(target_date[rank_in_month <= 5]) / stacked_rf_total_months,
    first_used = min(as.Date(target_date)),
    last_used = max(as.Date(target_date)),
    mean_importance = mean(importance, na.rm = TRUE),
    median_importance = median(importance, na.rm = TRUE),
    latest_importance = importance[which.max(as.Date(target_date))],
    mean_rank = mean(rank_in_month, na.rm = TRUE)
  ),
  by = individual_forecast
]
stacked_rf[, `:=`(
  forecast_label = vapply(individual_forecast, forecast_label, character(1)),
  method = vapply(individual_forecast, forecast_method, character(1)),
  information_set = vapply(individual_forecast, forecast_info_set, character(1))
)]
setcolorder(stacked_rf, c(
  "individual_forecast",
  "forecast_label",
  "method",
  "information_set",
  setdiff(names(stacked_rf), c("individual_forecast", "forecast_label", "method", "information_set"))
))
setorder(stacked_rf, -top5_rate, mean_rank, -mean_importance)

round_cols <- function(dt, cols, digits = 5) {
  cols <- intersect(cols, names(dt))
  out <- copy(dt)
  out[, (cols) := lapply(.SD, round, digits = digits), .SDcols = cols]
  out[]
}

drop_report_columns <- function(dt, cols) {
  cols <- intersect(cols, names(dt))
  if (length(cols) == 0L) {
    return(dt)
  }
  dt[, (cols) := NULL]
  dt
}

clean_variable_report_table <- function(dt) {
  dt <- copy(dt)
  if ("variable_label" %in% names(dt)) {
    dt[, variable := pretty_variable(variable_label)]
    dt[, variable_label := NULL]
  } else if ("variable" %in% names(dt)) {
    dt[, variable := pretty_variable(variable)]
  }
  if ("feature_group" %in% names(dt)) {
    dt[, feature_group := fifelse(tolower(feature_group) == "har", "HAR", tools::toTitleCase(feature_group))]
  }
  setcolorder(dt, c("variable", "feature_group", setdiff(names(dt), c("variable", "feature_group"))))
  dt
}

clean_forecast_report_table <- function(dt) {
  dt <- copy(dt)
  dt <- drop_report_columns(dt, c(
    "individual_forecast",
    "forecast_label",
    "first_selected",
    "last_selected",
    "first_used",
    "last_used"
  ))
  setcolorder(dt, c("method", "information_set", setdiff(names(dt), c("method", "information_set"))))
  dt
}

enet_export <- round_cols(
  enet_har_o[, .(
    variable,
    variable_label,
    feature_group,
    selected_refits,
    selection_rate,
    mean_abs_coefficient,
    median_abs_coefficient,
    latest_abs_coefficient
  )],
  c("selection_rate", "mean_abs_coefficient", "median_abs_coefficient", "latest_abs_coefficient")
)

rf_export <- round_cols(
  rf_har_o[, .(
    variable,
    variable_label,
    feature_group,
    refits_used,
    top5_refits,
    top5_rate,
    mean_importance,
    median_importance,
    latest_importance,
    mean_rank
  )],
  c("top5_rate", "mean_importance", "median_importance", "latest_importance", "mean_rank")
)

stacked_enet_export <- round_cols(
  stacked_enet,
  c("selection_rate", "mean_coefficient", "share_positive", "mean_abs_coefficient", "latest_coefficient")
)

stacked_rf_export <- round_cols(
  stacked_rf,
  c("top5_rate", "mean_importance", "median_importance", "latest_importance", "mean_rank")
)

fwrite(enet_export, file.path(output_dir, "main_forecast_enet_har_option_selection.csv"))
fwrite(rf_export, file.path(output_dir, "main_forecast_rf_har_option_importance.csv"))
fwrite(stacked_candidates, file.path(output_dir, "main_forecast_stacked_candidate_forecasts.csv"))
fwrite(stacked_enet_export, file.path(output_dir, "main_forecast_stacked_enet_selected_forecasts.csv"))
fwrite(stacked_rf_export, file.path(output_dir, "main_forecast_stacked_rf_forecast_importance.csv"))

top_enet <- clean_variable_report_table(enet_export[1:min(.N, 12L)])
top_rf <- clean_variable_report_table(rf_export[1:min(.N, 12L)])
stacked_candidates_report <- clean_forecast_report_table(stacked_candidates)
top_stacked_enet <- clean_forecast_report_table(stacked_enet_export[1:min(.N, 12L)])
top_stacked_rf <- clean_forecast_report_table(stacked_rf_export[1:min(.N, 12L)])

md_path <- file.path(output_dir, "main_forecast_model_interpretation.md")

writeLines(
  c(
    "# Main Forecast Model Interpretation",
    "",
    "Scope:",
    "- Individual model diagnostics focus on the 120-month rolling log-RV HAR+Option specification.",
    "- Elastic Net selection is reported as non-zero coefficient frequency across rolling refits.",
    "- Random Forest does not have linear coefficients, so its table reports impurity importance and how often a variable appears in the top five within a refit.",
    "- Stacked forecast diagnostics use the available all-model meta-combination selection files, filtered to the 16 individual forecasts used as candidates in the current main-table stacked forecasts.",
    "",
    "Interpretation summary:",
    "- Elastic Net keeps the three HAR lags by construction, but the option variables most persistently selected are option-implied variance/volatility level measures and dispersion measures. That says the gain is not just a richer autoregressive HAR; it is mainly forward-looking option information about expected variance and volatility disagreement.",
    "- Random Forest puts the strongest importance on the option volatility surface: put 25-delta IV, ATM IV, total implied variance, and call 25-delta IV are almost always among the top variables. The short HAR lag still matters, but the longer HAR lags are much less central in the RF ranking.",
    "- In the stacked combinations, the meta models lean heavily toward option-augmented forecasts, especially PCA HAR+Option, RF HAR+Option, NN HAR+Macro+Option, and several ENET/RF macro-option variants. This is consistent with the main table: the best standalone model is Elastic Net HAR+Option, but combinations also harvest useful signal from nonlinear and dimension-reduction forecasts.",
    "",
    "## Elastic Net HAR+Option Variable Selection",
    "",
    knitr::kable(top_enet, format = "pipe", digits = 5),
    "",
    "## Random Forest HAR+Option Variable Importance",
    "",
    knitr::kable(top_rf, format = "pipe", digits = 5),
    "",
    "## Stacked Forecast Candidate Set",
    "",
    knitr::kable(stacked_candidates_report, format = "pipe"),
    "",
    "## Stacked Elastic Net Selected Forecasts",
    "",
    knitr::kable(top_stacked_enet, format = "pipe", digits = 5),
    "",
    "## Stacked Random Forest Forecast Importance",
    "",
    knitr::kable(top_stacked_rf, format = "pipe", digits = 5)
  ),
  con = md_path
)

cat("Saved interpretation outputs:\n")
cat(" - ", md_path, "\n", sep = "")
cat(" - ", file.path(output_dir, "main_forecast_enet_har_option_selection.csv"), "\n", sep = "")
cat(" - ", file.path(output_dir, "main_forecast_rf_har_option_importance.csv"), "\n", sep = "")
cat(" - ", file.path(output_dir, "main_forecast_stacked_candidate_forecasts.csv"), "\n", sep = "")
cat(" - ", file.path(output_dir, "main_forecast_stacked_enet_selected_forecasts.csv"), "\n", sep = "")
cat(" - ", file.path(output_dir, "main_forecast_stacked_rf_forecast_importance.csv"), "\n", sep = "")
