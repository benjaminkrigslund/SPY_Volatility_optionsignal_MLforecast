#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(data.table)
  library(flextable)
  library(officer)
})

output_dir <- file.path(getwd(), "output", "tables")
input_path <- file.path(output_dir, "encompassing_rolling120_vs_har.csv")
output_path <- file.path(output_dir, "encompassing_rolling120_models_add_info_vs_har.docx")

if (!file.exists(input_path)) {
  stop("Missing encompassing-test CSV: ", input_path)
}

res <- fread(input_path)
res[, adds_info_5pct := model_p_given_har < 0.05]
res[, adds_info_10pct := model_p_given_har < 0.10]
res[, p_missing := is.na(model_p_given_har)]
setorder(res, p_missing, model_p_given_har, -r2_oos_vs_har)
res[, p_missing := NULL]

display_type <- c(
  individual = "Individual",
  method_EW = "Method EW",
  infoset_EW = "Info-set EW",
  all_EW = "All EW",
  stacked = "Stacked"
)

prep_table <- function(dt, include_har_p = TRUE) {
  dt <- copy(dt)
  dt[, forecast_type := unname(display_type[forecast_type])]
  dt[is.na(forecast_type), forecast_type := ""]

  keep <- c(
    "model", "information_set", "forecast_type", "n",
    "model_coef_given_har", "model_p_given_har",
    "har_p_given_model", "r2_oos_vs_har", "qlike_gain_vs_har"
  )
  if (!isTRUE(include_har_p)) {
    keep <- setdiff(keep, "har_p_given_model")
  }
  dt <- dt[, ..keep]

  names(dt) <- c(
    "Model", "Info set", "Type", "N",
    "Beta model", "p(model | HAR)",
    if (isTRUE(include_har_p)) "p(HAR | model)" else NULL,
    "R2 OOS", "QLIKE gain"
  )
  dt[]
}

make_ft <- function(dt, font_size = 7.4) {
  ft <- flextable(dt)
  ft <- theme_booktabs(ft)
  ft <- font(ft, fontname = "Arial", part = "all")
  ft <- fontsize(ft, size = font_size, part = "all")
  ft <- fontsize(ft, size = font_size, part = "header")
  ft <- bold(ft, part = "header")
  ft <- align(ft, align = "center", part = "header")
  ft <- align(ft, j = c("Model", "Info set", "Type"), align = "left", part = "body")
  numeric_cols <- setdiff(names(dt), c("Model", "Info set", "Type"))
  ft <- align(ft, j = numeric_cols, align = "right", part = "body")
  ft <- colformat_num(
    ft,
    j = intersect(c("Beta model", "R2 OOS", "QLIKE gain"), names(dt)),
    digits = 4
  )
  ft <- colformat_num(
    ft,
    j = intersect(c("p(model | HAR)", "p(HAR | model)"), names(dt)),
    digits = 4
  )
  ft <- padding(ft, padding = 1, part = "all")
  ft <- valign(ft, valign = "center", part = "all")
  ft <- line_spacing(ft, space = 1, part = "all")
  ft <- set_table_properties(ft, layout = "autofit", width = 1)
  autofit(ft)
}

add_bullets <- function(doc, bullets) {
  for (line in bullets) {
    doc <- body_add_par(doc, paste0("- ", line), style = "Normal")
  }
  doc
}

add_table_section <- function(doc, title, dt, note = NULL, font_size = 7.4) {
  doc <- body_add_par(doc, title, style = "heading 2")
  if (!is.null(note)) {
    doc <- body_add_par(doc, note, style = "Normal")
  }
  doc <- body_add_flextable(doc, make_ft(dt, font_size = font_size))
  body_add_par(doc, "", style = "Normal")
}

adds_5 <- prep_table(res[adds_info_5pct == TRUE])
not_5 <- prep_table(res[is.na(adds_info_5pct) | adds_info_5pct == FALSE])

top_rows <- prep_table(res[adds_info_5pct == TRUE][seq_len(min(.N, 8L))])

key_model <- res[model == "Elastic Net" & information_set == "HAR+Option" & forecast_type == "individual"]
headline <- c(
  paste0(
    "At the 5% level, ", nrow(adds_5), " of ", nrow(res),
    " tested rolling-120 models add information beyond OLS HAR."
  ),
  paste0(
    "At the 10% level, ", res[adds_info_10pct == TRUE, .N], " of ", nrow(res),
    " tested rolling-120 models add information beyond OLS HAR."
  )
)
if (nrow(key_model) == 1L) {
  headline <- c(
    headline,
    paste0(
      "Elastic Net HAR+Option is the strongest case: beta_model p = ",
      formatC(key_model$model_p_given_har, format = "e", digits = 2),
      ", R2 OOS = ", sprintf("%.4f", key_model$r2_oos_vs_har),
      ", QLIKE gain = ", sprintf("%.4f", key_model$qlike_gain_vs_har), "."
    ),
    paste0(
      "For Elastic Net HAR+Option, HAR is not significant once the model forecast is included: p(HAR | model) = ",
      sprintf("%.4f", key_model$har_p_given_model), "."
    )
  )
}

doc <- read_docx()
doc <- body_set_default_section(
  doc,
  prop_section(
    page_size = page_size(width = 11.69, height = 8.27, orient = "landscape"),
    page_margins = page_mar(
      top = 0.35,
      bottom = 0.35,
      left = 0.35,
      right = 0.35,
      header = 0.25,
      footer = 0.25
    )
  )
)

doc <- body_add_par(doc, "Forecast Encompassing Tests vs OLS HAR", style = "heading 1")
doc <- body_add_par(doc, "Rolling-120 common sample", style = "heading 2")
doc <- add_bullets(doc, headline)

doc <- body_add_par(doc, "Test Specification", style = "heading 2")
doc <- add_bullets(doc, c(
  "Regression: actual volatility = alpha + beta_HAR * HAR forecast + beta_model * model forecast + error.",
  "The reported p(model | HAR) tests whether the model forecast adds information beyond the OLS HAR benchmark.",
  "The reported p(HAR | model) tests whether HAR still adds information after the model forecast is included."
))

doc <- add_table_section(
  doc,
  "Strongest Encompassing Results",
  top_rows,
  note = "Top rows sorted by p(model | HAR), with lower p-values indicating stronger incremental information.",
  font_size = 8
)

doc <- add_table_section(
  doc,
  "Models Adding Information Beyond HAR at 5%",
  adds_5,
  note = "Rows satisfy p(model | HAR) < 0.05.",
  font_size = 6.8
)

doc <- add_table_section(
  doc,
  "Models Not Adding Information Beyond HAR at 5%",
  not_5,
  note = "Rows do not satisfy p(model | HAR) < 0.05. PCA/HAR is collinear with the HAR benchmark in this panel, so its model coefficient is undefined.",
  font_size = 8
)

doc <- body_add_par(
  doc,
  "Note: this is the project's simple OLS encompassing regression and is not HAC-adjusted.",
  style = "Normal"
)

print(doc, target = output_path)
cat("Saved Word document: ", output_path, "\n", sep = "")
