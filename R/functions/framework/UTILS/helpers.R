`%||%` <- function(x, y) {
  if (is.null(x)) y else x
}

ensure_dir <- function(path) {
  if (!dir.exists(path)) {
    dir.create(path, recursive = TRUE, showWarnings = FALSE)
  }
  invisible(path)
}

build_forecast_id <- function(model_type, feature_set, target_type, window_type) {
  paste(model_type, feature_set, target_type, window_type, sep = "__")
}

transform_target <- function(y, target_type = c("level", "log")) {
  target_type <- match.arg(target_type)
  if (target_type == "log") {
    return(log(y))
  }
  y
}

inverse_target_transform <- function(y_hat, target_type = c("level", "log"), log_resid_var = 0) {
  target_type <- match.arg(target_type)
  if (target_type == "log") {
    return(exp(y_hat + 0.5 * (log_resid_var %||% 0)))
  }
  y_hat
}

enforce_positive_forecast <- function(x, floor_value = 1e-6) {
  pmax(as.numeric(x), floor_value)
}

get_level_forecast_floor <- function(train_actual_level, config) {
  positive_train <- train_actual_level[is.finite(train_actual_level) & train_actual_level > 0]
  base_floor <- config$forecasting$min_positive_forecast %||% 1e-6

  if (length(positive_train) == 0L) {
    return(base_floor)
  }

  train_fraction <- config$forecasting$level_floor_train_fraction %||% 0.5
  max(base_floor, train_fraction * min(positive_train))
}

qlike_loss <- function(actual, forecast, eps = 1e-8) {
  actual_safe <- pmax(actual, eps)
  forecast_safe <- pmax(forecast, eps)
  ratio <- actual_safe / forecast_safe
  ratio - log(ratio) - 1
}

qlike_loss_from_volatility <- function(actual_vol, forecast_vol, eps = 1e-8) {
  qlike_loss(actual_vol ^ 2, forecast_vol ^ 2, eps = eps)
}

fit_standardizer <- function(X) {
  X <- as.matrix(X)
  center <- colMeans(X, na.rm = TRUE)
  scale <- apply(X, 2, stats::sd, na.rm = TRUE)
  scale[is.na(scale) | scale == 0] <- 1

  list(center = center, scale = scale)
}

transform_standardizer <- function(X, preproc) {
  X <- as.matrix(X)
  scaled <- sweep(X, 2, preproc$center, "-")
  sweep(scaled, 2, preproc$scale, "/")
}

make_model_frame <- function(data, config, target_type = c("level", "log")) {
  target_type <- match.arg(target_type)
  data <- data.table::copy(data.table::as.data.table(data))

  date_col <- config$columns$date
  target_col <- config$columns$target
  predictor_cols <- setdiff(names(data), c(date_col, target_col))

  data[, target_date := data.table::shift(get(date_col), type = "lead")]
  data[, target_level := data.table::shift(get(target_col), type = "lead")]
  data[, target_transformed := transform_target(target_level, target_type = target_type)]

  model_data <- data[!is.na(target_level)]
  data.table::setnames(model_data, date_col, "date")
  data.table::setattr(model_data, "predictor_cols", predictor_cols)

  model_data[]
}

get_model_config <- function(model_type, config) {
  switch(
    model_type,
    har_ols = list(),
    enet = config$models$enet,
    pca = config$models$pca,
    pls = config$models$pls,
    rf = config$models$rf,
    nn = config$models$nn,
    stop("Unknown model type: ", model_type)
  )
}

get_min_train_rows <- function(model_type) {
  switch(
    model_type,
    har_ols = 10L,
    enet = 5L,
    pca = 10L,
    pls = 10L,
    rf = 25L,
    nn = 25L,
    10L
  )
}

clean_forecast_table <- function(forecast_df) {
  forecast_dt <- data.table::as.data.table(forecast_df)

  required_cols <- intersect(
    c("forecast_id", "origin_date", "target_date", "model_type", "feature_set", "window_type", "target_type"),
    names(forecast_dt)
  )

  if (length(required_cols) == 0L) {
    return(forecast_dt[0])
  }

  char_cols <- intersect(c("forecast_id", "model_type", "feature_set", "window_type", "target_type"), names(forecast_dt))
  for (col in char_cols) {
    forecast_dt[get(col) == "", (col) := NA_character_]
  }

  forecast_dt[
    stats::complete.cases(forecast_dt[, ..required_cols])
  ]
}
