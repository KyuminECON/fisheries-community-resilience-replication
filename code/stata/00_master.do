*-------------------------------------------------------------------------------
* 00_master.do: runs the full Stata stage (data construction, estimation, panel).
* Inputs:  the four raw CSVs in data/raw
* Outputs: derived datasets in data/derived, saved estimates in output/estimates, logs/00_master.log
* Run from the package root, or set REPLICATION_ROOT.
*-------------------------------------------------------------------------------

*==============================================================================*
* Setup
*==============================================================================*
clear all
version 17
set more off

* Package root: REPLICATION_ROOT, else the current directory or a parent containing config/paths.do
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
    display as error "Cannot find the replication package root. Run from the package folder:"
    display as error `"    cd "/path/to/replication_package""'
    display as error "    do code/stata/00_master.do"
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

* Stata's sort breaks ties at random; fixing the seed keeps row order reproducible
set seed 20260915

*==============================================================================*
* Main
*==============================================================================*
* Data construction (order matters), estimation, two-period panel (Table S6 only), tables
local SCRIPTS ///
    01_prep_demographics          ///
    02_geography_longlat          ///
    03_growth_instability_base    ///
    04_growth_instability_geom    ///
    05_diversification_sectoral   ///
    06_regional_emp_share         ///
    07_regional_permit_share      ///
    08_diversification_fisheries  ///
    09_fish_wage_ratio            ///
    10_imputation_earning         ///
    11_fishermen                  ///
    12_build_master               ///
    20_estimate_frontiers         ///
    21_mrt                        ///
    22_tables                     ///
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

foreach f of local SCRIPTS {
    display as text _n "{hline 78}"
    display as text ">>> `f'"
    display as text "{hline 78}"
    do "$CODE/stata/`f'.do"
}

*==============================================================================*
* Checks
*==============================================================================*
* Every file the R stage reads must exist
foreach f in ///
    "$DERIVED/estimation_sample.dta"            ///
    "$DERIVED/processed_dataset.csv"            ///
    "$ESTIMATES/ehdf_spec3_coefficients.csv"    ///
    "$ESTIMATES/MRT_emp_fish_5-95.dta"          ///
    "$ESTIMATES/MRT_emp_fish.dta" {
    capture confirm file "`f'"
    if _rc {
        display as error "Expected output missing: `f'"
        exit 601
    }
}

display as text _n "Stata stage complete: `c(current_date)' `c(current_time)'"
log close master
