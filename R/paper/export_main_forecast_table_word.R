#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(data.table)
  library(flextable)
  library(officer)
})

output_dir <- file.path(getwd(), "output", "tables")
input_path <- file.path(output_dir, "main_forecast_results_table.csv")
dm_qlike_path <- file.path(output_dir, "dm_qlike_rolling120_vs_har.csv")
forecast_panel_path <- file.path(output_dir, "main_forecast_forecast_panel.csv")
dm_se_path <- file.path(output_dir, "dm_squared_error_rolling_windows_vs_har.csv")
output_path <- file.path(output_dir, "main_forecast_results_table_word.docx")
dm_test_path <- file.path("R", "functions", "framework", "EVALUATION", "dm_test.R")

if (!file.exists(input_path)) {
  stop("Missing main forecast table CSV: ", input_path)
}
if (!file.exists(dm_qlike_path)) {
  stop("Missing rolling-120 QLIKE DM-test CSV: ", dm_qlike_path)
}
if (!file.exists(forecast_panel_path)) {
  stop("Missing main forecast panel CSV: ", forecast_panel_path)
}
if (!file.exists(dm_test_path)) {
  stop("Missing DM-test helper: ", dm_test_path)
}

table_dt <- fread(input_path)
dm_qlike <- fread(dm_qlike_path)
forecast_panel <- fread(forecast_panel_path)
source(dm_test_path)

strip_model_suffix <- function(x) {
  x <- gsub(" \\(Individual\\)$", "", x)
  x <- gsub(" \\(Info-set EW\\)$", "", x)
  x <- gsub(" \\(Method EW\\)$", "", x)
  x <- gsub(" \\(All EW\\)$", "", x)
  x <- gsub(" \\(Stacked\\)$", "", x)
  x
}

extract_forecast_type <- function(x) {
  fifelse(
    grepl(" \\(Individual\\)$", x), "individual",
    fifelse(
      grepl(" \\(Info-set EW\\)$", x), "infoset_EW",
      fifelse(
        grepl(" \\(Method EW\\)$", x), "method_EW",
        fifelse(
          grepl(" \\(All EW\\)$", x), "all_EW",
          fifelse(grepl(" \\(Stacked\\)$", x), "stacked", NA_character_)
        )
      )
    )
  )
}

table_dt[, forecast_type := extract_forecast_type(model)]
table_dt[, model := strip_model_suffix(model)]

star_from_one_sided_p <- function(gain, p_value) {
  data.table::fifelse(
    is.finite(gain) & gain > 0 & is.finite(p_value) & p_value < 0.05,
    "**",
    data.table::fifelse(
      is.finite(gain) & gain > 0 & is.finite(p_value) & p_value < 0.10,
      "*",
      ""
    )
  )
}

compute_squared_error_dm <- function(panel, window_months) {
  har_id <- "har_ols__HAR__log__rolling"
  har_dt <- panel[
    rolling_window_months == window_months &
      forecast_id == har_id &
      forecast_type == "individual",
    .(target_date, har_forecast_vol = forecast_value_rv)
  ]

  model_meta <- unique(panel[
    rolling_window_months == window_months &
      !is.na(forecast_id),
    .(forecast_id, model, information_set, forecast_type)
  ])
  model_meta <- model_meta[forecast_id != har_id]

  data.table::rbindlist(lapply(seq_len(nrow(model_meta)), function(i) {
    meta <- model_meta[i]
    model_dt <- panel[
      rolling_window_months == window_months &
        forecast_id == meta$forecast_id,
      .(
        target_date,
        actual_vol = realized_value_rv,
        model_forecast_vol = forecast_value_rv
      )
    ]
    dt <- merge(model_dt, har_dt, by = "target_date", all = FALSE)
    dt <- dt[
      is.finite(actual_vol) &
        is.finite(model_forecast_vol) &
        is.finite(har_forecast_vol)
    ]

    if (nrow(dt) == 0L) {
      return(NULL)
    }

    dt[, `:=`(
      se_model = (actual_vol - model_forecast_vol) ^ 2,
      se_har = (actual_vol - har_forecast_vol) ^ 2
    )]
    test <- dm_test(dt$se_model, dt$se_har, horizon = 1L)
    one_sided_p <- if (is.finite(test$statistic) && test$statistic < 0) {
      test$p_value / 2
    } else if (is.finite(test$statistic)) {
      1 - test$p_value / 2
    } else {
      NA_real_
    }

    data.table::data.table(
      rolling_window_months = window_months,
      forecast_id = meta$forecast_id,
      model = meta$model,
      information_set = meta$information_set,
      forecast_type = meta$forecast_type,
      n = nrow(dt),
      squared_error_gain_vs_har = mean(dt$se_har) - mean(dt$se_model),
      dm_stat_model_minus_har = test$statistic,
      dm_p_two_sided = test$p_value,
      dm_p_one_sided_model_better = one_sided_p
    )
  }), fill = TRUE)
}

