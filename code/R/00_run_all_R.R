#-------------------------------------------------------------------------------
# Filename:     00_run_all_R.R
# Purpose:      Run the R half of the replication, in order, after Stata.
# Inputs:       data/derived/* and output/estimates/* written by code/stata
# Outputs:      output/figures/*.png, plus the Table S6 posterior summary in logs/
# Requires:     see renv.lock; JAGS must be installed for 14_tableS6_bayesian.R
# Author:       Replication package build, 2026
#
# WHY a runner instead of one big script: each figure script clears its own
# workspace (rm(list=ls())), which is how the originals were written. Running
# them as separate processes keeps that behaviour and stops one failure from
# taking the rest down.
#-------------------------------------------------------------------------------

## ===========================================================================
## Setup
## ===========================================================================
ROOT <- Sys.getenv("REPLICATION_ROOT", unset = NA_character_)
if (is.na(ROOT) || ROOT == "") ROOT <- here::here()
Sys.setenv(REPLICATION_ROOT = ROOT)

LOGS <- file.path(ROOT, "logs")
dir.create(LOGS, showWarnings = FALSE, recursive = TRUE)

## ===========================================================================
## Parameters
## ===========================================================================
# 14_tableS6_bayesian.R runs 3 chains x 800,000 iterations and takes a long time.
# It is off by default; set RUN_BAYES=1 to include it.
RUN_BAYES <- identical(Sys.getenv("RUN_BAYES"), "1")

SCRIPTS <- c(
  "10_figS1_diversification_trend.R",      # Fig. S.1a, S.1b
  "11_fig3_frontier_concept.R",            # Fig. 3a, 3b
  "12_fig4_figS2_frontier_quantiles.R",    # Fig. 4, Fig. S.2
  "13_fig2_sector_composition.R",          # Fig. 2
  "15_fig1_ak_overview.R",                 # Fig. 1   (Reimer)
  "16_fig5_mrt_marginal_panels.R",         # Fig. 5   (Reimer)
  "17_fig6_mrt_substitution.R"             # Fig. 6   (Reimer)
)
if (RUN_BAYES) SCRIPTS <- c(SCRIPTS, "14_tableS6_bayesian.R")

## ===========================================================================
## Checks
## ===========================================================================
needed <- c(
  file.path(ROOT, "data", "derived", "master_local_fish_max.dta"),
  file.path(ROOT, "data", "derived", "R_plot.dta"),
  file.path(ROOT, "data", "derived", "marginal_effect_EHDF.dta"),
  file.path(ROOT, "output", "estimates", "ehdf_spec3_coefficients.csv"),
  file.path(ROOT, "data", "derived", "df_plot.dta"),
  file.path(ROOT, "output", "estimates", "MRT_emp_fish_5-95.dta"),
  file.path(ROOT, "output", "estimates", "MRT_emp_fish.dta")
)
missing <- needed[!file.exists(needed)]
if (length(missing)) {
  stop("The Stata stage has not been run. Missing:\n  ",
       paste(basename(missing), collapse = "\n  "),
       "\nRun: code/stata/00_master.do")
}

## ===========================================================================
## Main
## ===========================================================================
failed <- character(0)
for (s in SCRIPTS) {
  message("\n", strrep("-", 70), "\n>>> ", s, "\n", strrep("-", 70))
  log <- file.path(LOGS, sub("\\.R$", ".log", s))
  rc <- system2("Rscript", shQuote(file.path(ROOT, "code", "R", s)),
                stdout = log, stderr = log)
  if (rc != 0L) {
    failed <- c(failed, s)
    message("  FAILED (exit ", rc, ") -- see ", log)
  } else {
    message("  ok")
  }
}

## ===========================================================================
## Export summary
## ===========================================================================
figs <- list.files(file.path(ROOT, "output", "figures"), pattern = "\\.png$")
message("\n", strrep("=", 70))
message("Figures written to output/figures (", length(figs), "):")
for (f in sort(figs)) message("  ", f)
if (!RUN_BAYES) {
  message("\nTable S6 not run. Set RUN_BAYES=1 to include it (long MCMC).")
}
if (length(failed)) {
  message("\nFAILED: ", paste(failed, collapse = ", "))
  quit(status = 1L)
}
message("R stage complete.")
