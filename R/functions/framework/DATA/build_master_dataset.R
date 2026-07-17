source(file.path("R", "functions", "framework", "DATA", "monthly_vol_target_utils.R"))

get_default_macro_feature_map <- function(factor_wide) {
  factor_cols <- setdiff(names(factor_wide), "date")
  stats::setNames(c("mkt_ret", factor_cols), c("macro_mkt_ret", paste0("macro_", factor_cols)))
}

build_monthly_market_series <- function(data_path = file.path("data", "raw")) {
  data.table::fread(file.path(data_path, "(usa)_(mkt)_(monthly)_(vw_cap) 2.csv")) |>
    dplyr::transmute(
      date = as.Date(date),
      mkt_ret = as.numeric(ret)
    ) |>
    dplyr::arrange(date)
}

build_master_dataset <- function(data_path = file.path("data", "raw"),
                                 output_path = file.path("data", "processed", "master_dataset.csv"),
                                 feature_dictionary_path = file.path("data", "processed", "master_feature_dictionary.csv"),
                                 framework_copy_path = file.path("data", "processed", "master_dataset.csv"),
                                 start_date = as.Date("1972-01-31"),
                                 macro_feature_map = NULL,
                                 save_outputs = TRUE) {
  data_path <- paste0(sub("[/\\\\]+$", "", data_path), "/")

  monthly_rv <- build_monthly_spy_5min_vol(
    data_path = data_path,
    month_position = "end"
  ) |>
    dplyr::filter(month >= start_date) |>
    dplyr::arrange(month) |>
    dplyr::transmute(
      date = month,
      rv = realized_vol,
      rv_var = realized_var,
      trading_days = trading_days,
      har_rv_1m = realized_vol,
      har_rv_3m = data.table::frollmean(realized_vol, n = 3, align = "right"),
      har_rv_12m = data.table::frollmean(realized_vol, n = 12, align = "right")
    )

  monthly_option <- build_monthly_option_signals(
    data_path = data_path,
    realized_vol_data = build_monthly_spy_5min_vol(
      data_path = data_path,
      month_position = "end"
    ),
    lag_predictors = FALSE
  ) |>
    dplyr::filter(month >= start_date) |>
    dplyr::select(
      month,
      dplyr::all_of(get_option_signal_names())
    ) |>
    dplyr::rename(date = month) |>
    dplyr::arrange(date)

  factor_wide <- build_monthly_factor_matrix(
    data_path = data_path,
    start_date = start_date,
    lag_predictors = FALSE
  )

  market_series <- build_monthly_market_series(data_path = data_path) |>
    dplyr::filter(date >= start_date)

  if (is.null(macro_feature_map)) {
    macro_feature_map <- get_default_macro_feature_map(factor_wide)
  }

  macro_source <- factor_wide |>
    dplyr::left_join(market_series, by = "date") |>
    dplyr::arrange(date)

  missing_macro_sources <- setdiff(unname(macro_feature_map), names(macro_source))
  if (length(missing_macro_sources) > 0L) {
    stop(
      "Requested macro source variables are missing from the provided data: ",
      paste(missing_macro_sources, collapse = ", "),
      "\nEdit get_default_macro_feature_map() in build_master_dataset.R if you want a different macro block."
    )
  }

  macro_dt <- macro_source |>
    dplyr::select(date, dplyr::all_of(unname(macro_feature_map)))
  names(macro_dt) <- c("date", names(macro_feature_map))

  master_dt <- monthly_rv |>
    dplyr::left_join(monthly_option, by = "date") |>
    dplyr::left_join(macro_dt, by = "date") |>
    dplyr::arrange(date)

  feature_dictionary <- data.table::rbindlist(list(
    data.table::data.table(feature_group = "target", feature_name = "rv", source_name = "realized_vol"),
    data.table::data.table(
      feature_group = "har",
      feature_name = c("har_rv_1m", "har_rv_3m", "har_rv_12m"),
      source_name = c("realized_vol", "3-month mean of realized_vol", "12-month mean of realized_vol")
    ),
    data.table::data.table(
      feature_group = "option",
      feature_name = get_option_signal_names(),
      source_name = get_option_signal_names()
    ),
    data.table::data.table(
      feature_group = "macro",
      feature_name = names(macro_feature_map),
      source_name = unname(macro_feature_map)
    )
  ), fill = TRUE)

  if (isTRUE(save_outputs)) {
    dir.create(dirname(output_path), recursive = TRUE, showWarnings = FALSE)
    dir.create(dirname(framework_copy_path), recursive = TRUE, showWarnings = FALSE)
    dir.create(dirname(feature_dictionary_path), recursive = TRUE, showWarnings = FALSE)

    data.table::fwrite(master_dt, output_path)
    data.table::fwrite(master_dt, framework_copy_path)
    data.table::fwrite(feature_dictionary, feature_dictionary_path)
  }

  list(
    master_data = data.table::as.data.table(master_dt),
    feature_dictionary = feature_dictionary,
    macro_feature_map = macro_feature_map
  )
}
