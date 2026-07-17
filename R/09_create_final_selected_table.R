#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(data.table)
  library(knitr)
})

output_dir <- file.path(getwd(), "output", "tables")
input_path <- file.path(output_dir, "main_forecast_results_table.csv")

csv_path <- file.path(output_dir, "main_forecast_results_table_final_selected.csv")
md_path <- file.path(output_dir, "main_forecast_results_table_final_selected.md")
tex_path <- file.path(output_dir, "main_forecast_results_table_final_selected.tex")
docx_path <- file.path(output_dir, "main_forecast_results_table_final_selected_word.docx")

if (!file.exists(input_path)) {
  stop("Missing main forecast table CSV: ", input_path)
}

main_table <- fread(input_path)

pick_best <- function(dt, selection, condition) {
  candidates <- dt[condition]
  if (nrow(candidates) == 0L) {
    stop("No row found for selection: ", selection)
  }
  out <- candidates[order(rank_r2_oos, rank_qlike)][1]
  out[, selection := selection]
  out
}

strip_model_suffix <- function(x) {
  x <- gsub(" \\(Individual\\)$", "", x)
  x <- gsub(" \\(Info-set EW\\)$", "", x)
  x <- gsub(" \\(Method EW\\)$", "", x)
  x <- gsub(" \\(All EW\\)$", "", x)
  x <- gsub(" \\(Stacked\\)$", "", x)
  x
}

is_individual <- grepl(" (Individual)", main_table$model, fixed = TRUE)
is_benchmark <- main_table$model == "OLS HAR (Individual)" & main_table$information_set == "HAR"
is_ml_individual <- is_individual & !is_benchmark

selected <- rbindlist(list(
  pick_best(
    main_table,
    "HAR benchmark",
    is_benchmark
  ),
  pick_best(
    main_table,
    "Best HAR-only ML model",
    is_ml_individual & main_table$information_set == "HAR"
  ),
  pick_best(
    main_table,
    "Best HAR + Option model",
    is_ml_individual & main_table$information_set == "HAR+Option"
  ),
  pick_best(
    main_table,
    "Best HAR + Macro model",
    is_ml_individual & main_table$information_set == "HAR+Macro"
  ),
  pick_best(
    main_table,
    "Best HAR + Macro + Option model",
    is_ml_individual & main_table$information_set == "HAR+Macro+Option"
  ),
  pick_best(
    main_table,
    "Best information-set equal weight",
    grepl(" (Info-set EW)", main_table$model, fixed = TRUE)
  ),
  pick_best(
    main_table,
    "Best method equal weight",
    grepl(" (Method EW)", main_table$model, fixed = TRUE)
  ),
  pick_best(
    main_table,
    "All-ML equal weight",
    main_table$model == "Equal Weight (All EW)"
  ),
  pick_best(
    main_table,
    "Stacked Elastic Net",
    main_table$model == "Stacked Elastic Net (Stacked)"
  ),
  pick_best(
    main_table,
    "Stacked Random Forest",
    main_table$model == "Stacked Random Forest (Stacked)"
  )
), fill = TRUE)

selected[, model := strip_model_suffix(model)]

setcolorder(selected, c(
  "selection",
  "rank_r2_oos",
  "rank_qlike",
  "model",
  "members",
  "information_set",
  "n_oos",
  "rmse_gain_vs_har",
  "r2_oos_vs_har",
  "qlike_gain_vs_har",
  "r2_oos_60_vs_har",
  "r2_oos_180_vs_har"
))

selected <- selected[, .(
  selection,
  rank_r2_oos,
  rank_qlike,
  model,
  members,
  information_set,
  n_oos,
  rmse_gain_vs_har,
  r2_oos_vs_har,
  qlike_gain_vs_har,
  r2_oos_60_vs_har,
  r2_oos_180_vs_har
)]

setorder(selected, rank_r2_oos, rank_qlike, selection)

numeric_cols <- c(
  "rmse_gain_vs_har",
  "r2_oos_vs_har",
  "qlike_gain_vs_har",
  "r2_oos_60_vs_har",
  "r2_oos_180_vs_har"
)
selected[, (numeric_cols) := lapply(.SD, round, digits = 5), .SDcols = numeric_cols]

fwrite(selected, csv_path)

heading_lines <- c(
  "# Main Forecast Results Table: Final Selected Rows",
  "",
  "Selection rule:",
  "- Rows are selected from the existing main forecast table.",
  "- Best rows are chosen by the main table's 120-month OOS R2 rank, with QLIKE rank as the tie-breaker.",
  "- The table is sorted by 120-month OOS R2 rank."
)

