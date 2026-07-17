required_packages <- c(
  "data.table",
  "dplyr",
  "tidyr",
  "lubridate",
  "purrr",
  "glmnet",
  "pls",
  "ranger",
  "nnet",
  "ggplot2",
  "knitr",
  "MCS",
  "openxlsx",
  "officer",
  "flextable"
)

install_missing_packages <- function(packages = required_packages) {
  missing_packages <- packages[
    !vapply(packages, requireNamespace, logical(1), quietly = TRUE)
  ]

  if (length(missing_packages) > 0L) {
    install.packages(missing_packages)
  }

  invisible(packages)
}

load_required_packages <- function(packages = required_packages, install_missing = FALSE) {
  missing_packages <- packages[
    !vapply(packages, requireNamespace, logical(1), quietly = TRUE)
  ]

  if (length(missing_packages) > 0L) {
    if (isTRUE(install_missing)) {
      install.packages(missing_packages)
    } else {
      stop(
        "Install required packages before running the project: ",
        paste(missing_packages, collapse = ", "),
        call. = FALSE
      )
    }
  }

  invisible(lapply(packages, require, character.only = TRUE))
}

if (identical(sys.nframe(), 0L)) {
  load_required_packages(
    install_missing = identical(tolower(Sys.getenv("INSTALL_MISSING_PACKAGES", "false")), "true")
  )
}
