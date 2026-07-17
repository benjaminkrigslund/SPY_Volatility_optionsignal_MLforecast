fit_har_model <- function(X_train, y_train, config = list(), feature_names = colnames(X_train), feature_blocks = NULL) {
  train_df <- data.frame(y = y_train, X_train, check.names = FALSE)
  stats::setNames(names(train_df), c("y", feature_names))
  names(train_df) <- c("y", feature_names)

  model <- stats::lm(y ~ ., data = train_df)

  list(
    model_type = "har_ols",
    object = model,
    feature_names = feature_names
  )
}

predict_har_model <- function(fitted_model, X_test, config = list()) {
  test_df <- data.frame(X_test, check.names = FALSE)
  names(test_df) <- fitted_model$feature_names
  as.numeric(stats::predict(fitted_model$object, newdata = test_df))
}

extract_har_importance <- function(fitted_model) {
  coef_table <- stats::coef(fitted_model$object)
  coef_table <- coef_table[names(coef_table) != "(Intercept)"]

  data.table::data.table(
    variable = names(coef_table),
    value = unname(coef_table),
    metric = "coefficient"
  )
}
