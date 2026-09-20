*-------------------------------------------------------------------------------
* Filename:     01_prep_demographics.do
* Purpose:      Average population, average wage income, and geography identifiers.
* Inputs:       $RAW/Total_pop.csv, $RAW/employment-summary-data-by-community-and-year.csv
* Outputs:      $DERIVED/avg_pop_l.dta, avg_wage_income.dta, wages_year_city.dta, geography.dta
* Requires:     Stata 17+, config/paths.do already included by 00_master.do
* Author:       Kim
*               Ported for the replication package 2026; ONLY paths and this
*               header were changed. Estimation logic is byte-for-byte original
*               except where a line is marked RESTORED / ADDED.
*-------------------------------------------------------------------------------
version 17
set more off

****** Data Preperation/Cleasing for Alaska wage income and population data ****
******** Kyumin Kim / Matt Reimer **********************************************
********************************************************************************
********************* 2023. 10. 3 version. ************************************

*Note: This is the do-file that should be run first before implementing other do-file execution. 

clear
set more off
* NOTE: original `global inpath ...` removed; paths come from config/paths.do



**** Population Data: Aggregating all data into average wage income of each local economy  ****
*Note: The data sheet below is NOT raw data. The original population data "Place_Total_Population has multiple sheet. Thus, you need to only create a sperate data sheet that only contains population-related sheet"

*insheet using "$DERIVED/Place_Total Population.csv", comma clear 
insheet using "$RAW/Total_pop.csv", comma clear 

*FYI, All data's key variable for data merging should be "city name". However, local economy raw data has a different type of city name. Therefore, I transform city names into the uniform shape for merging purpose. 

replace place_name = subinstr(place_name, " CDP, Alaska", "",.) /*Name part: "CDP, Alaska"  removed*/
replace place_name = subinstr(place_name, " city, Alaska","",.) /*Nname part: "city, Alaska"  removed*/
replace place_name = subinstr(place_name, " Alaska","",.)

drop if place_name=="NA"

*Manually modify for cities that are not matched with other dataset's city names
replace place_name ="Wrangell" if place_name =="Wrangell city and borough,"
replace place_name ="Anchorage" if place_name =="Anchorage municipality,"
replace place_name ="Chenega Bay" if place_name =="Chenega"
replace place_name ="Juneau" if place_name =="Juneau city and borough,"
replace place_name ="Saint George" if place_name =="St. George"
replace place_name ="Saint Mary's" if place_name =="St. Mary's"
replace place_name ="Saint Michael" if place_name =="St. Michael"
replace place_name ="Saint Paul" if place_name =="St. Paul"
replace place_name ="Sitka" if place_name  =="Sitka city and borough,"



*** Making average population data set for fisheries only 1990-2020
preserve
collapse (mean) avg_pop=total_pop, by(place_name)
rename place_name city /*Rename place_name as city to create a key variable for merge*/
label variable avg_pop "Average population(1990-2020)"

*Save dataset. '_f' means it is only for fish 
save "$DERIVED/avg_pop_f.dta", replace /*Save this population data for merging it into master data set*/
restore 

** Making average population date set for local economies only from 2000-2016

keep if year>1999
keep if year<2017

collapse (mean) avg_pop=total_pop, by(place_name)
rename place_name city 
label variable avg_pop "Average Population(2000-2016)"

** Save dataset. '_l' manes it is only for local economies
save "$DERIVED/avg_pop_l.dta", replace /*Save this population data for merging it into master data set*/


*************




*** Wage Data: Aggregating all data into average wage income of each local economy.
insheet using "$RAW/employment-summary-data-by-community-and-year.csv", comma clear  /*period is 2000-2016*/
collapse (mean) avg_wincome=wages avg_emp=emp ,by(community__name) /*Here, community__name is equivalent to city name*/
label variable avg_wincome "Average wage income for community"
label variable avg_emp "Average number of employment for community"
rename community__name city /*Renaming "Community__name as "city" to make it as a key variable for merging*/


save "$DERIVED/avg_wage_income.dta", replace /*Save this wage data for merging it into master data set*/

*** Wage: Data for just merging. 
*** Wage Data: Aggregating all data into average wage income of each local economy.
insheet using "$RAW/employment-summary-data-by-community-and-year.csv", comma clear  /*period is 2000-2016*/
rename community__name city /*Rename place_name as city to create a key variable for merge*/
rename periodyear year 
*Drop all variables except for city year and total wage 
keep city year wages


save "$DERIVED/wages_year_city.dta", replace 

** Wage income data for year and city (For preparation of fisheries earning / wage income data )

insheet using "$RAW/employment-summary-data-by-community-and-year.csv", comma clear 
collapse (mean) avg_wincome=wages avg_emp=emp ,by(community__name periodyear)
rename community__name city
rename periodyear year


save "$DERIVED/avg_wage_income_year_city.dta", replace


***longditue and latitude extraction 
insheet using "$RAW/employment-summary-data-by-community-and-year.csv", comma clear  /*period is 2000-2016*/
collapse (mean) longitude=community__longitude latitude=community__latitude, by(community__name)
label variable long "Longitude"
label variable lat "Latitude"
rename community__name city


save "$DERIVED/geography.dta", replace


