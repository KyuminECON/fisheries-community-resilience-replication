# setup.R: shared setup sourced by every R script (paths and common packages).
# Requires: .here at the package root, config/paths.R

source(here::here("config", "paths.R"))

suppressPackageStartupMessages({
  library(tidyverse)
  library(haven)
})
