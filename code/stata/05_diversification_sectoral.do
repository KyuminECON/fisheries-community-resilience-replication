*-------------------------------------------------------------------------------
* Filename:     05_diversification_sectoral.do
* Purpose:      Sectoral (industrial) Shannon diversification, level and growth-based.
* Inputs:       $RAW/employment-by-industry-community-and-year.csv
* Outputs:      $DERIVED/diversity_emp.dta, diversity_emp_diff.dta
* Requires:     Stata 17+, config/paths.do already included by 00_master.do
* Author:       Kim
*               Ported for the replication package 2026; ONLY paths and this
*               header were changed. Estimation logic is byte-for-byte original
*               except where a line is marked RESTORED / ADDED.
*-------------------------------------------------------------------------------
version 17
set more off

***************************************************************************************** 
********************** Local Economies diversification **********************************
************************* Kyumin Kim and Matthew Reimer *********************************
******************************** 2023_10_15 version**************************************
*****************************************************************************************
clear
set more off
* NOTE: original `global inpath ...` removed; paths come from config/paths.do

* Load a raw data -- this dataset has up-to-date available data (from 2014 -> 2016)
insheet using "$RAW/employment-by-industry-community-and-year.csv", comma clear

* Rename Commuinty_name -> "city", "periodyear" ->"year" since fisheries data uses "city" and "year" for community id and time and for my convenience
rename community__name city
rename periodyear year
rename industry__name industry
rename emp employment

* Create city_id
egen city_id = group(city)

* Generate industry
egen industry_id = group(industry) 

* Generate an unique ID to set two-dimensional panel: The original data is 3-dimensional.   
sort year, stable
gen city_industry = city + "-" + industry
egen city_industry_id = group(city_industry), label

* Construct panel structure: This is necessary since we need to use first-difference to create "Change in employment" variable* 
xtset city_industry_id year
isid city_industry_id year 

* Note: Adjust the code above if you need to consider each city across all years and industries, or modify it to be specific to each industry or year.

*Save file
save "$DERIVED/temp.dta",replace

*********** Share computation (Equation (2) in Kluge (2018)) ********************
******Note: Diversification Measure is by Inverse HHI index**********************


*1) Making sum of revenue
collapse (sum) sum_employment=employment, by(year city_id city)

save "$DERIVED/sum_employment.dta", replace 

*2) Load original data and merge 
use "$DERIVED/temp.dta"
merge m:1 city_id city year using "$DERIVED/sum_employment.dta"
drop _merge

*3) Compute S_irt "Share" of active permit
gen share_employment=employment/sum_employment
drop if share_employment==. 
gen share_sq_employment = share_employment^2 

save "$DERIVED/temp.dta",replace

collapse (sum) share_sq_employment, by(city_id city year)  /* summing over industry sectors within year and community*/
gen inv_share_employment=1/share_sq_employment

* Filter out cities with less than 8 observations over the observation period
bysort city: gen count = _N
drop if count < 8


// *For trend information gathering.. over time
// collapse (mean) div_emp=inv_share_employment, by(year)
// save "$DERIVED/div_emp_trend.dta",replace

collapse (mean) div_emp=inv_share_employment, by(city_id city)
label variable div_emp "Average diversification measure by employment"

*Save HHI diversity measure by employment. (whole fishing periods) 
save "$DERIVED/diversity_emp.dta", replace





///////// Diversification measure by difference as proposed by Kluge (run the code below after you run the code line from 1-36 first. Don't run 44-67 ) //////////////

* Re-load dataset*/
use "$DERIVED/temp.dta"

* Construct panel structure: This is necessary since we need to use first-difference to create "Change in employment" variable* 
xtset city_industry_id year
isid city_industry_id year 

*1) Absoulte Value of first-diffenced employment for city-industry, and year
gen d_employment=abs(d1.employment)
save "$DERIVED/temp.dta", replace /*Before collapse, save the original dataset*/

*2) Sum of change in employment over all industry while aggregating by each city and year 
collapse (sum) sum_d_employment=d_employment, by(year city city_id) /*You can use "egen by" function instead. I'm just lazy */
save "$DERIVED/sum_employment.dta",replace /* Save for merging it into the original dataset*/

*3) Share computation ("S_irt"")
use "$DERIVED/temp.dta" /*Loading the original dataset*/
merge m:1 city_id year using "$DERIVED/sum_employment.dta" /*Merge sum_employment into original data*/
drop _merge
gen share=d_employment/sum_d_employment /* "|change in employement| / | Sum of change in employment over all industyries|" */ 

*4) Compute diversification measure (Div_r)
drop if share==. 
gen share_sq=share^2 /* Before creating Herfindhal index*/

*save the file before collapse 
save "$DERIVED/temp.dta",replace

collapse (sum) share_sq, by(city_id city year) /*Summation over industry: This is Herfindhal Index */
gen inv_share_sq=1/share_sq /* Create Inverse Herfihndhal Index*/

* Filter out cities with less than 8 observations over the observation period
bysort city: gen count = _N
drop if count < 8

collapse (mean) div_emp_diff= inv_share_sq, by(city_id city) /*Average Diversification measure by city - averaged over time(year)*/
label variable div_emp_diff "Average diversification measure by difference in employment"
save "$DERIVED/diversity_emp_diff.dta", replace /*Save this data for merging later* - what should be merged later */

////// Compute Growth-based entropy index /////// 

use "$DERIVED/temp.dta",replace


* Calculate Shannon's index
gen shannon=-share*ln(share)

*Sum Shannon's index for each city and year
egen shannon_index = sum(shannon), by(city year)

*Exponentiate 
gen div_emp_s= exp(shannon_index)

*Now average over the years for each city
collapse (mean) div_emp_diff_s=div_emp_s, by(city year)
label variable div_emp_diff_s "Average Shannon diversity measure by employment growth"

*****Don't run the line below: this for imputating-data creation
*save "$DERIVED/emp_div_imputation.dta", replace 

* Filter out cities with less than 8 observations over the observation period
bysort city: gen count = _N
drop if count < 8

*** Save for time-trend plot

* RE-ENABLED 2026: needed by code/R for Fig. S.1; export only.
save "$DERIVED/diversity_emp_shannon_time_trend.dta", replace

***

collapse (mean) div_emp_diff_s, by(city) 

* Save the average Shannon diversity measure by city (whole fishing periods)
save "$DERIVED/diversity_emp_diff_shannon.dta", replace
merge m:1 city using "$DERIVED/diversity_emp_diff.dta"
drop _merge
drop city_id

gen sq_div_emp_diff_s = sqrt(div_emp_diff_s)
gen sq_div_emp_diff  = sqrt(div_emp_diff)

label variable sq_div_emp_diff "Sqaure Root Econ. Diversification"
label variable sq_div_emp_diff_s "Sqaured Root Econ. Diversification"


* Save all together
save "$DERIVED/diversity_emp_diff.dta", replace



