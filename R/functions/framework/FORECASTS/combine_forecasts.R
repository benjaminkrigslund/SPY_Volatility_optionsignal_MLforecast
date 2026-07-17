combine_forecasts <- function(forecast_df,
                              method = c("equal_weight"),
                              selected_models = NULL,
                              combination_name = NULL) {
  method <- match.arg(method)
  forecast_dt <- clean_forecast_table(forecast_df)

  if (!is.null(selected_models)) {
    forecast_dt <- forecast_dt[forecast_id %in% selected_models | model_type %in% selected_models]
  }

  if (nrow(forecast_dt) == 0L) {
    stop("No forecasts available for the requested combination.")
  }

  combination_name <- combination_name %||% "combo_equal_weight"

  if (method == "equal_weight") {
    combo_dt <- forecast_dt[
      ,
      .(
        forecast_level = mean(forecast_level, na.rm = TRUE),
        forecast_transformed = mean(forecast_transformed, na.rm = TRUE),
        actual_level = data.table::first(actual_level),
        actual_transformed = data.table::first(actual_transformed),
        benchmark_forecast = data.table::first(benchmark_forecast),
        members = paste(sort(unique(forecast_id)), collapse = " | ")
      ),
      by = .(origin_date, target_date, target_type, window_type)
    ]

    combo_dt[, `:=`(
      model_type = combination_name,
      feature_set = "COMBINATION",
      forecast_id = combination_name
    )]

    return(combo_dt[])
  }

  stop("Combination method not implemented: ", method)
}

score_combination <- function(combo_forecasts, criterion = c("oos_r2", "qlike"), config) {
  criterion <- match.arg(criterion)
  evaluation <- evaluate_forecasts(forecast_df = combo_forecasts, config = config)
  summary_dt <- data.table::as.data.table(evaluation$summary)

  if (criterion == "oos_r2") {
    summary_dt[, score := oos_r2]
  } else {
    summary_dt[, score := -qlike]
  }

  list(
    evaluation = evaluation,
    summary = summary_dt
  )
}

score_combination_against_benchmark <- function(combo_forecasts,
                                                benchmark_forecasts,
                                                criterion = c("oos_r2_vs_benchmark", "qlike_gain_vs_benchmark"),
                                                config,
                                                min_history = 1L) {
  criterion <- match.arg(criterion)

  combo_dt <- data.table::as.data.table(combo_forecasts)
  benchmark_dt <- data.table::as.data.table(benchmark_forecasts)

  merged_dt <- merge(
    combo_dt[, .(
      target_date,
      target_type,
      window_type,
      combo_forecast = forecast_level,
      actual_level_combo = actual_level
    )],
    benchmark_dt[, .(
      target_date,
      target_type,
      window_type,
      benchmark_forecast = forecast_level,
      actual_level_benchmark = actual_level
    )],
    by = c("target_date", "target_type", "window_type"),
    all = FALSE
  )

  if (nrow(merged_dt) < min_history) {
    return(NA_real_)
  }

  merged_dt[, actual_level := ifelse(is.na(actual_level_combo), actual_level_benchmark, actual_level_combo)]
  merged_dt <- merged_dt[is.finite(actual_level) & is.finite(combo_forecast) & is.finite(benchmark_forecast)]

  if (nrow(merged_dt) < min_history) {
    return(NA_real_)
  }

  if (criterion == "oos_r2_vs_benchmark") {
    se_combo <- (merged_dt$actual_level - merged_dt$combo_forecast) ^ 2
    se_benchmark <- (merged_dt$actual_level - merged_dt$benchmark_forecast) ^ 2
    denom <- sum(se_benchmark, na.rm = TRUE)

    if (!is.finite(denom) || denom <= 0) {
      return(NA_real_)
    }

    return(1 - sum(se_combo, na.rm = TRUE) / denom)
  }

  qlike_combo <- qlike_loss_from_volatility(
    merged_dt$actual_level,
    merged_dt$combo_forecast,
    eps = config$evaluation$qlike_epsilon
  )
  qlike_benchmark <- qlike_loss_from_volatility(
    merged_dt$actual_level,
    merged_dt$benchmark_forecast,
    eps = config$evaluation$qlike_epsilon
  )

  mean(qlike_benchmark, na.rm = TRUE) - mean(qlike_combo, na.rm = TRUE)
}

