#!/usr/bin/env bash
# run_all.sh: runs the Stata stage, then the R stage.
# Inputs:  data/raw/
# Outputs: data/derived/, output/estimates/, output/figures/, logs/
# Usage:   ./run_all.sh                  (skips the long Bayesian run for Table S6)
#          RUN_BAYES=1 ./run_all.sh      (includes Table S6)
#          STATA=/path/to/stata ./run_all.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export REPLICATION_ROOT="$ROOT"
cd "$ROOT"
mkdir -p logs data/derived output/estimates output/tables output/figures

if [[ -z "${STATA:-}" ]]; then
  for c in \
    /Applications/Stata/StataMP.app/Contents/MacOS/stata-mp \
    /Applications/Stata/StataSE.app/Contents/MacOS/stata-se \
    /Applications/Stata/StataBE.app/Contents/MacOS/stata-be \
    stata-mp stata-se stata-be stata
  do
    if command -v "$c" >/dev/null 2>&1 || [[ -x "$c" ]]; then STATA="$c"; break; fi
  done
fi
[[ -n "${STATA:-}" ]] || { echo "ERROR: Stata not found. Set STATA=/path/to/stata." >&2; exit 1; }
command -v Rscript >/dev/null 2>&1 || { echo "ERROR: Rscript not found." >&2; exit 1; }

echo ">>> Stata stage"
# Stata returns 0 even on error, so the log is checked below.
"$STATA" -b do code/stata/00_master.do || true
[[ -f 00_master.log ]] && mv -f 00_master.log logs/00_master_batch.log

if [[ ! -f logs/00_master.log ]]; then
  echo "ERROR: logs/00_master.log was not written; Stata did not start." >&2
  exit 1
fi
if grep -qE '^r\([0-9]+\);' logs/00_master.log; then
  echo "ERROR: the Stata stage reported errors:" >&2
  grep -nE -B4 '^r\([0-9]+\);' logs/00_master.log | tail -20 >&2
  exit 1
fi

echo ">>> R stage"
Rscript code/R/00_run_all_R.R
