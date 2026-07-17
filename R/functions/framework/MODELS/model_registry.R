fit_model <- function(model_type,
                      X_train,
                      y_train,
                      config,
                      feature_names = colnames(X_train),
                      feature_blocks = NULL) {
  model_type <- match.arg(model_type, c("har_ols", "enet", "pca", "pls", "rf", "nn"))

  switch(
    model_type,
    har_ols = fit_har_model(X_train, y_train, config = config, feature_names = feature_names, feature_blocks = feature_blocks),
    enet = fit_enet_model(X_train, y_train, config = config, feature_names = feature_names, feature_blocks = feature_blocks),
    pca = fit_pca_model(X_train, y_train, config = config, feature_names = feature_names, feature_blocks = feature_blocks),
    pls = fit_pls_model(X_train, y_train, config = config, feature_names = feature_names, feature_blocks = feature_blocks),
    rf = fit_rf_model(X_train, y_train, config = config, feature_names = feature_names, feature_blocks = feature_blocks),
    nn = fit_nn_model(X_train, y_train, config = config, feature_names = feature_names, feature_blocks = feature_blocks)
  )
}

predict_model <- function(fitted_model, X_test, config) {
  switch(
    fitted_model$model_type,
    har_ols = predict_har_model(fitted_model, X_test, config = config),
    enet = predict_enet_model(fitted_model, X_test, config = config),
    pca = predict_pca_model(fitted_model, X_test, config = config),
    pls = predict_pls_model(fitted_model, X_test, config = config),
    rf = predict_rf_model(fitted_model, X_test, config = config),
    nn = predict_nn_model(fitted_model, X_test, config = config),
    stop("Unsupported fitted model type: ", fitted_model$model_type)
  )
}

extract_model_importance <- function(fitted_model) {
  switch(
    fitted_model$model_type,
    har_ols = extract_har_importance(fitted_model),
    enet = extract_enet_importance(fitted_model),
    pca = extract_pca_importance(fitted_model),
    pls = extract_pls_importance(fitted_model),
    rf = extract_rf_importance(fitted_model),
    nn = extract_nn_importance(fitted_model),
    data.table::data.table(variable = character(), value = numeric(), metric = character())
  )
}
