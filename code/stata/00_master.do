*-------------------------------------------------------------------------------
* Filename:     00_master.do
* Purpose:      Single entry point for the Stata half of the replication.
*               Builds every derived dataset from the four raw CSVs, then runs
*               the EHDF estimations that the paper reports.
* Inputs:       the four raw CSVs in data/raw
* Outputs:      derived .dta files, saved estimates, and run logs
* Requires:     Stata 17+; SSC: sfcross, parmest, mat2txt, estout
* Author:       Replication package build, 2026
*
* WHY the numbering: 01-12 construct data and must run in order (each merges the
* previous outputs). 20-24 estimate and may be re-run independently once the
* master file exists. R reads only what 20-24 leave behind.
*
* NOTE: do NOT `set varabbrev off` here. The original data-construction code
* relies on abbreviation (e.g. `long` for `longitude` in 02_geography_longlat),
* so turning it off changes behaviour rather than merely tightening it.
*-------------------------------------------------------------------------------

*==============================================================================*
* Setup
*==============================================================================*
clear all
version 17
set more off

*------------------------------------------------------------------------------
* Find the package root before anything else.
*
* WHY: every path below is relative, and Stata resolves relative paths against the
* working directory -- wherever Stata happens to be, not where this file lives.
* Stata gives a do-file no way to learn its own path, so we look for the root:
*   1. the REPLICATION_ROOT environment variable, if set (run_all.sh sets it)
*   2. the current directory, or any parent, that contains config/paths.do
* If neither works we stop with an instruction, not a cryptic "file not found".
*------------------------------------------------------------------------------
local root : environment REPLICATION_ROOT
if `"`root'"' == "" {
    local try "`c(pwd)'"
    forvalues up = 1/6 {
        capture confirm file `"`try'/config/paths.do"'
        if !_rc {
            local root `"`try'"'
            continue, break
        }
        local try = regexr(`"`try'"', "/[^/]+$", "")
        if `"`try'"' == "" continue, break
    }
}
if `"`root'"' == "" {
    display as error "{hline 78}"
    display as error "Cannot find the replication package root."
    display as error ""
    display as error "Stata is currently in:  `c(pwd)'"
    display as error ""
    display as error "Run the package from its own folder. In Stata:"
    display as error `"    cd "/path/to/replication_package""'
    display as error "    do code/stata/00_master.do"
    display as error ""
    display as error "or, from a terminal:  ./run_all.sh"
    display as error "{hline 78}"
    exit 601
}
quietly cd `"`root'"'
display as text "Package root: `c(pwd)'"

do "config/paths.do"


capture log close _all
log using "$LOGS/00_master.log", replace text name(master)

display as text "{hline 78}"
display as text "Replication: Diversification, Growth, and Stability in Local Fishing Economies"
display as text "Started: `c(current_date)' `c(current_time)'   Stata `c(stata_version)' `c(flavor)'"
display as text "{hline 78}"

*==============================================================================*
* Parameters
*==============================================================================*
* Nothing stochastic runs in Stata (sfcross is deterministic given the data and
* the technique sequence), but the seed is fixed anyway so that any future
* bootstrap or simulation added here is reproducible.
set seed 20260915

* Expected estimation sample. The do-files' own `keep if` leaves 179 rows; the
* published sample is the complete-case subset across every frontier and usigma
* regressor, which is 177. Asserted in 12_build_master.do.
global N_ESTIMATION 177

*==============================================================================*
* Dependency check
*==============================================================================*
foreach pkg in sfcross parmest mat2txt {
    capture which `pkg'
    if _rc {
        display as error "Missing Stata package: `pkg'"
        display as error "Install with:  ssc install `pkg'"
        exit 111
    }
}

*==============================================================================*
* Main: data construction (order matters)
*==============================================================================*
local BUILD ///
    01_prep_demographics         ///
    02_geography_longlat         ///
    03_growth_instability_base   ///
    04_growth_instability_geom   ///
    05_diversification_sectoral  ///
    06_regional_emp_share        ///
    07_regional_permit_share     ///
    08_diversification_fisheries ///
    09_fish_wage_ratio           ///
    10_imputation_earning        ///
    11_fishermen                 ///
    12_build_master

foreach f of local BUILD {
    display as text _n "{hline 78}"
    display as text ">>> BUILD  `f'"
    display as text "{hline 78}"
    do "$CODE/stata/`f'.do"
}

*==============================================================================*
* Main: estimation
*==============================================================================*
local ESTIMATE ///
    20_ehdf_main            ///
    21_ehdf_nmrt            ///
    22_robustness_hhi       ///
    23_export_r_plot        ///
    24_export_coefficients  ///
    25_marginal_effects     ///
    26_hdf_mrt

*------------------------------------------------------------------------------
* Two-period panel, used only by Table S6 (Bayesian Mundlak-Chamberlain check).
* Built from the same four raw CSVs; independent of the cross-section above.
*------------------------------------------------------------------------------
local PANEL ///
    30_panel_growth_instability   ///
    31_panel_diversification_emp  ///
    32_panel_population           ///
    33_panel_wage_income          ///
    34_panel_regional_emp_share   ///
    35_panel_regional_permit_share ///
    36_panel_diversification_fish ///
    37_panel_fish_ratio           ///
    38_panel_build                ///
    39_panel_export_for_bayes

foreach f of local ESTIMATE {
    display as text _n "{hline 78}"
    display as text ">>> ESTIMATE  `f'"
    display as text "{hline 78}"
    do "$CODE/stata/`f'.do"
}

foreach f of local PANEL {
    display as text _n "{hline 78}"
    display as text ">>> PANEL  `f'"
    display as text "{hline 78}"
    do "$CODE/stata/`f'.do"
}

*==============================================================================*
* Checks
*==============================================================================*
* Every artefact the R stage consumes must exist before R is allowed to run.
foreach f in ///
    "$DERIVED/master_local_fish_max.dta"        ///
    "$DERIVED/R_plot.dta"                       ///
    "$ESTIMATES/frontier_spec3.ster"            ///
    "$ESTIMATES/NMRT_quantile_tests.dta"        ///
    "$ESTIMATES/NMRT_quantile_tests_x3.dta"     ///
    "$ESTIMATES/NMRT_contrasts_x3.dta"          ///
    "$ESTIMATES/NMRT_contrasts_x4.dta"          ///
    "$ESTIMATES/ehdf_spec3_coefficients.csv"    ///
    "$DERIVED/marginal_effect_EHDF.dta"         ///
    "$DERIVED/processed_dataset.csv"            ///
    "$DERIVED/df_plot.dta"                      ///
    "$ESTIMATES/MRT_emp_fish_5-95.dta"          ///
    "$ESTIMATES/MRT_emp_fish.dta" {
    capture confirm file "`f'"
    if _rc {
        display as error "Expected output missing: `f'"
        exit 601
    }
    display as text "  present: `f'"
}

display as text _n "{hline 78}"
display as text "Stata stage complete: `c(current_date)' `c(current_time)'"
display as text "Next: Rscript code/R/00_run_all_R.R"
display as text "{hline 78}"

log close master
