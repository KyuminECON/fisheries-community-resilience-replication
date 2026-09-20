*-------------------------------------------------------------------------------
* Filename:     33_panel_wage_income.do
* Purpose:      Two-period panel: wage income per capita.
* Inputs:       $RAW/employment-summary-data-by-community-and-year.csv
* Outputs:      $DERIVED/wages_year_city_panel_twoperiod.dta
* Requires:     Stata 17+, config/paths.do already included by 00_master.do
* Author:       Kim
*               Ported for the replication package 2026; ONLY paths and this
*               header were changed. Estimation logic is byte-for-byte original
*               except where a line is marked RESTORED / ADDED.
*-------------------------------------------------------------------------------
version 17
set more off

************************************************************
****** Average Income related data for twoperiod panel structure ****
******** Kyumin Kim / Matt Reimer **********************************************
********************************************************************************
*********************************************************



clear
set more off
* NOTE: original `global inpath ...` removed; paths come from config/paths.do

* Define a program to create average wage and employment data for specified periods
capture program drop create_avg_wage
program define create_avg_wage
    args labelname startyear endyear
    preserve
    insheet using "$RAW/employment-summary-data-by-community-and-year.csv", comma clear
    keep if periodyear >= `startyear' & periodyear <= `endyear'
    rename community__name city
    rename periodyear year 

    * Creating avg_wage_income dataset
    collapse (mean) avg_wincome=wages avg_emp=emp , by(city)
    label variable avg_wincome "Average wage income for community (`startyear'-`endyear')"
    label variable avg_emp "Average number of employment for community (`startyear'-`endyear')"
    gen period = `labelname'  // Label the dataset with the time period
    save "$DERIVED/avg_wage_income_period`labelname'.dta", replace

    * Re-load for wages_year_city dataset
    insheet using "$RAW/employment-summary-data-by-community-and-year.csv", comma clear
    keep if periodyear >= `startyear' & periodyear <= `endyear'
    rename community__name city
    rename periodyear year
	gen period= `labelname'
    keep city year wages period
    save "$DERIVED/wages_year_city_period`labelname'.dta", replace

    restore
end

* Calculate for 2000-2008
create_avg_wage "1" 2000 2008

* Calculate for 2009-2016
create_avg_wage "2" 2009 2016



* Merge the datasets into one panel dataset for each category
* For avg_wage_income
use "$DERIVED/avg_wage_income_period1.dta", clear
append using "$DERIVED/avg_wage_income_period2.dta"
save "$DERIVED/avg_wage_income_panel_twoperiod.dta", replace

* For wages_year_city
use "$DERIVED/wages_year_city_period1.dta", clear
append using "$DERIVED/wages_year_city_period2.dta"
save "$DERIVED/wages_year_city_panel_twoperiod.dta", replace
