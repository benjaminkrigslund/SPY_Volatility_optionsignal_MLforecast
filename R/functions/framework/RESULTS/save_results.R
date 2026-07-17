save_results <- function(object, file_stub, config, subdir = NULL) {
  base_dir <- config$paths$results_dir
  if (!is.null(subdir)) {
    base_dir <- file.path(base_dir, subdir)
  }

  ensure_dir(base_dir)

  if (is.data.frame(object) || data.table::is.data.table(object)) {
    if (isTRUE(config$output$save_csv)) {
      data.table::fwrite(object, file.path(base_dir, paste0(file_stub, ".csv")))
    }
    if (isTRUE(config$output$save_rds)) {
      saveRDS(object, file.path(base_dir, paste0(file_stub, ".rds")))
    }
  } else {
    if (isTRUE(config$output$save_rds)) {
      saveRDS(object, file.path(base_dir, paste0(file_stub, ".rds")))
    }
  }

  invisible(file.path(base_dir, file_stub))
}

