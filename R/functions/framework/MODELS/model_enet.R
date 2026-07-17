fit_enet_model <- function(X_train, y_train, config = list(), feature_names = colnames(X_train), feature_blocks = NULL) {
  preproc <- fit_standardizer(X_train)
  x_scaled <- transform_standardizer(X_train, preproc)

  nfolds <- min(config$nfolds %||% 10L, nrow(x_scaled))
  if (nfolds < 3L) {
    stop("Elastic Net requires at least 3 training observations for cross-validation.")
  }

  always_include <- intersect(config$always_include %||% character(), feature_names)
  penalty_factor <- ifelse(feature_names %in% always_include, 0, 1)

  glmnet_args <- list(
    x = x_scaled,
    y = y_train,
    alpha = config$alpha %||% 0.5,
    nfolds = nfolds
  )

  if (any(penalty_factor > 0)) {
    glmnet_args$penalty.factor <- penalty_factor
  }

  cv_fit <- do.call(glmnet::cv.glmnet, glmnet_args)

  list(
    model_type = "enet",
    object = cv_fit,
    preproc = preproc,
    feature_names = feature_names,
    lambda = cv_fit$lambda.min
  )
}

predict_enet_model <- function(fitted_model, X_test, config = list()) {
  x_scaled <- transform_standardizer(X_test, fitted_model$preproc)
  as.numeric(stats::predict(fitted_model$object, newx = x_scaled, s = "lambda.min"))
}

extract_enet_importance <- function(fitted_model) {
  coef_mat <- as.matrix(stats::coef(fitted_model$object, s = "lambda.min"))
  coef_dt <- data.table::data.table(
    variable = rownames(coef_mat),
    value = as.numeric(coef_mat[, 1])
  )

  coef_dt <- coef_dt[variable != "(Intercept)" & abs(value) > 0]
  coef_dt[, metric := "non_zero_coefficient"]
  coef_dt[]
}
