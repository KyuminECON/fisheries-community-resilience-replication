#-------------------------------------------------------------------------------
# Filename:     config/paths.R
# Purpose:      Resolve every package directory from the project root so the R
#               figure scripts never carry an absolute path.
# Inputs:       none
# Outputs:      objects ROOT, RAW, DERIVED, ESTIMATES, TABLES, FIGURES
# Requires:     here
# Author:       Replication package build, 2026
#
# WHY here::here(): the original scripts used setwd() to a Google Drive path,
# which is the single biggest portability failure in the source material.
#-------------------------------------------------------------------------------

## ===========================================================================
## Setup
## ===========================================================================
if (!requireNamespace("here", quietly = TRUE)) {
  stop("Package 'here' is required. Run: install.packages('here')")
}

ROOT <- Sys.getenv("REPLICATION_ROOT", unset = NA_character_)
if (is.na(ROOT) || ROOT == "") ROOT <- here::here()

## ===========================================================================
## Derived paths
## ===========================================================================
RAW       <- file.path(ROOT, "data", "raw")
DERIVED   <- file.path(ROOT, "data", "derived")
ESTIMATES <- file.path(ROOT, "output", "estimates")
TABLES    <- file.path(ROOT, "output", "tables")
FIGURES   <- file.path(ROOT, "output", "figures")

## ===========================================================================
## Checks
## ===========================================================================
if (!dir.exists(RAW)) {
  stop("Cannot find data/raw under ROOT = ", ROOT,
       "\nSet REPLICATION_ROOT or open the .Rproj at the package root.")
}

# The Stata stage must run first: R reads what Stata writes.
if (!dir.exists(DERIVED) || length(list.files(DERIVED, pattern = "\\.dta$")) == 0L) {
  warning("data/derived is empty. Run the Stata stage (code/stata/00_master.do) first.")
}

for (d in c(DERIVED, ESTIMATES, TABLES, FIGURES)) {
  if (!dir.exists(d)) dir.create(d, recursive = TRUE, showWarnings = FALSE)
}

message("paths.R: ROOT = ", ROOT)
