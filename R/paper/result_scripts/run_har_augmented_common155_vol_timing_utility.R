library(data.table)
library(ggplot2)

source(file.path("R", "functions", "framework", "00_config.R"))
source(file.path("R", "functions", "framework", "UTILS", "helpers.R"))

config <- create_config(base_dir = getwd())

forecast_path <- file.path(
  config$paths$results_dir,
  "har_augmented_common155_monthly_refit_forecasts.csv"
)
if (!file.exists(forecast_path)) {
  stop("Missing saved monthly-refit forecast panel: ", forecast_path)
}

market_path <- file.path(config$paths$data_dir, "(usa)_(mkt)_(monthly)_(vw_cap) 2.csv")
if (!file.exists(market_path)) {
  stop("Missing monthly market return file: ", market_path)
}

forecast_floor <- 1e-4
target_vol_annual_grid <- c(0.10, 0.15, 0.20)
utility_gamma_grid <- 1:10
max_leverage <- 1.5
allow_short <- FALSE
rf_monthly <- 0

forecast_df <- fread(forecast_path)
forecast_df <- clean_forecast_table(forecast_df)

selected_models <- data.table(
  forecast_id = c(
    "har_ols__HAR__log__rolling",
    "enet__HAR_O__log__rolling",
    "rf__HAR_O__log__rolling",
    "combo_equal_weight_har_o_across_ml_har_augmented_log_rolling",
    "combo_equal_weight_nn_across_har_augmented_datasets_log_rolling",
    "stacked_enet_on_har_augmented_forecasts_log_rolling"
  ),
  specification = c(
    "HAR",
    "ENET HAR + Option",
    "RF HAR + Option",
    "EW Across ML HAR + Option",
    "EW Neural Net Across Sets",
    "Stacked ENET"
  )
)

market_returns <- fread(market_path)[
  ,
  .(
    month = as.Date(date),
    risky_return = as.numeric(ret),
    rf = rf_monthly,
    excess_return = as.numeric(ret) - rf_monthly
  )
][order(month)]

investor_data <- merge(
  forecast_df[
    forecast_id %in% selected_models$forecast_id,
    .(
      forecast_id,
      month = as.Date(origin_date),
      forecast_var = pmax(as.numeric(forecast_level), forecast_floor)
    )
  ],
  selected_models,
  by = "forecast_id",
  all = FALSE
)

investor_data <- merge(investor_data, market_returns, by = "month", all = FALSE)
setorder(investor_data, specification, month)

build_portfolio_path <- function(data, target_vol_annual, max_leverage, allow_short) {
  target_vol_monthly <- target_vol_annual / sqrt(12)
  forecast_vol <- sqrt(pmax(data$forecast_var, forecast_floor))
  weights_raw <- target_vol_monthly / forecast_vol
  lower_bound <- if (allow_short) -max_leverage else 0
  weights <- pmin(pmax(weights_raw, lower_bound), max_leverage)
  portfolio_return <- data$rf + weights * data$excess_return

  data.table(
    month = data$month,
    specification = data$specification,
    target_vol_annual = target_vol_annual,
    target_vol_monthly = target_vol_monthly,
    forecast_var = data$forecast_var,
    forecast_vol = forecast_vol,
    weight = weights,
    risky_return = data$risky_return,
    rf = data$rf,
    excess_return = data$excess_return,
    portfolio_return = portfolio_return,
    turnover = c(NA_real_, abs(diff(weights))),
    cumulative_wealth = cumprod(1 + portfolio_return)
  )
}

summarise_utility <- function(path_data) {
  avg_return <- mean(path_data$portfolio_return, na.rm = TRUE)
  vol_return <- stats::sd(path_data$portfolio_return, na.rm = TRUE)
  var_return <- stats::var(path_data$portfolio_return, na.rm = TRUE)

  data.table(
    specification = unique(path_data$specification),
    target_vol_annual = unique(path_data$target_vol_annual),
    observations = nrow(path_data),
    mean_return = avg_return,
    vol_return = vol_return,
    var_return = var_return,
    sharpe = ifelse(vol_return > 0, avg_return / vol_return, NA_real_),
    avg_weight = mean(path_data$weight, na.rm = TRUE),
    avg_turnover = mean(path_data$turnover, na.rm = TRUE),
    realized_vol_annualized = sqrt(12) * vol_return,
    realized_mean_annualized = 12 * avg_return,
    terminal_wealth = data.table::last(path_data$cumulative_wealth)
  )
}

