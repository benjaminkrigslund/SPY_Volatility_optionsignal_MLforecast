resolve_feature_columns <- function(data, config, feature_group = c("har", "option", "macro")) {
  feature_group <- match.arg(feature_group)

  configured <- config$columns[[feature_group]]
  if (!is.null(configured)) {
    return(configured)
  }

  if (feature_group == "macro") {
    return(grep("^macro_", names(data), value = TRUE))
  }

  character()
}

get_feature_map <- function(config) {
  stop("get_feature_map() now requires data. Call get_feature_set() instead.")
}

build_feature_map <- function(data, config) {
  har_cols <- resolve_feature_columns(data, config, "har")
  option_cols <- resolve_feature_columns(data, config, "option")
  macro_cols <- resolve_feature_columns(data, config, "macro")

  list(
    HAR = har_cols,
    O = option_cols,
    M = macro_cols,
    OM = unique(c(option_cols, macro_cols)),
    HAR_O = unique(c(har_cols, option_cols)),
    HAR_M = unique(c(har_cols, macro_cols)),
    HAR_OM = unique(c(har_cols, option_cols, macro_cols))
  )
}

get_feature_set <- function(data, feature_set = c("HAR", "O", "M", "OM", "HAR_O", "HAR_M", "HAR_OM"), config) {
  feature_set <- match.arg(feature_set)
  feature_map <- build_feature_map(data, config)
  feature_cols <- feature_map[[feature_set]]
  block_map <- list(
    har = intersect(feature_map[["HAR"]], feature_cols),
    option = intersect(feature_map[["O"]], feature_cols),
    macro = intersect(feature_map[["M"]], feature_cols)
  )
  block_map <- block_map[vapply(block_map, length, integer(1)) > 0L]

  missing_cols <- setdiff(feature_cols, names(data))
  if (length(missing_cols) > 0L) {
    stop(
      "Feature set ", feature_set, " references missing columns: ",
      paste(missing_cols, collapse = ", ")
    )
  }

  keep_cols <- unique(c(config$columns$date, config$columns$target, feature_cols))
  out <- data[, ..keep_cols]
  data.table::setattr(out, "feature_blocks", block_map)
  out
}
