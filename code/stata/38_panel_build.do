*-------------------------------------------------------------------------------
* Filename:     38_panel_build.do
* Purpose:      Merge the two-period panel pieces into complete_panel_dataset.dta.
* Inputs:       the $DERIVED panel pieces built by 30-37
* Outputs:      $DERIVED/complete_panel_dataset.dta
* Requires:     Stata 17+, config/paths.do already included by 00_master.do
* Author:       Kim
*               Ported for the replication package 2026; ONLY paths and this
*               header were changed. Estimation logic is byte-for-byte original
*               except where a line is marked RESTORED / ADDED.
*-------------------------------------------------------------------------------
version 17
set more off

***************************************************************************
********************* Panel Structure Synthesizing ************************
***************************************************************************



clear 
* NOTE: original `global inpath ...` removed; paths come from config/paths.do

* Load Growth and Instability Data
use "$DERIVED/growth_and_instability_emp_reg_panel_twoperiod.dta", clear

* Merge Diversification Measure by Difference
merge m:1 city period using "$DERIVED/diversity_emp_diff_panel_twoperiod.dta"
drop _merge

* Merge Population Data
merge m:1 city period using "$DERIVED/avg_pop_panel_twoperiod.dta"
drop _merge

* Merge Regional Employment Share
merge m:1 city period using "$DERIVED/regional_emp_share_panel_twoperiod.dta"
drop _merge

* Merge Average Wage Income Data
merge m:1 city period using "$DERIVED/avg_wage_income_panel_twoperiod.dta"
drop _merge

* Merge Spatial Share of Fishing Permit
merge m:1 city period using "$DERIVED/regional_permit_share_max_panel_twoperiod.dta"
drop _merge

* Merge Fish Diversification Information
merge m:1 city period using "$DERIVED/diversith_fish_max_panel_twoperiod.dta"
drop _merge

* Merg avg fishery revenue income ratio

merge m:1 city period using "$DERIVED/avg_fish_ratio_im_panel_twoperiod"
drop _merge


///////// need to drop variables. 

* Additional calculations (if necessary) such as wage per capita, fishing revenue growth
* Assuming the necessary data for these calculations are already in the merged dataset

* Calculate average wage per capita
gen avg_wage_pc = avg_wincome / avg_pop
label variable avg_wage_pc "Average wage income per capita"

* Log-transformations for large scale variables
gen l_avg_wage_pc = log(avg_wage_pc + 1) // Adding 1 to handle cases where avg_wage_pc is zero
gen l_avg_pop = log(avg_pop + 1) // Same reason as above

*Urbanity dummy (if data on community census area names is present in the dataset by the standard of OMB)
rename community__census_area__name community_census_area

gen urbanity = inlist(community_census_area, "Fairbanks North Star Borough", "Matanuska-Susitna Borough", "Anchorage Municipality", "Juneau City and Borough")

* Save the final merged dataset
save "$DERIVED/complete_panel_dataset.dta", replace
