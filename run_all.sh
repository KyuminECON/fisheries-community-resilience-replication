#!/usr/bin/env bash
#-------------------------------------------------------------------------------
# Filename:     run_all.sh
# Purpose:      Single entry point. Runs the Stata stage, then the R stage.
# Inputs:       data/raw/ (four CSVs, shipped with the package)
# Outputs:      data/derived/, output/estimates/, output/figures/, logs/
# Requires:     Stata 17+ with sfcross/parmest/mat2txt/estout; R 4.5+; JAGS
#               (JAGS only for the optional Table S6 step)
# Author:       Replication package build, 2026
#
# Usage:
#   ./run_all.sh                 # everything except the long Bayesian check
#   RUN_BAYES=1 ./run_all.sh     # include Table S6 (3 chains x 800k iterations)
#   STATA=/path/to/stata-mp ./run_all.sh
#-------------------------------------------------------------------------------
set -euo pipefail

#==============================================================================#
# Setup
#==============================================================================#
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export REPLICATION_ROOT="$ROOT"
cd "$ROOT"
mkdir -p logs data/derived output/estimates output/tables output/figures

# Stata has no single canonical binary name; allow an override and try the
# common ones. The batch flag differs on Windows, which this script does not target.
STATA="${STATA:-}"
if [[ -z "$STATA" ]]; then
  for c in \
    /Applications/Stata/StataMP.app/Contents/MacOS/stata-mp \
    /Applications/Stata/StataSE.app/Contents/MacOS/stata-se \
    /Applications/Stata/StataBE.app/Contents/MacOS/stata-be \
    stata-mp stata-se stata-be stata
  do
    if command -v "$c" >/dev/null 2>&1 || [[ -x "$c" ]]; then STATA="$c"; break; fi
  done
fi
if [[ -z "$STATA" ]]; then
  echo "ERROR: Stata not found. Set STATA=/path/to/stata-mp and re-run." >&2
  exit 1
fi

RSCRIPT="${RSCRIPT:-Rscript}"
command -v "$RSCRIPT" >/dev/null 2>&1 || { echo "ERROR: Rscript not found." >&2; exit 1; }

echo "=============================================================="
echo "Replication: Diversification, Growth, and Stability"
echo "  root   : $ROOT"
echo "  stata  : $STATA"
echo "  R      : $($RSCRIPT --version 2>&1 | head -1)"
echo "  started: $(date)"
echo "=============================================================="

#==============================================================================#
# Main: Stata stage
#==============================================================================#
echo
echo ">>> STAGE 1/2  Stata"
# Run from the package root: 00_master.do resolves config/paths.do relatively,
# and a relative do-file path avoids the spaces that this directory name contains
# (Stata's batch parser drops quotes and would read "and" as an option).
# Stata returns 0 even on error, so the log is inspected below instead.
"$STATA" -b do code/stata/00_master.do || true
# -b leaves its own transcript in the working directory; keep it out of the way.
[[ -f 00_master.log ]] && mv -f 00_master.log logs/00_master_batch.log

MASTER_LOG="logs/00_master.log"
if [[ ! -f "$MASTER_LOG" ]]; then
  echo "ERROR: $MASTER_LOG was not written; Stata did not start." >&2
  exit 1
fi
if grep -qE '^r\([0-9]+\);' "$MASTER_LOG"; then
  echo "ERROR: the Stata stage reported errors:" >&2
  grep -nE -B4 '^r\([0-9]+\);' "$MASTER_LOG" | tail -20 >&2
  exit 1
fi
echo "  Stata stage OK"

#==============================================================================#
# Main: R stage
#==============================================================================#
echo
echo ">>> STAGE 2/2  R"
"$RSCRIPT" code/R/00_run_all_R.R

#==============================================================================#
# Checks
#==============================================================================#
echo
echo "=============================================================="
echo "Derived datasets : $(ls data/derived/*.dta 2>/dev/null | wc -l | tr -d ' ')"
echo "Saved estimates  : $(ls output/estimates/* 2>/dev/null | wc -l | tr -d ' ')"
echo "Figures          : $(ls output/figures/*.png 2>/dev/null | wc -l | tr -d ' ')"
echo "finished: $(date)"
echo "=============================================================="
