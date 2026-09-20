# paths.R: project directories, resolved from the package root.
# Sourced by code/R/setup.R.

ROOT <- Sys.getenv("REPLICATION_ROOT", unset = NA_character_)
if (is.na(ROOT) || ROOT == "") ROOT <- here::here()

RAW       <- file.path(ROOT, "data", "raw")
DERIVED   <- file.path(ROOT, "data", "derived")
ESTIMATES <- file.path(ROOT, "output", "estimates")
TABLES    <- file.path(ROOT, "output", "tables")
FIGURES   <- file.path(ROOT, "output", "figures")

if (!dir.exists(RAW)) stop("Cannot find data/raw under ROOT = ", ROOT)
if (!dir.exists(DERIVED) || length(list.files(DERIVED, pattern = "\\.dta$")) == 0L) {
  warning("data/derived is empty. Run the Stata stage (code/stata/00_master.do) first.")
}
for (d in c(DERIVED, ESTIMATES, TABLES, FIGURES)) dir.create(d, recursive = TRUE, showWarnings = FALSE)