writeLines(
  c(
    heading_lines,
    "",
    knitr::kable(as.data.frame(selected), format = "pipe", digits = 5)
  ),
  con = md_path
)

writeLines(
  knitr::kable(
    as.data.frame(selected),
    format = "latex",
    booktabs = TRUE,
    longtable = FALSE,
    digits = 5
  ),
  con = tex_path
)

if (requireNamespace("flextable", quietly = TRUE) &&
    requireNamespace("officer", quietly = TRUE)) {
  display_dt <- copy(selected)
  display_dt[, selection := fcase(
    selection == "Best HAR-only ML model", "Best HAR-only ML",
    selection == "Best HAR + Option model", "Best HAR+Option",
    selection == "Best HAR + Macro model", "Best HAR+Macro",
    selection == "Best HAR + Macro + Option model", "Best HAR+Macro+Option",
    selection == "Best information-set equal weight", "Best info-set EW",
    selection == "Best method equal weight", "Best method EW",
    selection == "All-ML equal weight", "All-ML EW",
    default = selection
  )]
  display_names <- c(
    selection = "Selected row",
    rank_r2_oos = "R2 rank",
    rank_qlike = "QLIKE rank",
    model = "Model",
    members = "M",
    information_set = "Info set",
    n_oos = "N",
    rmse_gain_vs_har = "RMSE gain",
    r2_oos_vs_har = "R2 OOS",
    qlike_gain_vs_har = "QLIKE gain",
    r2_oos_60_vs_har = "R2 60m",
    r2_oos_180_vs_har = "R2 180m"
  )
  setnames(display_dt, names(display_names), unname(display_names))

  ft <- flextable::flextable(display_dt)
  ft <- flextable::theme_booktabs(ft)
  ft <- flextable::font(ft, fontname = "Arial", part = "all")
  ft <- flextable::fontsize(ft, size = 6.5, part = "all")
  ft <- flextable::fontsize(ft, size = 6.2, part = "header")
  ft <- flextable::bold(ft, part = "header")
  ft <- flextable::align(ft, align = "center", part = "header")
  ft <- flextable::align(
    ft,
    j = c("Selected row", "Model", "Info set"),
    align = "left",
    part = "body"
  )
  ft <- flextable::align(
    ft,
    j = setdiff(names(display_dt), c("Selected row", "Model", "Info set")),
    align = "right",
    part = "body"
  )
  ft <- flextable::colformat_num(
    ft,
    j = c(
      "RMSE gain",
      "R2 OOS",
      "QLIKE gain",
      "R2 60m",
      "R2 180m"
    ),
    digits = 5
  )
  ft <- flextable::padding(ft, padding = 1.2, part = "all")
  ft <- flextable::valign(ft, valign = "center", part = "all")
  ft <- flextable::line_spacing(ft, space = 1, part = "all")
  ft <- flextable::width(
    ft,
    j = c(
      "Selected row",
      "R2 rank",
      "QLIKE rank",
      "Model",
      "M",
      "Info set",
      "N",
      "RMSE gain",
      "R2 OOS",
      "QLIKE gain",
      "R2 60m",
      "R2 180m"
    ),
    width = c(1.18, 0.35, 0.43, 0.82, 0.24, 0.77, 0.30, 0.55, 0.48, 0.55, 0.45, 0.45)
  )
  ft <- flextable::set_table_properties(ft, layout = "fixed", width = 1)
  ft <- flextable::fit_to_width(ft, max_width = 7.2)

  notes <- paste(
    "Notes: selected from the existing main forecast table and sorted by 120-month",
    "OOS R2 rank. Gain columns are versus HAR; positive RMSE gain means lower RMSE",
    "than HAR. M is the number of forecasts in a combination."
  )

  doc <- officer::read_docx()
  doc <- officer::body_set_default_section(
    doc,
    officer::prop_section(
      page_size = officer::page_size(width = 8.27, height = 11.69, orient = "portrait"),
      page_margins = officer::page_mar(
        top = 0.45,
        bottom = 0.45,
        left = 0.45,
        right = 0.45,
        header = 0.25,
        footer = 0.25
      )
    )
  )
  doc <- officer::body_add_par(doc, "Main Forecast Results Table: Final Selected Rows", style = "heading 1")
  doc <- flextable::body_add_flextable(doc, ft)
  doc <- officer::body_add_par(doc, notes, style = "Normal")
  print(doc, target = docx_path)
}

cat("Saved selected final main forecast table:\n")
cat(" - ", csv_path, "\n", sep = "")
cat(" - ", md_path, "\n", sep = "")
cat(" - ", tex_path, "\n", sep = "")
if (file.exists(docx_path)) {
  cat(" - ", docx_path, "\n", sep = "")
}
