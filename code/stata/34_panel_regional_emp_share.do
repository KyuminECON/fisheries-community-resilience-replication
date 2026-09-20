*-------------------------------------------------------------------------------
* 34_panel_regional_emp_share.do: Two-period panel: regional employment share.
* Inputs:  $RAW/employment-by-industry-community-and-year.csv
* Outputs: $DERIVED/regional_emp_share_panel_twoperiod.dta
*-------------------------------------------------------------------------------
version 17
set more off

* Broader Share of employment
* Panel structure two period

clear
set more off

* Load the employment data
insheet using "$RAW/employment-by-industry-community-and-year.csv", comma clear
rename community__name city
rename periodyear year
rename industry__name industry
rename emp employment
encode community__census_area__name, generate(census_id)

* Define a program to handle the data by period
capture program drop process_employment_data
program define process_employment_data
    args labelname startyear endyear
    preserve
    keep if year >= `startyear' & year <= `endyear'
	* For communities that have insufficient observaitons over time, removal.
	bysort city: gen count = _N
	drop if count < 4
    collapse (mean) mean_emp_by_city=emp, by(city census_id community__census_area__name)
    bysort census_id: egen sum_mean_emp_by_borough=sum(mean_emp_by_city)
    gen broader_emp_share = mean_emp_by_city / sum_mean_emp_by_borough
    label variable broader_emp_share "Broader employment share"
    gen period = `labelname'  // Label the dataset with the time period
    keep city broader_emp_share period community__census_area__name  // Keep only the specified variables
    save "$DERIVED/regional_emp_share_period`labelname'.dta", replace
    restore
end

* Process data for 2000-2008
process_employment_data "1" 2000 2008

* Process data for 2009-2016
process_employment_data "2" 2009 2016

* Merge the datasets into one panel dataset
use "$DERIVED/regional_emp_share_period1.dta", clear
append using "$DERIVED/regional_emp_share_period2.dta"
save "$DERIVED/regional_emp_share_panel_twoperiod.dta", replace
