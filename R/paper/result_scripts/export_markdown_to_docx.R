#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(officer)
  library(flextable)
})

args <- commandArgs(trailingOnly = TRUE)

input_path <- if (length(args) >= 1) {
  args[[1]]
} else {
  file.path("output", "tables", "economic_value_vrp_scaled_short_only_forecast_combinations_main_rolling120.md")
}

output_path <- if (length(args) >= 2) {
  args[[2]]
} else {
  sub("\\.md$", ".docx", input_path)
}

if (!file.exists(input_path)) {
  stop("Input markdown file not found: ", input_path)
}

lines <- readLines(input_path, warn = FALSE, encoding = "UTF-8")

is_table_line <- function(x) {
  grepl("^\\s*\\|", x)
}

is_separator_row <- function(cells) {
  all(grepl("^:?-{3,}:?$", trimws(cells)))
}

split_table_row <- function(x) {
  x <- trimws(x)
  x <- sub("^\\|", "", x)
  x <- sub("\\|$", "", x)
  trimws(strsplit(x, "\\|", fixed = FALSE)[[1]])
}

parse_markdown_table <- function(table_lines) {
  rows <- lapply(table_lines, split_table_row)
  rows <- rows[!vapply(rows, is_separator_row, logical(1))]

  if (length(rows) < 2) {
    return(NULL)
  }

  max_cols <- max(vapply(rows, length, integer(1)))
  pad_row <- function(x) c(x, rep("", max_cols - length(x)))

  header <- pad_row(rows[[1]])
  body <- rows[-1]
  mat <- do.call(rbind, lapply(body, pad_row))
  out <- as.data.frame(mat, stringsAsFactors = FALSE, check.names = FALSE)
  names(out) <- make.unique(header, sep = " ")
  out
}

add_paragraph <- function(doc, text) {
  text <- trimws(text)
  if (!nzchar(text)) {
    return(doc)
  }
  body_add_par(doc, text, style = "Normal")
}

add_code_block <- function(doc, code_lines) {
  code_text <- paste(code_lines, collapse = "\n")
  body_add_fpar(
    doc,
    fpar(
      ftext(
        code_text,
        prop = fp_text(font.family = "Courier New", font.size = 9)
      )
    )
  )
}

add_markdown_table <- function(doc, table_lines) {
  dat <- parse_markdown_table(table_lines)
  if (is.null(dat)) {
    return(doc)
  }

  font_size <- if (ncol(dat) >= 9) 7 else 8

  ft <- flextable(dat)
  ft <- theme_booktabs(ft)
  ft <- fontsize(ft, size = font_size, part = "all")
  ft <- bold(ft, bold = TRUE, part = "header")
  ft <- align(ft, align = "center", part = "header")
  ft <- align(ft, j = 1, align = "left", part = "body")
  ft <- valign(ft, valign = "top", part = "all")
  ft <- set_table_properties(ft, width = 1, layout = "autofit")
  ft <- autofit(ft)

  body_add_flextable(doc, ft)
}

doc <- read_docx()
doc <- body_set_default_section(
  doc,
  prop_section(
    page_size = page_size(orient = "landscape"),
    page_margins = page_mar(top = 0.5, bottom = 0.5, left = 0.5, right = 0.5)
  )
)

i <- 1
n <- length(lines)

while (i <= n) {
  line <- lines[[i]]

  if (grepl("^```", line)) {
    code_lines <- character()
    i <- i + 1
    while (i <= n && !grepl("^```", lines[[i]])) {
      code_lines <- c(code_lines, lines[[i]])
      i <- i + 1
    }
    doc <- add_code_block(doc, code_lines)
    i <- i + 1
    next
  }

  if (is_table_line(line)) {
    table_lines <- character()
    while (i <= n && is_table_line(lines[[i]])) {
      table_lines <- c(table_lines, lines[[i]])
      i <- i + 1
    }
    doc <- add_markdown_table(doc, table_lines)
    next
  }

  if (grepl("^#\\s+", line)) {
    doc <- body_add_par(doc, sub("^#\\s+", "", line), style = "heading 1")
  } else if (grepl("^##\\s+", line)) {
    doc <- body_add_par(doc, sub("^##\\s+", "", line), style = "heading 2")
  } else {
    doc <- add_paragraph(doc, line)
  }

  i <- i + 1
}

print(doc, target = output_path)
message("Wrote ", output_path)
