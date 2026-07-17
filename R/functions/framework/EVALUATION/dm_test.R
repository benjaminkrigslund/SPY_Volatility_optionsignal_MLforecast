dm_test <- function(loss_a, loss_b, horizon = 1L) {
  loss_a <- as.numeric(loss_a)
  loss_b <- as.numeric(loss_b)
  keep <- stats::complete.cases(loss_a, loss_b)
  d <- loss_a[keep] - loss_b[keep]

  n <- length(d)
  if (n < 5L) {
    return(data.table::data.table(statistic = NA_real_, p_value = NA_real_, mean_loss_diff = NA_real_, n = n))
  }

  gamma0 <- stats::var(d)
  if (is.na(gamma0) || gamma0 == 0) {
    return(data.table::data.table(statistic = NA_real_, p_value = NA_real_, mean_loss_diff = mean(d), n = n))
  }

  long_run_var <- gamma0
  if (horizon > 1L) {
    for (lag in seq_len(horizon - 1L)) {
      cov_lag <- stats::cov(d[(lag + 1L):n], d[seq_len(n - lag)])
      long_run_var <- long_run_var + 2 * (1 - lag / horizon) * cov_lag
    }
  }

  stat <- mean(d) / sqrt(long_run_var / n)
  p_value <- 2 * stats::pnorm(abs(stat), lower.tail = FALSE)

  data.table::data.table(
    statistic = stat,
    p_value = p_value,
    mean_loss_diff = mean(d),
    n = n
  )
}

