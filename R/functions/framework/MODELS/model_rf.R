fit_rf_model <- function(X_train, y_train, config = list(), feature_names = colnames(X_train), feature_blocks = NULL) {
  train_df <- data.frame(y = y_train, X_train, check.names = FALSE)
  names(train_df) <- c("y", feature_names)

  mtry <- config$mtry %||% max(1L, floor(sqrt(length(feature_names))))

  rf_fit <- ranger::ranger(
    y ~ .,
    data = train_df,
    num.trees = config$num_trees %||% 500L,
    mtry = mtry,
    min.node.size = config$min_node_size %||% 5L,
    importance = config$importance %||% "impurity",
    write.forest = TRUE,
    seed = config$seed %||% 123
  )

  list(
    model_type = "rf",
    object = rf_fit,
    feature_names = feature_names
  )
}

predict_rf_model <- function(fitted_model, X_test, config = list()) {
  test_df <- data.frame(X_test, check.names = FALSE)
  names(test_df) <- fitted_model$feature_names
  as.numeric(stats::predict(fitted_model$object, data = test_df)$predictions)
}

extract_rf_importance <- function(fitted_model) {
  importance <- fitted_model$object$variable.importance
  if (is.null(importance)) {
    return(data.table::data.table(variable = character(), value = numeric(), metric = character()))
  }

  data.table::data.table(
    variable = names(importance),
    value = as.numeric(importance),
    metric = "variable_importance"
  )
}
