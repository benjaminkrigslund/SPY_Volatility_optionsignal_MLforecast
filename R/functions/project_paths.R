find_project_root <- function(start = getwd()) {
  current <- normalizePath(start, winslash = "/", mustWork = TRUE)

  repeat {
    has_rproj <- length(list.files(current, pattern = "\\.Rproj$", full.names = TRUE)) > 0L
    has_framework <- file.exists(file.path(current, "R", "functions", "framework", "00_config.R"))

    if (has_rproj || has_framework) {
      return(current)
    }

    parent <- dirname(current)
    if (identical(parent, current)) {
      stop("Could not locate the project root from: ", start)
    }
    current <- parent
  }
}

project_path <- function(...) {
  file.path(find_project_root(), ...)
}
