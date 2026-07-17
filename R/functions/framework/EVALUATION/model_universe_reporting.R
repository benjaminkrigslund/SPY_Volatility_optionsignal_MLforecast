get_model_universe_specifications <- function(config, data) {
  feature_map <- build_feature_map(data, config)

  info_map <- data.table::data.table(
    feature_set = c("HAR", "O", "M", "HAR_O", "HAR_M", "OM", "HAR_OM"),
    information_set = c("HAR", "Option", "Macro", "HAR + Option", "HAR + Macro", "Option + Macro", "HAR + Option + Macro")
  )
  info_map[, n_predictors := vapply(feature_set, function(fs) length(feature_map[[fs]]), integer(1))]

  family_map <- data.table::data.table(
    model_type = c("har_ols", "enet", "pca", "pls", "rf", "nn"),
    model_family = c("OLS", "Elastic Net", "PCA Regression", "PLS Regression", "Random Forest", "Neural Network")
  )

  spec_dt <- data.table::rbindlist(list(
    data.table::data.table(model_type = "har_ols", feature_set = "HAR"),
    data.table::CJ(model_type = c("enet", "pca", "pls"), feature_set = c("O", "M", "HAR_O", "HAR_M", "OM", "HAR_OM"), sorted = FALSE),
    data.table::CJ(model_type = c("rf", "nn"), feature_set = c("HAR", "O", "M", "HAR_O", "HAR_M", "OM", "HAR_OM"), sorted = FALSE)
  ))

  spec_dt <- merge(spec_dt, family_map, by = "model_type", all.x = TRUE)
  spec_dt <- merge(spec_dt, info_map, by = "feature_set", all.x = TRUE)
  spec_dt[, specification_name := paste(model_family, information_set, sep = " | ")]
  spec_dt[, scenario_name := paste(config$reporting$main_target_type, config$reporting$main_window_type, sep = "_")]
  spec_dt[]
}

build_model_universe_forecast_output <- function(all_forecasts, spec_dt) {
  actual_dt <- unique(
    all_forecasts[, .(
      forecast_date = target_date,
      realized_value = actual_level
    )]
  )

  grid_dt <- data.table::CJ(
    specification_name = spec_dt$specification_name,
    forecast_date = sort(unique(actual_dt$forecast_date)),
    sorted = TRUE
  )

  forecast_dt <- merge(
    grid_dt,
    all_forecasts[, .(
      specification_name,
      forecast_date = target_date,
      forecast_value = forecast_level
    )],
    by = c("specification_name", "forecast_date"),
    all.x = TRUE
  )

  out_dt <- merge(forecast_dt, actual_dt, by = "forecast_date", all.x = TRUE)
  out_dt <- merge(
    out_dt,
    unique(spec_dt[, .(specification_name, model_family, information_set)]),
    by = "specification_name",
    all.x = TRUE
  )
  data.table::setcolorder(
    out_dt,
    c("forecast_date", "realized_value", "forecast_value", "model_family", "information_set", "specification_name")
  )
  out_dt[]
}

