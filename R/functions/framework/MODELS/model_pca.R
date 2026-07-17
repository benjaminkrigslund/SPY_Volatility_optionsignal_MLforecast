resolve_reduction_blocks <- function(feature_names, feature_blocks = NULL) {
  if (is.null(feature_blocks) || length(feature_blocks) == 0L) {
    return(list(all = feature_names))
  }

  lapply(feature_blocks, intersect, y = feature_names)
}

fit_pca_model <- function(X_train, y_train, config = list(), feature_names = colnames(X_train), feature_blocks = NULL) {
  block_map <- resolve_reduction_blocks(feature_names, feature_blocks)
  min_block_size <- config$min_block_size %||% 5L
  threshold <- config$explained_variance %||% 0.70

  transformed_parts <- list()
  block_objects <- list()
  component_index <- 0L

  for (block_name in names(block_map)) {
    block_cols <- block_map[[block_name]]
    if (length(block_cols) == 0L) {
      next
    }

    block_x <- as.matrix(X_train[, block_cols, drop = FALSE])

    if (length(block_cols) < min_block_size) {
      transformed_parts[[block_name]] <- block_x
      block_objects[[block_name]] <- list(
        type = "raw",
        columns = block_cols
      )
      next
    }

    preproc <- fit_standardizer(block_x)
    x_scaled <- transform_standardizer(block_x, preproc)
    pca_fit <- stats::prcomp(x_scaled, center = FALSE, scale. = FALSE)
    explained <- (pca_fit$sdev ^ 2) / sum(pca_fit$sdev ^ 2)
    cum_explained <- cumsum(explained)
    ncomp <- which(cum_explained >= threshold)[1]
    ncomp <- max(1L, ncomp)

    score_names <- paste0(toupper(block_name), "_PC", seq_len(ncomp))
    scores <- pca_fit$x[, seq_len(ncomp), drop = FALSE]
    colnames(scores) <- score_names

    transformed_parts[[block_name]] <- scores
    block_objects[[block_name]] <- list(
      type = "pca",
      columns = block_cols,
      preproc = preproc,
      pca = pca_fit,
      explained = explained,
      ncomp = ncomp,
      score_names = score_names
    )
    component_index <- component_index + ncomp
  }

  x_transformed <- do.call(cbind, transformed_parts)
  train_df <- data.frame(y = y_train, x_transformed, check.names = FALSE)
  model <- stats::lm(y ~ ., data = train_df)

  list(
    model_type = "pca",
    object = model,
    feature_names = feature_names,
    block_objects = block_objects,
    transformed_feature_names = colnames(x_transformed),
    ncomp = component_index
  )
}

predict_pca_model <- function(fitted_model, X_test, config = list()) {
  transformed_parts <- lapply(
    fitted_model$block_objects,
    function(block_object) {
      block_x <- as.matrix(X_test[, block_object$columns, drop = FALSE])

      if (identical(block_object$type, "raw")) {
        return(block_x)
      }

      x_scaled <- transform_standardizer(block_x, block_object$preproc)
      scores <- x_scaled %*% block_object$pca$rotation[, seq_len(block_object$ncomp), drop = FALSE]
      colnames(scores) <- block_object$score_names
      scores
    }
  )

  x_transformed <- do.call(cbind, transformed_parts)
  test_df <- data.frame(x_transformed, check.names = FALSE)
  names(test_df) <- fitted_model$transformed_feature_names
  as.numeric(stats::predict(fitted_model$object, newdata = test_df))
}

extract_pca_importance <- function(fitted_model) {
  importance_rows <- list()

  for (block_name in names(fitted_model$block_objects)) {
    block_object <- fitted_model$block_objects[[block_name]]

    if (identical(block_object$type, "raw")) {
      coef_table <- stats::coef(fitted_model$object)[block_object$columns]
      coef_table <- coef_table[!is.na(coef_table)]
      importance_rows[[length(importance_rows) + 1L]] <- data.table::data.table(
        variable = names(coef_table),
        value = as.numeric(coef_table),
        metric = "coefficient"
      )
      next
    }

    loadings <- block_object$pca$rotation[, seq_len(block_object$ncomp), drop = FALSE]
    colnames(loadings) <- block_object$score_names
    loadings_dt <- data.table::as.data.table(loadings, keep.rownames = "variable")
    loadings_long <- data.table::melt(
      loadings_dt,
      id.vars = "variable",
      variable.name = "component",
      value.name = "value"
    )
    loadings_long[, metric := "loading"]
    importance_rows[[length(importance_rows) + 1L]] <- loadings_long
  }

  data.table::rbindlist(importance_rows, fill = TRUE)
}
