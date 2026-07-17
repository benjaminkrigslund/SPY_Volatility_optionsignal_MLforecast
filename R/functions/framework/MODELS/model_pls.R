fit_pls_model <- function(X_train, y_train, config = list(), feature_names = colnames(X_train), feature_blocks = NULL) {
  block_map <- resolve_reduction_blocks(feature_names, feature_blocks)
  min_block_size <- config$min_block_size %||% 5L

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

    train_df <- data.frame(y = y_train, block_x, check.names = FALSE)
    names(train_df) <- c("y", block_cols)

    max_components <- config$max_components %||% min(length(block_cols), max(1L, nrow(block_x) - 1L))
    pls_fit <- pls::plsr(
      y ~ .,
      data = train_df,
      scale = TRUE,
      validation = config$validation %||% "CV",
      ncomp = max_components
    )

    validation_press <- pls_fit$validation$PRESS
    if (!is.null(validation_press)) {
      press_vals <- drop(validation_press)
      press_vals <- press_vals[-1]
      ncomp <- which.min(press_vals)
    } else {
      ncomp <- min(max_components, 5L)
    }
    ncomp <- max(1L, min(ncomp, max_components))

    scores <- pls_fit$scores[, seq_len(ncomp), drop = FALSE]
    score_names <- paste0(toupper(block_name), "_PLS", seq_len(ncomp))
    colnames(scores) <- score_names

    transformed_parts[[block_name]] <- scores
    block_objects[[block_name]] <- list(
      type = "pls",
      columns = block_cols,
      object = pls_fit,
      ncomp = ncomp,
      score_names = score_names
    )
    component_index <- component_index + ncomp
  }

  x_transformed <- do.call(cbind, transformed_parts)
  train_df <- data.frame(y = y_train, x_transformed, check.names = FALSE)
  model <- stats::lm(y ~ ., data = train_df)

  list(
    model_type = "pls",
    object = model,
    feature_names = feature_names,
    block_objects = block_objects,
    transformed_feature_names = colnames(x_transformed),
    ncomp = component_index
  )
}

predict_pls_model <- function(fitted_model, X_test, config = list()) {
  transformed_parts <- lapply(
    fitted_model$block_objects,
    function(block_object) {
      block_x <- as.matrix(X_test[, block_object$columns, drop = FALSE])

      if (identical(block_object$type, "raw")) {
        return(block_x)
      }

      centered <- sweep(block_x, 2, block_object$object$Xmeans, "-")
      scale_vec <- block_object$object$scale
      if (!isFALSE(scale_vec)) {
        centered <- sweep(centered, 2, scale_vec, "/")
      }
      scores <- centered %*% block_object$object$projection[, seq_len(block_object$ncomp), drop = FALSE]
      colnames(scores) <- block_object$score_names
      scores
    }
  )

  x_transformed <- do.call(cbind, transformed_parts)
  test_df <- data.frame(x_transformed, check.names = FALSE)
  names(test_df) <- fitted_model$transformed_feature_names
  as.numeric(stats::predict(fitted_model$object, newdata = test_df))
}

extract_pls_importance <- function(fitted_model) {
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

    loadings <- block_object$object$loadings[, seq_len(block_object$ncomp), drop = FALSE]
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