dm_se <- data.table::rbindlist(
  lapply(c(60L, 120L, 180L), function(window_months) {
    compute_squared_error_dm(forecast_panel, window_months)
  }),
  fill = TRUE
)
dm_se[, se_dm_sig := star_from_one_sided_p(
  squared_error_gain_vs_har,
  dm_p_one_sided_model_better
)]
fwrite(dm_se, dm_se_path)

dm_qlike[, qlike_dm_sig := star_from_one_sided_p(
  qlike_gain_vs_har,
  dm_p_one_sided_model_better
)]
dm_qlike <- unique(dm_qlike[, .(
  model,
  information_set,
  forecast_type,
  qlike_dm_sig
)])

dm_se_120 <- unique(dm_se[rolling_window_months == 120L, .(
  model,
  information_set,
  forecast_type,
  se_dm_sig_120 = se_dm_sig
)])
dm_se_60 <- unique(dm_se[rolling_window_months == 60L, .(
  model,
  information_set,
  forecast_type,
  se_dm_sig_60 = se_dm_sig
)])
dm_se_180 <- unique(dm_se[rolling_window_months == 180L, .(
  model,
  information_set,
  forecast_type,
  se_dm_sig_180 = se_dm_sig
)])

table_dt <- merge(
  table_dt,
  dm_qlike,
  by = c("model", "information_set", "forecast_type"),
  all.x = TRUE,
  sort = FALSE
)
table_dt <- merge(
  table_dt,
  dm_se_120,
  by = c("model", "information_set", "forecast_type"),
  all.x = TRUE,
  sort = FALSE
)
table_dt <- merge(
  table_dt,
  dm_se_60,
  by = c("model", "information_set", "forecast_type"),
  all.x = TRUE,
  sort = FALSE
)
table_dt <- merge(
  table_dt,
  dm_se_180,
  by = c("model", "information_set", "forecast_type"),
  all.x = TRUE,
  sort = FALSE
)
for (sig_col in c("qlike_dm_sig", "se_dm_sig_120", "se_dm_sig_60", "se_dm_sig_180")) {
  table_dt[is.na(get(sig_col)), (sig_col) := ""]
}
table_dt[, rmse_gain_vs_har := paste0(sprintf("%.3f", rmse_gain_vs_har), se_dm_sig_120)]
table_dt[, r2_oos_vs_har := paste0(sprintf("%.3f", r2_oos_vs_har), se_dm_sig_120)]
table_dt[, qlike_gain_vs_har := paste0(sprintf("%.3f", qlike_gain_vs_har), qlike_dm_sig)]
table_dt[, r2_oos_60_vs_har := paste0(sprintf("%.3f", r2_oos_60_vs_har), se_dm_sig_60)]
table_dt[, r2_oos_180_vs_har := paste0(sprintf("%.3f", r2_oos_180_vs_har), se_dm_sig_180)]
table_dt[, c(
  "forecast_type",
  "qlike_dm_sig",
  "se_dm_sig_120",
  "se_dm_sig_60",
  "se_dm_sig_180"
) := NULL]

display_names <- c(
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

setnames(table_dt, names(display_names), unname(display_names))

ft <- flextable(table_dt)
ft <- theme_booktabs(ft)
ft <- font(ft, fontname = "Arial", part = "all")
ft <- fontsize(ft, size = 7.2, part = "all")
ft <- fontsize(ft, size = 7, part = "header")
ft <- bold(ft, part = "header")
ft <- align(ft, align = "center", part = "header")
ft <- align(ft, j = c("Model", "Info set"), align = "left", part = "body")
ft <- align(ft, j = setdiff(names(table_dt), c("Model", "Info set")), align = "right", part = "body")
ft <- padding(ft, padding = 1, part = "all")
ft <- valign(ft, valign = "center", part = "all")
ft <- line_spacing(ft, space = 1, part = "all")
ft <- height_all(ft, height = 0.17)
ft <- width(
  ft,
  j = c(
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
  width = c(0.45, 0.55, 1.65, 0.30, 0.95, 0.36, 0.70, 0.60, 0.70, 0.55, 0.55)
)
ft <- set_table_properties(ft, layout = "fixed", width = 1)
ft <- fit_to_width(ft, max_width = 7.75)

notes <- paste(
  "Notes: rows are sorted by 120-month OOS R2 rank. Gain columns are versus HAR;",
  "positive RMSE gain means lower RMSE than HAR. M is the number of forecasts in a combination.",
  "Stars use one-sided DM tests against OLS HAR: RMSE/R2 columns use squared-error loss for the relevant window;",
  "QLIKE gain uses corrected rolling-120 QLIKE loss. ** p < 0.05, * p < 0.10."
)

doc <- read_docx()
doc <- body_set_default_section(
  doc,
  prop_section(
    page_size = page_size(width = 8.27, height = 11.69, orient = "portrait"),
    page_margins = page_mar(
      top = 0.30,
      bottom = 0.30,
      left = 0.25,
      right = 0.25,
      header = 0.25,
      footer = 0.25
    )
  )
)
doc <- body_add_par(doc, "Main Forecast Results Table", style = "heading 1")
doc <- body_add_flextable(doc, ft)
doc <- body_add_par(doc, notes, style = "Normal")

print(doc, target = output_path)
cat("Saved Word table: ", output_path, "\n", sep = "")