run_backward_combination_selection <- function(forecast_df,
                                               config,
                                               criterion = c("oos_r2", "qlike"),
                                               selected_models = NULL,
                                               min_members = 1L,
                                               combination_name = "combo_backward_subset_equal_weight",
                                               improvement_tol = 1e-10) {
  criterion <- match.arg(criterion)
  forecast_dt <- clean_forecast_table(forecast_df)

  if (!is.null(selected_models)) {
    forecast_dt <- forecast_dt[forecast_id %in% selected_models | model_type %in% selected_models]
  }

  if (nrow(forecast_dt) == 0L) {
    stop("No forecasts available for backward subset selection.")
  }

  strata <- unique(forecast_dt[, .(target_type, window_type)])
  combo_results <- vector("list", nrow(strata))
  selection_results <- vector("list", nrow(strata))
  summary_results <- vector("list", nrow(strata))

  for (i in seq_len(nrow(strata))) {
    stratum <- strata[i]
    stratum_dt <- forecast_dt[
      target_type == stratum$target_type &
        window_type == stratum$window_type
    ]

    current_members <- sort(unique(stratum_dt$forecast_id))
    if (length(current_members) < min_members) {
      next
    }

    current_combo <- combine_forecasts(
      forecast_df = stratum_dt,
      method = "equal_weight",
      selected_models = current_members,
      combination_name = combination_name
    )
    current_scored <- score_combination(current_combo, criterion = criterion, config = config)
    current_score <- current_scored$summary$score[1]

    path_rows <- list(
      data.table::data.table(
        target_type = stratum$target_type,
        window_type = stratum$window_type,
        step = 0L,
        action = "start",
        removed_member = NA_character_,
        n_members = length(current_members),
        score = current_score,
        members = paste(current_members, collapse = " | ")
      )
    )

    step <- 0L
    improved <- TRUE

    while (improved && length(current_members) > min_members) {
      candidate_rows <- vector("list", length(current_members))

      for (j in seq_along(current_members)) {
        candidate_members <- current_members[-j]
        candidate_combo <- combine_forecasts(
          forecast_df = stratum_dt,
          method = "equal_weight",
          selected_models = candidate_members,
          combination_name = combination_name
        )
        candidate_scored <- score_combination(candidate_combo, criterion = criterion, config = config)
        candidate_rows[[j]] <- data.table::data.table(
          removed_member = current_members[j],
          score = candidate_scored$summary$score[1],
          n_members = length(candidate_members),
          members = paste(candidate_members, collapse = " | ")
        )
      }

      candidate_table <- data.table::rbindlist(candidate_rows)
      data.table::setorder(candidate_table, -score, removed_member)
      best_candidate <- candidate_table[1]

      if (is.na(best_candidate$score) || (best_candidate$score <= current_score + improvement_tol)) {
        improved <- FALSE
      } else {
        current_members <- unlist(strsplit(best_candidate$members, " \\| ", fixed = FALSE))
        current_score <- best_candidate$score
        step <- step + 1L
        path_rows[[length(path_rows) + 1L]] <- data.table::data.table(
          target_type = stratum$target_type,
          window_type = stratum$window_type,
          step = step,
          action = "drop",
          removed_member = best_candidate$removed_member,
          n_members = best_candidate$n_members,
          score = best_candidate$score,
          members = best_candidate$members
        )
      }
    }

    final_combo <- combine_forecasts(
      forecast_df = stratum_dt,
      method = "equal_weight",
      selected_models = current_members,
      combination_name = combination_name
    )
    final_eval <- evaluate_forecasts(forecast_df = final_combo, config = config)
    final_summary <- data.table::as.data.table(final_eval$summary)
    final_summary[, `:=`(
      selection_method = "backward_subset_equal_weight",
      criterion = criterion,
      selected_members = paste(current_members, collapse = " | "),
      n_members = length(current_members)
    )]

    combo_results[[i]] <- final_combo
    selection_results[[i]] <- data.table::rbindlist(path_rows)
    summary_results[[i]] <- final_summary
  }

  list(
    forecasts = data.table::rbindlist(combo_results, fill = TRUE),
    selection_path = data.table::rbindlist(selection_results, fill = TRUE),
    evaluation = data.table::rbindlist(summary_results, fill = TRUE)
  )
}

