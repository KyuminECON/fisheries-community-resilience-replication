*-------------------------------------------------------------------------------
* 32_panel_population.do: Two-period panel: average population.
* Inputs:  $RAW/Total_pop.csv
* Outputs: $DERIVED/avg_pop_panel_twoperiod.dta
*-------------------------------------------------------------------------------
version 17
set more off

* Local Economies diversification
* Twp-period panel data creation for population
clear
set more off

* Load the population data
insheet using "$RAW/Total_pop.csv", comma clear

* Normalize city names for consistent merging
replace place_name = subinstr(place_name, " CDP, Alaska", "",.)
replace place_name = subinstr(place_name, " city, Alaska", "",.)
replace place_name = subinstr(place_name, " Alaska", "",.)
drop if place_name=="NA"

* Manually correct city names to match other datasets
replace place_name ="Wrangell" if place_name =="Wrangell city and borough,"
replace place_name ="Anchorage" if place_name =="Anchorage municipality,"
replace place_name ="Chenega Bay" if place_name =="Chenega"
replace place_name ="Juneau" if place_name =="Juneau city and borough,"
replace place_name ="Saint George" if place_name =="St. George"
replace place_name ="Saint Mary's" if place_name =="St. Mary's"
replace place_name ="Saint Michael" if place_name =="St. Michael"
replace place_name ="Saint Paul" if place_name =="St. Paul"
replace place_name ="Sitka" if place_name =="Sitka city and borough,"

* Define a program to create average population data for specified periods
capture program drop create_avg_pop
program define create_avg_pop
    args labelname startyear endyear
    preserve
    keep if year >= `startyear' & year <= `endyear'
    collapse (mean) avg_pop=total_pop, by(place_name)
    rename place_name city
    label variable avg_pop "Average Population(`startyear'-`endyear')"
    gen period = `labelname'  // Label the dataset with a period identifier
    save "$DERIVED/avg_pop_period`labelname'.dta", replace
    restore
end

* Calculate for period1
create_avg_pop "1" 2000 2008

* Calculate for period2
create_avg_pop "2" 2009 2016

* Merge the datasets into one panel dataset
use "$DERIVED/avg_pop_period1.dta", clear
append using "$DERIVED/avg_pop_period2.dta"

save "$DERIVED/avg_pop_panel_twoperiod.dta", replace
