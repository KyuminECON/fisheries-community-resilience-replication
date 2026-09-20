# Replication package

**Diversification, Growth, and Stability in Local Fishing Economies**
Kyumin Kim and Matthew N. Reimer, University of California, Davis

All results are built from four public CSV files:

```bash
./run_all.sh                 # about 15 minutes
RUN_BAYES=1 ./run_all.sh     # also runs the Bayesian check for Table S6 (about 20 minutes)
STATA=/path/to/stata ./run_all.sh
```

The package ships with only code and raw data; `data/derived/`, `output/` and `logs/` are empty until you run it. The script runs the Stata stage, then the R stage. Figures are written to `output/figures/`, LaTeX table bodies to `output/tables/`, and saved estimates to `output/estimates/`. To run Stata alone, change to the package root and run `do code/stata/00_master.do`.

## 1. Requirements

| Software | Notes |
|---|---|
| Stata 17 or later | `sfcross`, `parmest`, `mat2txt` and `estout` are bundled in `code/ado/` |
| R 4.4 or later | `here`, `tidyverse`, `haven`, `sf`, `patchwork`, `viridis`, `rnaturalearthdata`, `isoband`, `plot3D`; `rjags` and `coda` for Table S6 |
| JAGS 4.3 | Table S6 only. `rjags` 4-17 does not build against JAGS 5, so install 4.3.x (Homebrew currently ships 5) |

On Apple Silicon, the CRAN binary of `rjags` may fail to find `libjags`. Build it from source:

```r
install.packages("rjags", type = "source",
  configure.args = "--with-jags-include=/opt/homebrew/include/JAGS --with-jags-lib=/opt/homebrew/lib")
```

## 2. Data

All inputs are in `data/raw/` and are never modified.

| File | Source |
|---|---|
| `akfish-data-CFECpermits.csv` | Alaska Commercial Fisheries Entry Commission permit records |
| `employment-by-industry-community-and-year.csv` | Alaska Local and Regional Information (ALARI) |
| `employment-summary-data-by-community-and-year.csv` | ALARI |
| `Total_pop.csv` | Alaska Department of Labor population estimates (population sheet extracted from the source workbook) |

Study period 2000–2016; estimation sample 177 communities.

## 3. Exhibits

| Exhibit | Produced by |
|---|---|
| Tables S1–S5 | `code/stata/22_tables.do`, from the estimates saved by `20_estimate_frontiers.do` and `21_mrt.do` |
| Table S6 | `code/stata/39_panel_export_for_bayes.do`, then `code/R/14_tableS6_bayesian.R` |
| In-text MRT estimates | `code/stata/21_mrt.do` |
| Fig. 1 | `code/R/15_fig1_ak_overview.R` |
| Fig. 2 | `code/R/13_fig2_sector_composition.R` |
| Fig. 3 | `code/R/11_fig3_frontier_concept.R` (illustrative; not estimated) |
| Fig. 4, Fig. S2 | `code/R/12_fig4_figS2_frontier_quantiles.R` |
| Fig. 5 | `code/R/16_fig5_mrt_marginal_panels.R` |
| Fig. 6 | `code/R/17_fig6_mrt_substitution.R` |
| Fig. S1 | `code/R/10_figS1_diversification_trend.R` |

The manuscript in `paper/` reads its figures from `output/figures/` and its tables from `output/tables/`, so run the package before compiling it.

## 4. Structure

| Script | Stage |
|---|---|
| `code/stata/01`–`12` | Build `master_local_fish_max.dta` from the raw CSVs (order matters) |
| `code/stata/20` | Estimates every frontier specification once and saves the estimation sample |
| `code/stata/21` | MRT, its elasticities, and percentile grids, from the saved spec 3 estimates |
| `code/stata/22` | Table bodies |
| `code/stata/30`–`39` | Two-period panel, used only for Table S6 |
| `code/R/10`–`17` | Figures and the Bayesian check |
| `code/R/setup.R`, `config/` | Paths and shared packages |

`code/ado/ehdf_prep.ado` builds the normalized variables and translog terms shared by the estimation scripts.

## 5. Notes

- The `keep if` in `20_estimate_frontiers.do` leaves 179 rows; `sfcross` drops those with a missing regressor, leaving 177 (asserted). Variables are normalized on the 179 rows, the frontiers are estimated once, and `estimation_sample.dta` (the 177 communities, with the normalized variables) is what every later script and all figures use, including the percentiles of diversification.
- All MRT quantities (Tables S2 and S5, the elasticities, the cross-partial, and Figs. 5 and 6) are computed by the same analytic formula from the spec 3 estimates, with all other log regressors at zero, so Table S5 is the middle row and column of the Fig. 6b grid.
- Table S6 uses MCMC. `set.seed(123)` is set, but JAGS is not bit-identical across platforms; posterior means and SDs should agree to the second or third decimal.
- `logs/` holds `00_master.log` and one log per R script.

## 6. Licence

Code is MIT, outputs and the manuscript are CC BY 4.0, the raw data follow the issuing agencies' terms, and the bundled Stata packages in `code/ado/` keep their authors' terms. See `LICENSE`.