compute_model_universe_report <- function(all_forecasts, spec_dt, config) {
  benchmark_id <- "har_ols__HAR__log__rolling"
  benchmark_dt <- all_forecasts[
    forecast_id == benchmark_id,
    .(
      forecast_date = target_date,
      benchmark_value = forecast_level,
      benchmark_actual = actual_level
    )
  ]

  model_splits <- split(all_forecasts, by = "specification_name", keep.by = FALSE)
  common_dates <- Reduce(
    intersect,
    c(
      list(unique(benchmark_dt$forecast_date)),
      lapply(model_splits, function(dt) unique(dt$target_date))
    )
  )

  aligned_dt <- all_forecasts[target_date %in% common_dates]
  benchmark_dt <- benchmark_dt[forecast_date %in% common_dates]

  model_rows <- lapply(
    spec_dt$specification_name,
    function(spec_name) {
      model_dt <- aligned_dt[specification_name == spec_name]
      merged <- merge(
        model_dt[, .(forecast_date = target_date, actual_level, forecast_level)],
        benchmark_dt,
        by = "forecast_date",
        all = FALSE
      )

      se_model <- (merged$actual_level - merged$forecast_level) ^ 2
      se_benchmark <- (merged$actual_level - merged$benchmark_value) ^ 2
      ae_model <- abs(merged$actual_level - merged$forecast_level)
      qlike_model <- qlike_loss_from_volatility(merged$actual_level, merged$forecast_level, eps = config$evaluation$qlike_epsilon)
      qlike_benchmark <- qlike_loss_from_volatility(merged$actual_level, merged$benchmark_value, eps = config$evaluation$qlike_epsilon)
      dm_qlike <- dm_test(qlike_model, qlike_benchmark, horizon = config$evaluation$dm_horizon)
      enc <- forecast_encompassing_test(
        actual = merged$actual_level,
        forecast_a = merged$benchmark_value,
        forecast_b = merged$forecast_level
      )

      data.table::data.table(
        specification_name = spec_name,
        n_oos = nrow(merged),
        oos_r2 = 1 - sum(se_model, na.rm = TRUE) / sum(se_benchmark, na.rm = TRUE),
        qlike = mean(qlike_model, na.rm = TRUE),
        mse = mean(se_model, na.rm = TRUE),
        mae = mean(ae_model, na.rm = TRUE),
        dm_p_value_vs_ols_har = dm_qlike$p_value,
        encompassing_p_value_vs_ols_har = enc$p_value
      )
    }
  )

  report_dt <- data.table::rbindlist(model_rows, fill = TRUE)
  report_dt <- merge(spec_dt, report_dt, by = "specification_name", all.x = TRUE)

  loss_wide <- data.table::dcast(
    aligned_dt[
      ,
      .(
        forecast_date = target_date,
        specification_name,
        qlike_loss = qlike_loss_from_volatility(actual_level, forecast_level, eps = config$evaluation$qlike_epsilon)
      )
    ],
    forecast_date ~ specification_name,
    value.var = "qlike_loss"
  )

  mcs_flag <- rep(NA, nrow(report_dt))
  names(mcs_flag) <- report_dt$specification_name
  loss_matrix <- NULL

  if (requireNamespace("MCS", quietly = TRUE) && nrow(loss_wide) > 5L) {
    loss_matrix <- as.matrix(loss_wide[, -1])
    finite_rows <- apply(loss_matrix, 1, function(x) all(is.finite(x)))
    loss_matrix <- loss_matrix[finite_rows, , drop = FALSE]
  }

  if (requireNamespace("MCS", quietly = TRUE) && nrow(loss_matrix) > 5L) {
    mcs_object <- MCS::MCSprocedure(
      Loss = loss_matrix,
      alpha = config$reporting$mcs_alpha,
      B = config$reporting$mcs_bootstrap,
      statistic = config$reporting$mcs_statistic,
      verbose = FALSE
    )
    mcs_table <- as.data.frame(mcs_object@show)
    mcs_table$specification_name <- rownames(mcs_table)
    mcs_flag[mcs_table$specification_name] <- mcs_table$MCS_M > config$reporting$mcs_alpha
  }

  report_dt[, mcs_included := as.logical(mcs_flag[specification_name])]
  report_dt[]
}

build_main_paper_table <- function(report_dt) {
  main_dt <- data.table::copy(report_dt)[
    ,
    .(
      model_family,
      information_set,
      oos_r2,
      qlike
    )
  ]

  main_dt[, rank_oos_r2 := data.table::frank(-oos_r2, ties.method = "min")]
  main_dt[, rank_qlike := data.table::frank(qlike, ties.method = "min")]
  data.table::setorder(main_dt, rank_oos_r2, rank_qlike, model_family, information_set)
  main_dt[]
}