run_forward_combination_selection <- function(forecast_df,
                                              config,
                                              criterion = c("oos_r2", "qlike"),
                                              selected_models = NULL,
                                              combination_name = "combo_forward_subset_equal_weight",
                                              improvement_tol = 1e-10) {
  criterion <- match.arg(criterion)
  forecast_dt <- clean_forecast_table(forecast_df)

  if (!is.null(selected_models)) {
    forecast_dt <- forecast_dt[forecast_id %in% selected_models | model_type %in% selected_models]
  }

  if (nrow(forecast_dt) == 0L) {
    stop("No forecasts available for forward subset selection.")
  }

  strata <- unique(forecast_dt[, .(target_type, window_type)])
  combo_results <- vector("list", nrow(strata))
  selection_results <- vector("list", nrow(strata))
  summary_results <- vector("list", nrow(strata))

  for (i in seq_len(nrow(strata))) {
    stratum <- strata[i]
    stratum_dt <- forecast_dt[
      target_type == stratum$target_type &
        window_type == stratum$window_type
    ]

    all_members <- sort(unique(stratum_dt$forecast_id))
    if (length(all_members) == 0L) {
      next
    }

    initial_rows <- vector("list", length(all_members))
    for (j in seq_along(all_members)) {
      candidate_members <- all_members[j]
      candidate_combo <- combine_forecasts(
        forecast_df = stratum_dt,
        method = "equal_weight",
        selected_models = candidate_members,
        combination_name = combination_name
      )
      candidate_scored <- score_combination(candidate_combo, criterion = criterion, config = config)
      initial_rows[[j]] <- data.table::data.table(
        added_member = all_members[j],
        score = candidate_scored$summary$score[1],
        n_members = 1L,
        members = candidate_members
      )
    }

    initial_table <- data.table::rbindlist(initial_rows)
    data.table::setorder(initial_table, -score, added_member)
    best_initial <- initial_table[1]

    current_members <- best_initial$members
    current_score <- best_initial$score
    remaining_members <- setdiff(all_members, current_members)

    path_rows <- list(
      data.table::data.table(
        target_type = stratum$target_type,
        window_type = stratum$window_type,
        step = 0L,
        action = "start",
        added_member = best_initial$added_member,
        n_members = best_initial$n_members,
        score = best_initial$score,
        members = best_initial$members
      )
    )

    step <- 0L
    improved <- TRUE

    while (improved && length(remaining_members) > 0L) {
      candidate_rows <- vector("list", length(remaining_members))

      for (j in seq_along(remaining_members)) {
        candidate_members <- sort(c(current_members, remaining_members[j]))
        candidate_combo <- combine_forecasts(
          forecast_df = stratum_dt,
          method = "equal_weight",
          selected_models = candidate_members,
          combination_name = combination_name
        )
        candidate_scored <- score_combination(candidate_combo, criterion = criterion, config = config)
        candidate_rows[[j]] <- data.table::data.table(
          added_member = remaining_members[j],
          score = candidate_scored$summary$score[1],
          n_members = length(candidate_members),
          members = paste(candidate_members, collapse = " | ")
        )
      }

      candidate_table <- data.table::rbindlist(candidate_rows)
      data.table::setorder(candidate_table, -score, added_member)
      best_candidate <- candidate_table[1]

      if (is.na(best_candidate$score) || (best_candidate$score <= current_score + improvement_tol)) {
        improved <- FALSE
      } else {
        current_members <- unlist(strsplit(best_candidate$members, " \\| ", fixed = FALSE))
        current_score <- best_candidate$score
        remaining_members <- setdiff(all_members, current_members)
        step <- step + 1L
        path_rows[[length(path_rows) + 1L]] <- data.table::data.table(
          target_type = stratum$target_type,
          window_type = stratum$window_type,
          step = step,
          action = "add",
          added_member = best_candidate$added_member,
          n_members = best_candidate$n_members,
          score = best_candidate$score,
          members = best_candidate$members
        )
      }
    }

    final_combo <- combine_forecasts(
      forecast_df = stratum_dt,
      method = "equal_weight",
      selected_models = current_members,
      combination_name = combination_name
    )
    final_eval <- evaluate_forecasts(forecast_df = final_combo, config = config)
    final_summary <- data.table::as.data.table(final_eval$summary)
    final_summary[, `:=`(
      selection_method = "forward_subset_equal_weight",
      criterion = criterion,
      selected_members = paste(current_members, collapse = " | "),
      n_members = length(current_members)
    )]

    combo_results[[i]] <- final_combo
    selection_results[[i]] <- data.table::rbindlist(path_rows)
    summary_results[[i]] <- final_summary
  }

  list(
    forecasts = data.table::rbindlist(combo_results, fill = TRUE),
    selection_path = data.table::rbindlist(selection_results, fill = TRUE),
    evaluation = data.table::rbindlist(summary_results, fill = TRUE)
  )
}

