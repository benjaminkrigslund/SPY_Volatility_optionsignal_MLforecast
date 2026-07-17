#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(data.table)
  library(flextable)
  library(officer)
})

output_dir <- file.path(getwd(), "output", "tables")
output_path <- file.path(output_dir, "main_forecast_model_interpretation_word.docx")

required_paths <- c(
  enet = file.path(output_dir, "main_forecast_enet_har_option_selection.csv"),
  rf = file.path(output_dir, "main_forecast_rf_har_option_importance.csv"),
  candidates = file.path(output_dir, "main_forecast_stacked_candidate_forecasts.csv"),
  stacked_enet = file.path(output_dir, "main_forecast_stacked_enet_selected_forecasts.csv"),
  stacked_rf = file.path(output_dir, "main_forecast_stacked_rf_forecast_importance.csv")
)

missing_paths <- required_paths[!file.exists(required_paths)]
if (length(missing_paths) > 0L) {
  stop(
    "Missing interpretation CSVs. Run R/09_create_model_interpretation.R first. Missing: ",
    paste(missing_paths, collapse = ", ")
  )
}

rename_for_word <- function(dt) {
  names(dt) <- gsub("top5", "top_5", names(dt), fixed = TRUE)
  names(dt) <- gsub("_", " ", names(dt), fixed = TRUE)
  names(dt) <- tools::toTitleCase(names(dt))
  dt
}

pretty_text <- function(x) {
  x <- gsub("_", " ", x, fixed = TRUE)
  trimws(gsub("[[:space:]]+", " ", x))
}

pretty_feature_group <- function(x) {
  out <- pretty_text(x)
  fifelse(tolower(out) == "har", "HAR", tools::toTitleCase(out))
}

make_ft <- function(dt, numeric_digits = 5, font_size = 7) {
  dt <- copy(dt)
  ft <- flextable(rename_for_word(dt))
  ft <- theme_booktabs(ft)
  ft <- fontsize(ft, size = font_size, part = "all")
  ft <- bold(ft, part = "header")
  ft <- align(ft, align = "center", part = "header")

  text_cols <- names(dt)[vapply(dt, function(x) is.character(x) || inherits(x, "Date"), logical(1))]
  text_cols <- tools::toTitleCase(gsub("_", " ", text_cols, fixed = TRUE))
  text_cols <- intersect(text_cols, ft$col_keys)
  if (length(text_cols) > 0L) {
    ft <- align(ft, j = text_cols, align = "left", part = "body")
  }

  numeric_cols <- names(dt)[vapply(dt, is.numeric, logical(1))]
  numeric_cols <- tools::toTitleCase(gsub("_", " ", numeric_cols, fixed = TRUE))
  numeric_cols <- intersect(numeric_cols, ft$col_keys)
  if (length(numeric_cols) > 0L) {
    ft <- align(ft, j = numeric_cols, align = "right", part = "body")
    ft <- colformat_num(ft, j = numeric_cols, digits = numeric_digits)
  }

  ft <- autofit(ft)
  set_table_properties(ft, layout = "autofit", width = 1)
}

drop_word_columns <- function(dt, cols) {
  cols <- intersect(cols, names(dt))
  if (length(cols) == 0L) {
    return(dt)
  }
  dt[, (cols) := NULL]
  dt
}

clean_variable_table <- function(dt) {
  dt <- copy(dt)
  if ("variable_label" %in% names(dt)) {
    dt[, variable := pretty_text(variable_label)]
    dt[, variable_label := NULL]
  } else if ("variable" %in% names(dt)) {
    dt[, variable := pretty_text(variable)]
  }
  if ("feature_group" %in% names(dt)) {
    dt[, feature_group := pretty_feature_group(feature_group)]
  }
  setcolorder(dt, c("variable", "feature_group", setdiff(names(dt), c("variable", "feature_group"))))
  dt
}

clean_forecast_table <- function(dt) {
  dt <- copy(dt)
  dt <- drop_word_columns(dt, c(
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

add_table_section <- function(doc, title, dt, max_rows = NULL, note = NULL, font_size = 7) {
  if (!is.null(max_rows)) {
    dt <- dt[seq_len(min(nrow(dt), max_rows))]
  }

  doc <- body_add_par(doc, title, style = "heading 2")
  if (!is.null(note)) {
    doc <- body_add_par(doc, note, style = "Normal")
  }
  doc <- body_add_flextable(doc, make_ft(dt, font_size = font_size))
  body_add_par(doc, "", style = "Normal")
}

enet <- fread(required_paths[["enet"]])
rf <- fread(required_paths[["rf"]])
candidates <- fread(required_paths[["candidates"]])
stacked_enet <- fread(required_paths[["stacked_enet"]])
stacked_rf <- fread(required_paths[["stacked_rf"]])

enet <- clean_variable_table(enet)
rf <- clean_variable_table(rf)
candidates <- clean_forecast_table(candidates)
stacked_enet <- clean_forecast_table(stacked_enet)
stacked_rf <- clean_forecast_table(stacked_rf)

doc <- read_docx()
doc <- body_add_par(doc, "Main Forecast Model Interpretation", style = "heading 1")

doc <- body_add_par(doc, "Scope", style = "heading 2")
scope_lines <- c(
  "Individual diagnostics focus on the 120-month rolling log-RV HAR+Option specification.",
  "Elastic Net selection is reported as non-zero coefficient frequency across rolling refits.",
  "Random Forest does not estimate linear coefficients, so the RF table reports impurity importance and top-five frequency.",
  "Stacked forecast diagnostics use the available meta-combination files, filtered to the 16 individual forecasts used in the current main-table stacked forecasts."
)
for (line in scope_lines) {
  doc <- body_add_par(doc, paste0("- ", line), style = "Normal")
}

doc <- body_add_par(doc, "Interpretation Summary", style = "heading 2")
summary_lines <- c(
  "Elastic Net keeps the three HAR lags by construction, but the most persistent option variables are implied variance/volatility level measures and dispersion measures.",
  "Random Forest puts the strongest importance on the option volatility surface: put 25-delta IV, ATM IV, total implied variance, and call 25-delta IV.",
  "The stacked combinations lean toward option-augmented forecasts, especially PCA HAR+Option, RF HAR+Option, NN HAR+Macro+Option, and several ENET/RF macro-option variants."
)
for (line in summary_lines) {
  doc <- body_add_par(doc, paste0("- ", line), style = "Normal")
}

doc <- add_table_section(
  doc,
  "Elastic Net HAR+Option Variable Selection",
  enet,
  max_rows = 12L,
  note = "Top variables by selection rate, then mean absolute coefficient."
)

doc <- add_table_section(
  doc,
  "Random Forest HAR+Option Variable Importance",
  rf,
  max_rows = 12L,
  note = "Top variables by top-five frequency within each refit, then mean rank."
)

doc <- add_table_section(
  doc,
  "Stacked Forecast Candidate Set",
  candidates,
  note = "The 16 individual forecasts used by the current main-table stacked forecasts.",
  font_size = 8
)

doc <- add_table_section(
  doc,
  "Stacked Elastic Net Selected Forecasts",
  stacked_enet,
  max_rows = 16L,
  note = "Individual forecasts with non-zero stacked ENET coefficients."
)

doc <- add_table_section(
  doc,
  "Stacked Random Forest Forecast Importance",
  stacked_rf,
  max_rows = 16L,
  note = "Individual forecast importance in the stacked RF meta model."
)

doc <- body_end_section_landscape(doc)
print(doc, target = output_path)

cat("Saved Word interpretation table: ", output_path, "\n", sep = "")
