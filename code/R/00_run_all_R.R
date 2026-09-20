# 00_run_all_R.R: run the R stage (figures, and optionally Table S6) after the Stata stage.
# Inputs:  data/derived/* and output/estimates/* written by code/stata
# Outputs: output/figures/*, logs/*.log
# Set RUN_BAYES=1 to include the long MCMC run for Table S6.

ROOT <- Sys.getenv("REPLICATION_ROOT", unset = NA_character_)
if (is.na(ROOT) || ROOT == "") ROOT <- here::here()
Sys.setenv(REPLICATION_ROOT = ROOT)

LOGS <- file.path(ROOT, "logs")
dir.create(LOGS, showWarnings = FALSE, recursive = TRUE)

SCRIPTS <- c(
  "10_figS1_diversification_trend.R",
  "11_fig3_frontier_concept.R",
  "12_fig4_figS2_frontier_quantiles.R",
  "13_fig2_sector_composition.R",
  "15_fig1_ak_overview.R",
  "16_fig5_mrt_marginal_panels.R",
  "17_fig6_mrt_substitution.R"
)
if (identical(Sys.getenv("RUN_BAYES"), "1")) SCRIPTS <- c(SCRIPTS, "14_tableS6_bayesian.R")

needed <- c(
  file.path("data", "derived", "estimation_sample.dta"),
  file.path("output", "estimates", c("ehdf_spec3_coefficients.csv", "MRT_emp_fish_5-95.dta", "MRT_emp_fish.dta"))
)
missing <- needed[!file.exists(file.path(ROOT, needed))]
if (length(missing)) stop("Run the Stata stage first. Missing: ", paste(missing, collapse = ", "))

failed <- character(0)
for (s in SCRIPTS) {
  message(">>> ", s)
  log <- file.path(LOGS, sub("\\.R$", ".log", s))
  rc <- system2("Rscript", shQuote(file.path(ROOT, "code", "R", s)), stdout = log, stderr = log)
  if (rc != 0L) {
    failed <- c(failed, s)
    message("    FAILED, see ", log)
  }
}

if (length(failed)) {
  message("FAILED: ", paste(failed, collapse = ", "))
  quit(status = 1L)
}
message("R stage complete.")
