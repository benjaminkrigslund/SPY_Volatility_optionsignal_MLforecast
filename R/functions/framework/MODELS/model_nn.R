fit_nn_model <- function(X_train, y_train, config = list(), feature_names = colnames(X_train), feature_blocks = NULL) {
  x_preproc <- fit_standardizer(X_train)
  x_scaled <- transform_standardizer(X_train, x_preproc)

  y_center <- mean(y_train)
  y_scale <- stats::sd(y_train)
  if (is.na(y_scale) || y_scale == 0) {
    y_scale <- 1
  }
  y_scaled <- (y_train - y_center) / y_scale

  nn_fit <- nnet::nnet(
    x = x_scaled,
    y = y_scaled,
    size = config$size %||% 5L,
    decay = config$decay %||% 0.01,
    linout = config$linout %||% TRUE,
    trace = config$trace %||% FALSE,
    maxit = config$maxit %||% 500L,
    MaxNWts = config$maxnwts %||% 10000L
  )

  list(
    model_type = "nn",
    object = nn_fit,
    preproc = x_preproc,
    y_center = y_center,
    y_scale = y_scale,
    feature_names = feature_names
  )
}

predict_nn_model <- function(fitted_model, X_test, config = list()) {
  x_scaled <- transform_standardizer(X_test, fitted_model$preproc)
  pred_scaled <- as.numeric(stats::predict(fitted_model$object, x_scaled))
  pred_scaled * fitted_model$y_scale + fitted_model$y_center
}

extract_nn_importance <- function(fitted_model) {
  weights <- fitted_model$object$wts
  data.table::data.table(
    variable = "network_weights",
    value = mean(abs(weights)),
    metric = "mean_absolute_weight"
  )
}