portfolio_paths <- rbindlist(
  lapply(
    target_vol_annual_grid,
    function(target_vol_value) {
      rbindlist(
        lapply(
          split(investor_data, by = "specification"),
          function(dt) {
            build_portfolio_path(
              data = dt,
              target_vol_annual = target_vol_value,
              max_leverage = max_leverage,
              allow_short = allow_short
            )
          }
        ),
        fill = TRUE
      )
    }
  ),
  fill = TRUE
)

utility_table <- rbindlist(
  lapply(
    split(portfolio_paths, by = c("specification", "target_vol_annual"), keep.by = TRUE),
    summarise_utility
  ),
  fill = TRUE
)

utility_table[, sharpe_gain_vs_har := sharpe - sharpe[specification == "HAR"], by = target_vol_annual]
utility_table[, terminal_wealth_gain_vs_har := terminal_wealth - terminal_wealth[specification == "HAR"], by = target_vol_annual]

utility_gain_table <- rbindlist(
  lapply(
    utility_gamma_grid,
    function(gamma_value) {
      out <- copy(utility_table)
      out[, utility_gamma := gamma_value]
      out[, cer_monthly := mean_return - 0.5 * utility_gamma * var_return]
      out[, cer_annualized := 12 * cer_monthly]
      out[, cer_gain_vs_har_annualized := cer_annualized - cer_annualized[specification == "HAR"], by = .(target_vol_annual, utility_gamma)]
      out[]
    }
  ),
  fill = TRUE
)

cer_gain_plot <- ggplot(
  utility_gain_table[specification != "HAR"],
  aes(x = utility_gamma, y = cer_gain_vs_har_annualized, color = specification)
) +
  geom_hline(yintercept = 0, color = "grey70", linewidth = 0.4) +
  geom_line(linewidth = 0.85, alpha = 0.9) +
  geom_point(size = 1.5) +
  facet_wrap(~ target_vol_annual, scales = "free_y") +
  labs(
    title = "Volatility-Timing Utility Gain vs HAR",
    subtitle = "Market-exposure sizing rule from script01: weight = target monthly vol / forecast vol",
    x = "Risk aversion gamma",
    y = "CER gain vs HAR (annualized)",
    color = NULL
  ) +
  theme_minimal(base_size = 12) +
  theme(
    legend.position = "bottom",
    panel.grid.minor = element_blank(),
    plot.title = element_text(face = "bold")
  )

wealth_plot <- ggplot(
  portfolio_paths[specification %in% c("HAR", "ENET HAR + Option", "RF HAR + Option", "EW Across ML HAR + Option", "Stacked ENET") & target_vol_annual == 0.15],
  aes(x = month, y = cumulative_wealth, color = specification)
) +
  geom_line(linewidth = 0.85, alpha = 0.9) +
  labs(
    title = "Volatility-Timing Wealth Paths",
    subtitle = "Target annual volatility = 15%",
    x = NULL,
    y = "Cumulative wealth",
    color = NULL
  ) +
  theme_minimal(base_size = 12) +
  theme(
    legend.position = "bottom",
    panel.grid.minor = element_blank(),
    plot.title = element_text(face = "bold")
  )

utility_table_out <- file.path(
  config$paths$results_dir,
  "har_augmented_common155_vol_timing_utility_table.csv"
)
utility_gain_out <- file.path(
  config$paths$results_dir,
  "har_augmented_common155_vol_timing_utility_gain.csv"
)
cer_gain_plot_out <- file.path(
  config$paths$output_dir,
  "har_augmented_common155_vol_timing_cer_gain.png"
)
wealth_plot_out <- file.path(
  config$paths$output_dir,
  "har_augmented_common155_vol_timing_wealth.png"
)

fwrite(utility_table, utility_table_out)
fwrite(utility_gain_table, utility_gain_out)
ggsave(cer_gain_plot_out, cer_gain_plot, width = 12, height = 8, dpi = 300)
ggsave(wealth_plot_out, wealth_plot, width = 11, height = 6, dpi = 300)

message("Saved vol-timing utility table to: ", utility_table_out)
message("Saved vol-timing utility gain table to: ", utility_gain_out)
message("Saved vol-timing CER gain plot to: ", cer_gain_plot_out)
message("Saved vol-timing wealth plot to: ", wealth_plot_out)
print(
  utility_gain_table[
    target_vol_annual == 0.15 & utility_gamma %in% c(1, 3, 5, 10),
    .(specification, utility_gamma, cer_annualized, cer_gain_vs_har_annualized)
  ][order(utility_gamma, -cer_gain_vs_har_annualized)]
)