run_online_forward_combination_selection <- function(forecast_df,
                                                     benchmark_df,
                                                     config,
                                                     criterion = c("oos_r2_vs_benchmark", "qlike_gain_vs_benchmark"),
                                                     selected_models = NULL,
                                                     target_types = NULL,
                                                     window_types = NULL,
                                                     min_history = 24L,
                                                     combination_name = "combo_online_forward_subset_equal_weight",
                                                     improvement_tol = 1e-10) {
  criterion <- match.arg(criterion)
  forecast_dt <- clean_forecast_table(forecast_df)
  benchmark_dt <- clean_forecast_table(benchmark_df)

  if (!is.null(selected_models)) {
    forecast_dt <- forecast_dt[forecast_id %in% selected_models | model_type %in% selected_models]
  }

  if (!is.null(target_types)) {
    forecast_dt <- forecast_dt[target_type %in% target_types]
    benchmark_dt <- benchmark_dt[target_type %in% target_types]
  }

  if (!is.null(window_types)) {
    forecast_dt <- forecast_dt[window_type %in% window_types]
    benchmark_dt <- benchmark_dt[window_type %in% window_types]
  }

  if (nrow(forecast_dt) == 0L) {
    stop("No forecasts available for online forward subset selection.")
  }

  strata <- unique(forecast_dt[, .(target_type, window_type)])
  combo_results <- vector("list", nrow(strata))
  selection_results <- vector("list", nrow(strata))

  for (i in seq_len(nrow(strata))) {
    stratum <- strata[i]
    stratum_dt <- forecast_dt[
      target_type == stratum$target_type &
        window_type == stratum$window_type
    ]
    stratum_benchmark <- benchmark_dt[
      target_type == stratum$target_type &
        window_type == stratum$window_type
    ]

    target_dates <- sort(unique(stratum_dt$target_date))
    current_combo_rows <- list()
    current_path_rows <- list()

    for (date_idx in seq_along(target_dates)) {
      current_target_date <- target_dates[date_idx]
      history_dt <- stratum_dt[target_date < current_target_date]
      benchmark_history <- stratum_benchmark[target_date < current_target_date]
      current_dt <- stratum_dt[target_date == current_target_date]

      if (nrow(history_dt) == 0L || nrow(benchmark_history) < min_history || nrow(current_dt) == 0L) {
        next
      }

      available_now <- sort(unique(current_dt$forecast_id))
      candidate_pool <- available_now[vapply(
        available_now,
        function(member) {
          history_count <- history_dt[forecast_id == member & is.finite(forecast_level), .N]
          history_count >= min_history
        },
        integer(1)
      ) == 1L]

      if (length(candidate_pool) == 0L) {
        next
      }

      initial_rows <- vector("list", length(candidate_pool))
      for (j in seq_along(candidate_pool)) {
        candidate_members <- candidate_pool[j]
        candidate_combo <- combine_forecasts(
          forecast_df = history_dt,
          method = "equal_weight",
          selected_models = candidate_members,
          combination_name = combination_name
        )
        initial_rows[[j]] <- data.table::data.table(
          added_member = candidate_pool[j],
          score = score_combination_against_benchmark(
            combo_forecasts = candidate_combo,
            benchmark_forecasts = benchmark_history,
            criterion = criterion,
            config = config,
            min_history = min_history
          ),
          n_members = 1L,
          members = candidate_members
        )
      }

      initial_table <- data.table::rbindlist(initial_rows)
      initial_table <- initial_table[is.finite(score)]
      if (nrow(initial_table) == 0L) {
        next
      }

      data.table::setorder(initial_table, -score, added_member)
      best_initial <- initial_table[1]

      current_members <- best_initial$members
      current_score <- best_initial$score
      remaining_members <- setdiff(candidate_pool, current_members)

      path_rows <- list(
        data.table::data.table(
          target_date = current_target_date,
          target_type = stratum$target_type,
          window_type = stratum$window_type,
          step = 0L,
          action = "start",
          added_member = best_initial$added_member,
          n_members = best_initial$n_members,
          score = best_initial$score,
          members = best_initial$members
        )
      )

      step <- 0L
      improved <- TRUE

      while (improved && length(remaining_members) > 0L) {
        candidate_rows <- vector("list", length(remaining_members))

        for (j in seq_along(remaining_members)) {
          candidate_members <- sort(c(current_members, remaining_members[j]))
          candidate_combo <- combine_forecasts(
            forecast_df = history_dt,
            method = "equal_weight",
            selected_models = candidate_members,
            combination_name = combination_name
          )
          candidate_rows[[j]] <- data.table::data.table(
            added_member = remaining_members[j],
            score = score_combination_against_benchmark(
              combo_forecasts = candidate_combo,
              benchmark_forecasts = benchmark_history,
              criterion = criterion,
              config = config,
              min_history = min_history
            ),
            n_members = length(candidate_members),
            members = paste(candidate_members, collapse = " | ")
          )
        }

        candidate_table <- data.table::rbindlist(candidate_rows)
        candidate_table <- candidate_table[is.finite(score)]

        if (nrow(candidate_table) == 0L) {
          break
        }

        data.table::setorder(candidate_table, -score, added_member)
        best_candidate <- candidate_table[1]

        if (best_candidate$score <= current_score + improvement_tol) {
          improved <- FALSE
        } else {
          current_members <- unlist(strsplit(best_candidate$members, " \\| ", fixed = FALSE))
          current_score <- best_candidate$score
          remaining_members <- setdiff(candidate_pool, current_members)
          step <- step + 1L
          path_rows[[length(path_rows) + 1L]] <- data.table::data.table(
            target_date = current_target_date,
            target_type = stratum$target_type,
            window_type = stratum$window_type,
            step = step,
            action = "add",
            added_member = best_candidate$added_member,
            n_members = best_candidate$n_members,
            score = best_candidate$score,
            members = best_candidate$members
          )
        }
      }

      current_combo <- combine_forecasts(
        forecast_df = current_dt,
        method = "equal_weight",
        selected_models = current_members,
        combination_name = combination_name
      )
      current_combo[, `:=`(
        selected_members = paste(current_members, collapse = " | "),
        n_members = length(current_members),
        selection_score = current_score,
        selection_criterion = criterion
      )]

      current_combo_rows[[length(current_combo_rows) + 1L]] <- current_combo
      current_path_rows[[length(current_path_rows) + 1L]] <- data.table::rbindlist(path_rows)
    }

    combo_results[[i]] <- data.table::rbindlist(current_combo_rows, fill = TRUE)
    selection_results[[i]] <- data.table::rbindlist(current_path_rows, fill = TRUE)
  }

  combo_forecasts <- data.table::rbindlist(combo_results, fill = TRUE)
  selection_path <- data.table::rbindlist(selection_results, fill = TRUE)
  evaluation <- evaluate_forecasts(forecast_df = combo_forecasts, config = config)
  evaluation_summary <- data.table::as.data.table(evaluation$summary)
  evaluation_summary[, `:=`(
    selection_method = "online_forward_subset_equal_weight",
    criterion = criterion
  )]

  list(
    forecasts = combo_forecasts,
    selection_path = selection_path,
    evaluation = evaluation_summary
  )
}
