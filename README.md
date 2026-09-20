# Replication package

**Diversification, Growth, and Stability in Local Fishing Economies**
Kyumin Kim and Matthew N. Reimer · University of California, Davis

Everything in the paper is built from four public CSV files by one command:

```bash
./run_all.sh                 # ~15 min; add RUN_BAYES=1 for Table S6 (~20 min)
```

That runs the Stata stage, then the R stage, and writes every figure into
`output/figures/` and every saved estimate into `output/estimates/`. If Stata is
not on your path, pass it: `STATA=/path/to/stata-mp ./run_all.sh`.

**Prefer to drive it from Stata itself?** Change directory into this folder first —
every path in the package is relative to it:

```stata
cd "/path/to/replication_package"
do code/stata/00_master.do
```

`00_master.do` also finds the root on its own if you launch it from anywhere inside
the package, and stops with an instruction rather than a cryptic error if it cannot.

---

## 1. What you need

| | Version used | Notes |
|---|---|---|
| Stata | 17.0 MP | `version 17` set in every do-file |
| R | 4.5.3 | `install.packages("renv"); renv::restore()` |
| JAGS | 4.3.2 | only for Table S6 |

Stata packages (`sfcross`, `parmest`, `mat2txt`, `estout`) are **bundled** in
`code/ado/` and take precedence, so no SSC access is required. `00_master.do`
still checks and names anything missing.

**JAGS on Apple Silicon.** The CRAN binary of `rjags` looks for
`/usr/local/lib/libjags.4.dylib` while Homebrew installs to `/opt/homebrew/lib`,
and fails with `Library not loaded`. Build from source:

```r
install.packages("rjags", type = "source",
  configure.args = "--with-jags-include=/opt/homebrew/include/JAGS --with-jags-lib=/opt/homebrew/lib")
```

## 2. Data

All inputs are public and ship in `data/raw/`. Nothing writes to that folder.

| File | Source |
|---|---|
| `akfish-data-CFECpermits.csv` | Alaska Commercial Fisheries Entry Commission permit records |
| `employment-by-industry-community-and-year.csv` | Alaska Local and Regional Information (ALARI) |
| `employment-summary-data-by-community-and-year.csv` | ALARI |
| `Total_pop.csv` | Alaska Dept. of Labor population estimates |

Study period 2000–2016; analysis sample 177 communities.

## 3. What produces what

| Exhibit | Produced by |
|---|---|
| Table S1 | summary of `data/derived/master_local_fish_max.dta` |
| Table S2, Table S5 | `code/stata/21_ehdf_nmrt.do` |
| Table S3 | `code/stata/20_ehdf_main.do` |
| Table S4 | `code/stata/22_robustness_hhi.do` |
| Table S6 | `code/stata/39_panel_export_for_bayes.do` → `code/R/14_tableS6_bayesian.R` |
| In-text estimates | `code/stata/26_hdf_mrt.do` |
| Fig. 1 | `code/R/15_fig1_ak_overview.R` |
| Fig. 2 | `code/R/13_fig2_sector_composition.R` |
| Fig. 3a, 3b | `code/R/11_fig3_frontier_concept.R` |
| Fig. 4, Fig. S.2 | `code/R/12_fig4_figS2_frontier_quantiles.R` |
| Fig. 5 | `code/R/16_fig5_mrt_marginal_panels.R` |
| Fig. 6 | `code/R/17_fig6_mrt_substitution.R` |
| Fig. S.1 | `code/R/10_figS1_diversification_trend.R` |

Stata tables are read from `logs/00_master.log`; the estimates behind them are
also saved under `output/estimates/`.

## 4. Execution order

| Range | Stage |
|---|---|
| `01`–`12` | Build `master_local_fish_max.dta` from the raw CSVs. Order matters. |
| `20`–`26` | EHDF estimation, marginal effects, MRT grids. Re-runnable once the master file exists. |
| `30`–`39` | Two-period panel. Only Table S6 uses it. |
| `10`–`17` (R) | Figures and the Bayesian check. Read only what Stata leaves behind. |

To run the stages separately:

```bash
export REPLICATION_ROOT="$PWD"
stata-mp -b do code/stata/00_master.do
Rscript code/R/00_run_all_R.R
```

Stata exits 0 even on error, so `run_all.sh` greps the log for `r(###);` and
fails the run itself if anything appears.

## 5. Notes for a replicator

**The estimation sample is 177, not 179.** The `keep if` at the top of each
estimation file leaves 179 rows; `sfcross` then drops rows with any missing
regressor. `12_build_master.do` asserts 177 so a later edit cannot change the
sample silently.

**R reads its coefficients from Stata.** `24_export_coefficients.do` writes
`output/estimates/ehdf_spec3_coefficients.csv`, which the frontier-quantile
figures read. Nothing is transcribed by hand.

**Table S6 is MCMC.** `set.seed(123)` is set, but JAGS is not bit-identical across
platforms. Judge agreement within Monte Carlo error: posterior means and SDs moving
in the second or third decimal is expected; signs and credible-interval coverage
should match. Across four independent runs here, the population coefficient came out
2.772, 2.772, 2.779 and 2.784 against the published 2.775.

**One earlier specification is carried along.** `25_marginal_effects.do` also
produces a legacy version of the frontier estimates that the paper does not report.

## 6. Layout

```
run_all.sh          single entry point
config/             paths.do, paths.R -- no absolute paths anywhere
data/raw/           the four public CSVs (inputs; never written to)
data/derived/       built by code
code/stata/         00_master.do + 29 numbered do-files
code/R/             00_run_all_R.R + 8 figure/table scripts
code/ado/           bundled Stata packages
output/             estimates, tables, figures
logs/               00_master.log and one log per R script
```

## 7. Licence

Everything here — code, data, and outputs — is released under CC BY 4.0; see `LICENSE`.
The four raw CSVs are public records of the State of Alaska, redistributed unmodified so
the package runs without any external download.

---

Run on macOS 15 (Apple Silicon), Stata/MP 17.0, R 4.5.3, JAGS 4.3.2.