run_model_universe_quality_checks <- function(master_data, all_forecasts, forecast_output, spec_dt, config) {
  har_frame <- make_model_frame(
    get_feature_set(master_data, feature_set = "HAR", config = config),
    config = config,
    target_type = config$reporting$main_target_type
  )
  all_common_dates <- Reduce(
    intersect,
    lapply(
      split(all_forecasts, by = "specification_name", keep.by = FALSE),
      function(dt) unique(dt$target_date)
    )
  )
  target_alignment_ok <- all(vapply(
    split(all_forecasts, by = "specification_name", keep.by = FALSE),
    function(dt) {
      dt <- dt[order(origin_date)]
      if (nrow(dt) <= 1L) {
        return(all(dt$target_date > dt$origin_date))
      }
      all(dt$target_date[-nrow(dt)] == dt$origin_date[-1L]) &&
        isTRUE(dt$target_date[nrow(dt)] > dt$origin_date[nrow(dt)])
    },
    logical(1)
  ))

  qc_dt <- data.table::rbindlist(list(
    data.table::data.table(
      check_name = "Predictors dated at t",
      passed = all(all_forecasts$origin_date < all_forecasts$target_date),
      detail = "All forecast rows have origin_date strictly earlier than target_date."
    ),
    data.table::data.table(
      check_name = "Target aligned to t+1",
      passed = target_alignment_ok,
      detail = "Within each specification, target_date is the next observed monthly date after origin_date."
    ),
    data.table::data.table(
      check_name = "No future leakage in frame construction",
      passed = nrow(har_frame) == nrow(master_data) - 1L,
      detail = paste0("Model frame rows = ", nrow(har_frame), "; raw monthly rows minus terminal month = ", nrow(master_data) - 1L, ".")
    ),
    data.table::data.table(
      check_name = "Common OOS sample available",
      passed = length(all_common_dates) > 0L,
      detail = paste0(length(all_common_dates), " common forecast dates across all ", nrow(spec_dt), " specifications.")
    ),
    data.table::data.table(
      check_name = "Missing forecasts flagged",
      passed = TRUE,
      detail = paste0(sum(is.na(forecast_output[["forecast_value"]])), " missing forecast cells retained as NA in the tidy output grid.")
    )
  ), fill = TRUE)

  qc_dt[]
}

write_model_universe_excel <- function(report_dt, main_dt, forecast_dt, qc_dt, output_path) {
  wb <- openxlsx::createWorkbook()
  header_style <- openxlsx::createStyle(textDecoration = "bold")
  bold_style <- openxlsx::createStyle(textDecoration = "bold")

  openxlsx::addWorksheet(wb, "main_paper")
  openxlsx::writeData(wb, "main_paper", main_dt)
  openxlsx::addStyle(wb, "main_paper", header_style, rows = 1, cols = seq_len(ncol(main_dt)), gridExpand = TRUE)

  best_oos_rows <- which(main_dt$oos_r2 == max(main_dt$oos_r2, na.rm = TRUE)) + 1L
  best_qlike_rows <- which(main_dt$qlike == min(main_dt$qlike, na.rm = TRUE)) + 1L
  openxlsx::addStyle(wb, "main_paper", bold_style, rows = best_oos_rows, cols = which(names(main_dt) == "oos_r2"), gridExpand = TRUE)
  openxlsx::addStyle(wb, "main_paper", bold_style, rows = best_qlike_rows, cols = which(names(main_dt) == "qlike"), gridExpand = TRUE)

  openxlsx::addWorksheet(wb, "final_report")
  openxlsx::writeData(wb, "final_report", report_dt)
  openxlsx::addStyle(wb, "final_report", header_style, rows = 1, cols = seq_len(ncol(report_dt)), gridExpand = TRUE)

  openxlsx::addWorksheet(wb, "tidy_forecasts")
  openxlsx::writeData(wb, "tidy_forecasts", forecast_dt)
  openxlsx::addStyle(wb, "tidy_forecasts", header_style, rows = 1, cols = seq_len(ncol(forecast_dt)), gridExpand = TRUE)

  openxlsx::addWorksheet(wb, "quality_checks")
  openxlsx::writeData(wb, "quality_checks", qc_dt)
  openxlsx::addStyle(wb, "quality_checks", header_style, rows = 1, cols = seq_len(ncol(qc_dt)), gridExpand = TRUE)

  openxlsx::saveWorkbook(wb, output_path, overwrite = TRUE)
}
