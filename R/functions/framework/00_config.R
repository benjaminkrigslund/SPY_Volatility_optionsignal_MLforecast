create_config <- function(base_dir = getwd()) {
  framework_dir <- file.path(base_dir, "R", "functions", "framework")

  list(
    base_dir = base_dir,
    framework_dir = framework_dir,
    paths = list(
      data_dir = file.path(base_dir, "data", "raw"),
      raw_data_dir = file.path(base_dir, "data", "raw"),
      framework_data_dir = file.path(base_dir, "data", "processed"),
      processed_data_dir = file.path(base_dir, "data", "processed"),
      forecast_panel_dir = file.path(base_dir, "data", "processed", "forecast_panels"),
      results_dir = file.path(base_dir, "data", "processed", "model_artifacts"),
      output_dir = file.path(base_dir, "output", "tables"),
      figures_dir = file.path(base_dir, "output", "figures"),
      diagnostics_dir = file.path(base_dir, "output", "diagnostics"),
      robustness_output_dir = file.path(base_dir, "robustness", "output", "tables"),
      robustness_figures_dir = file.path(base_dir, "robustness", "output", "figures"),
      master_data = file.path(base_dir, "data", "processed", "master_dataset.csv"),
      feature_dictionary = file.path(base_dir, "data", "processed", "master_feature_dictionary.csv")
    ),
    columns = list(
      date = "date",
      target = "rv",
      har = c("har_rv_1m", "har_rv_3m", "har_rv_12m"),
      option = c(
        "implied_var_eom",
        "atm_iv_eom",
        "put_25_iv_eom",
        "call_25_iv_eom",
        "skew_25_eom",
        "downside_skew_eom",
        "smile_curvature_25_eom",
        "skew_10_eom",
        "downside_skew_10_eom",
        "smile_curvature_10_eom",
        "atm_dispersion_eom",
        "put_25_dispersion_eom",
        "mean_dispersion_eom",
        "atm_iv_month_avg",
        "implied_var_month_avg",
        "vrp_forward_eom",
        "vrp_forward_month_avg",
        "skew_25_month_avg",
        "smile_curvature_25_month_avg",
        "mean_dispersion_month_avg"
      ),
      macro = NULL
    ),
    forecasting = list(
      initial_window = 120L,
      refit_every = 12L,
      horizon = 1L,
      window_types = c("rolling", "expanding"),
      target_types = c("level", "log"),
      min_positive_forecast = 1e-6,
      level_floor_train_fraction = 0.5
    ),
    models = list(
      enet = list(alpha = 0.5, nfolds = 10L, always_include = c("har_rv_1m", "har_rv_3m", "har_rv_12m")),
      pca = list(explained_variance = 0.70, min_block_size = 5L),
      pls = list(max_components = NULL, validation = "CV", min_block_size = 5L),
      rf = list(
        num_trees = 500L,
        mtry = NULL,
        min_node_size = 5L,
        importance = "impurity",
        seed = 123
      ),
      nn = list(
        size = 5L,
        decay = 0.01,
        maxit = 500L,
        linout = TRUE,
        trace = FALSE,
        maxnwts = 10000L
      )
    ),
    evaluation = list(
      qlike_epsilon = 1e-8,
      dm_horizon = 1L
    ),
    reporting = list(
      main_window_type = "rolling",
      main_target_type = "log",
      mcs_alpha = 0.10,
      mcs_bootstrap = 500L,
      mcs_statistic = "Tmax"
    ),
    output = list(
      save_csv = TRUE,
      save_rds = TRUE
    )
  )
}
