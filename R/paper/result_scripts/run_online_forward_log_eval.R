library(data.table)

source(file.path("R", "functions", "framework", "00_config.R"))
source(file.path("R", "functions", "framework", "UTILS", "helpers.R"))

config <- create_config(base_dir = getwd())
allf <- as.data.table(readRDS(file.path(config$paths$results_dir, "all_forecasts.rds")))
allf <- clean_forecast_table(allf)

nonhar <- allf[
  model_type != "har_ols" &
    target_type == "log" &
    window_type %in% c("rolling", "expanding")
]

har <- allf[
  model_type == "har_ols" &
    target_type == "log" &
    window_type %in% c("rolling", "expanding")
]

run_online_forward_fast <- function(stratum_dt, har_dt, min_history = 24L) {
  dates <- sort(unique(stratum_dt$target_date))

  wide <- dcast(stratum_dt, target_date ~ forecast_id, value.var = "forecast_level")
  setorder(wide, target_date)

  mat <- as.matrix(wide[, -1])
  mode(mat) <- "numeric"
  colnames(mat) <- names(wide)[-1]

  actual <- stratum_dt[
    ,
    .(actual_level = first(actual_level)),
    by = target_date
  ][order(target_date)]$actual_level

  har_vec <- har_dt[
    ,
    .(har_forecast = first(forecast_level)),
    by = target_date
  ][order(target_date)]$har_forecast

  score_members <- function(member_names, hist_idx) {
    combo_hist <- rowMeans(mat[hist_idx, member_names, drop = FALSE], na.rm = TRUE)
    valid <- is.finite(combo_hist) & is.finite(actual[hist_idx]) & is.finite(har_vec[hist_idx])

    if (sum(valid) < min_history) {
      return(-Inf)
    }

    denom <- sum((actual[hist_idx][valid] - har_vec[hist_idx][valid])^2)

    if (!is.finite(denom) || denom <= 0) {
      return(-Inf)
    }

    1 - sum((actual[hist_idx][valid] - combo_hist[valid])^2) / denom
  }

  rows <- vector("list", length(dates))
  path <- list()
  out_i <- 0L
  path_i <- 0L

  for (t in seq_along(dates)) {
    hist_idx <- seq_len(t - 1L)

    if (length(hist_idx) < min_history) {
      next
    }

    current_row <- mat[t, ]
    available_now <- names(current_row)[is.finite(current_row)]

    if (!length(available_now)) {
      next
    }

    history_counts <- colSums(is.finite(mat[hist_idx, available_now, drop = FALSE]))
    candidate_pool <- available_now[history_counts >= min_history]

    if (!length(candidate_pool)) {
      next
    }

    single_scores <- vapply(
      candidate_pool,
      function(member) score_members(member, hist_idx),
      numeric(1)
    )

    if (!any(is.finite(single_scores))) {
      next
    }

    best_idx <- which.max(single_scores)
    current_members <- candidate_pool[best_idx]
    current_score <- single_scores[best_idx]
    remaining <- setdiff(candidate_pool, current_members)

    path_i <- path_i + 1L
    path[[path_i]] <- data.table(
      target_date = dates[t],
      step = 0L,
      action = "start",
      added_member = current_members,
      n_members = 1L,
      score = current_score,
      members = current_members
    )

    step <- 0L

    repeat {
      if (!length(remaining)) {
        break
      }

      cand_scores <- vapply(
        remaining,
        function(member) score_members(sort(c(current_members, member)), hist_idx),
        numeric(1)
      )

      if (!any(is.finite(cand_scores))) {
        break
      }

      add_idx <- which.max(cand_scores)
      best_add <- remaining[add_idx]
      best_score <- cand_scores[add_idx]

      if (!is.finite(best_score) || best_score <= current_score + 1e-10) {
        break
      }

      current_members <- sort(c(current_members, best_add))
      current_score <- best_score
      remaining <- setdiff(candidate_pool, current_members)
      step <- step + 1L

      path_i <- path_i + 1L
      path[[path_i]] <- data.table(
        target_date = dates[t],
        step = step,
        action = "add",
        added_member = best_add,
        n_members = length(current_members),
        score = current_score,
        members = paste(current_members, collapse = " | ")
      )
    }

    combo_forecast <- mean(current_row[current_members], na.rm = TRUE)

    out_i <- out_i + 1L
    rows[[out_i]] <- data.table(
      target_date = dates[t],
      forecast_level = combo_forecast,
      actual_level = actual[t],
      har_forecast = har_vec[t],
      selected_members = paste(current_members, collapse = " | "),
      n_members = length(current_members),
      selection_score = current_score
    )
  }

  list(
    forecasts = rbindlist(rows[seq_len(out_i)], fill = TRUE),
    path = rbindlist(path, fill = TRUE)
  )
}

results <- list()
eval_rows <- list()
path_rows <- list()
idx <- 0L
pidx <- 0L

for (window_name in c("rolling", "expanding")) {
  stratum_dt <- nonhar[window_type == window_name]
  har_dt <- har[window_type == window_name]
  res <- run_online_forward_fast(stratum_dt, har_dt, min_history = 24L)

  if (nrow(res$forecasts) == 0L) {
    next
  }

  res$forecasts[, `:=`(
    target_type = "log",
    window_type = window_name,
    model_type = "combo_online_forward_subset_equal_weight",
    feature_set = "COMBINATION",
    forecast_id = "combo_online_forward_subset_equal_weight"
  )]

  res$path[, `:=`(
    target_type = "log",
    window_type = window_name
  )]

  dt <- res$forecasts[
    is.finite(forecast_level) &
      is.finite(actual_level) &
      is.finite(har_forecast)
  ]

  dt[, se_combo := (actual_level - forecast_level)^2]
  dt[, se_har := (actual_level - har_forecast)^2]
  dt[, qlike_combo := qlike_loss_from_volatility(actual_level, forecast_level, eps = config$evaluation$qlike_epsilon)]
  dt[, qlike_har := qlike_loss_from_volatility(actual_level, har_forecast, eps = config$evaluation$qlike_epsilon)]

  idx <- idx + 1L
  eval_rows[[idx]] <- dt[
    ,
    .(
      target_type = "log",
      window_type = window_name,
      n_oos = .N,
      oos_r2_vs_har = 1 - sum(se_combo) / sum(se_har),
      qlike_combo = mean(qlike_combo),
      qlike_har = mean(qlike_har),
      qlike_gain_vs_har = mean(qlike_har) - mean(qlike_combo),
      qlike_pct_improvement_vs_har = 100 * (1 - mean(qlike_combo) / mean(qlike_har)),
      avg_n_members = mean(n_members),
      median_n_members = median(n_members)
    )
  ]

  pidx <- pidx + 1L
  path_rows[[pidx]] <- res$path
  results[[idx]] <- res$forecasts
}

out_eval <- rbindlist(eval_rows, fill = TRUE)
out_forecasts <- rbindlist(results, fill = TRUE)
out_path <- rbindlist(path_rows, fill = TRUE)

print(out_eval)
cat("\nLATEST MEMBERS\n")
print(
  out_forecasts[order(target_date), .SD[.N], by = window_type][
    ,
    .(window_type, target_date, n_members, selection_score, selected_members)
  ]
)

fwrite(out_eval, file.path(config$paths$results_dir, "forecast_combinations_online_forward_log_har_eval.csv"))
fwrite(out_forecasts, file.path(config$paths$results_dir, "forecast_combinations_online_forward_log_har_forecasts.csv"))
fwrite(out_path, file.path(config$paths$results_dir, "forecast_combinations_online_forward_log_har_path.csv"))
