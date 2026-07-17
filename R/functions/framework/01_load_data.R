load_master_data <- function(config) {
  data_path <- config$paths$master_data

  if (!file.exists(data_path)) {
    stop(
      "Master dataset not found at: ", data_path, "\n",
      "Create a single monthly dataset with date, target RV, HAR, option, and macro columns, ",
      "then update config$paths$master_data if needed."
    )
  }

  data <- data.table::fread(data_path)
  data <- data.table::as.data.table(data)

  date_col <- config$columns$date
  if (!date_col %in% names(data)) {
    stop("Date column '", date_col, "' not found in master dataset.")
  }

  if (!inherits(data[[date_col]], "Date")) {
    data[, (date_col) := as.Date(get(date_col))]
  }

  data.table::setorderv(data, date_col)

  required_cols <- unique(c(
    config$columns$date,
    config$columns$target,
    config$columns$har,
    config$columns$option,
    config$columns$macro
  ))
  required_cols <- required_cols[!is.null(required_cols)]

  missing_cols <- setdiff(required_cols, names(data))
  if (length(missing_cols) > 0L) {
    stop(
      "The master dataset is missing required columns: ",
      paste(missing_cols, collapse = ", "),
      "\nUpdate 00_config.R so the column lists match your data."
    )
  }

  data[]
}
