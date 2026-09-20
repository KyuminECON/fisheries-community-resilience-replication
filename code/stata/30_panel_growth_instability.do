*-------------------------------------------------------------------------------
* 30_panel_growth_instability.do: Two-period panel: employment growth and instability by period.
* Inputs:  $RAW/employment-by-industry-community-and-year.csv
* Outputs: $DERIVED/growth_and_instability_emp_reg_period*.dta
*-------------------------------------------------------------------------------
version 17
set more off

* Local economy dataset

clear
set more off

*Load a raw data* -- this dataset has up-to-date available data (from 2014 -> 2016)
insheet using "$RAW/employment-by-industry-community-and-year.csv", comma clear

* Rename to the community and year keys used in the fisheries data
rename community__name city
rename periodyear year
rename industry__name industry
rename emp employment

*Create city_id
egen city_id =group(city)

*Generate industy
egen industry_id = group(industry)

* Unique ID for the two-dimensional panel
sort year, stable
gen city_industry=city+"-"+industry
egen city_industry_id=group(city_industry), label

*Save file
save "$DERIVED/temp.dta",replace

* Growth and instability compute for employment  (Equation (9) in Kluge (2018)

* Construct panel structure: This is necessary since we need to use first-difference to create "Change in employment" variable*
xtset city_industry_id year
isid city_industry_id year

*1) Growth rate, "mu" computation  (unbalanced panel; growth is not log-approximated)

collapse (sum) sum_employment_city_year=employment, by(year city)
label variable sum_employment_city_year "Sum of employement of each year and city"
rename sum_employment_city_year employment

egen city_id=group(city)
xtset city_id year

gen ln_employment = log(employment)

save "$DERIVED/temp.dta",replace

* Regression-Based Computation

clear

* Define a structure for the cumulative results dataset with the same variables as your final dataset
set obs 1
gen year = .
gen city = ""
gen employment = .
gen city_id = .
gen ln_employment = .
gen mu_emp_reg = .
gen sigma_emp_reg = .
gen min_year = .
gen time_trend = .

* Save this structure as an empty dataset and clear the dummy observation
save "$DERIVED/cumulative_results.dta", replace
use "$DERIVED/cumulative_results.dta", clear
drop in 1
save "$DERIVED/cumulative_results.dta", replace

* Now load your main data to start the process
use "$DERIVED/temp.dta", clear

* Ensure the dataset is sorted appropriately
sort city_id year

* Creating variables to hold the results
gen mu_emp_reg = .
gen sigma_emp_reg = .

* limit-time period for first period

keep if year>=2000 & year<=2008

* Normalize time trend to start at 1
egen min_year = min(year), by(city_id)
gen time_trend = year - min_year + 1

* Determine the number of unique city_ids in the dataset
qui sum city_id, detail
local num_cities = r(max)

* Loop through each city and run the regression
forvalues i = 1/`num_cities' {
    * Preserve the full dataset before focusing on one city
    preserve

    * Select the data for one city at a time
    qui keep if city_id == `i'

    * Check if there are enough observations
    if _N > 4 {
        * Create a log of employment if it doesn't exist

        * Regression of ln_employment on normalized time trend to get beta_1
        qui regress ln_employment time_trend

        * Store the exponentiated beta_1 (growth rate) for the city
        scalar growth_i = exp(_b[time_trend]) - 1

        * Calculate and store the standard deviation of residuals
        qui predict residuals, residuals
        summarize residuals, detail
        scalar sd_resid_i = r(sd)

        * Assign the computed values back to the original data
        qui replace mu_emp_reg = growth_i
        qui replace sigma_emp_reg = sd_resid_i

        * Save results for this city only
        save "$DERIVED/city_results.dta", replace

        * Append to cumulative file
        qui use "$DERIVED/cumulative_results.dta", clear
        qui append using "$DERIVED/city_results.dta"
        qui save "$DERIVED/cumulative_results.dta", replace
    }

    * Restore the full dataset
    restore
}

* Load the final cumulative results
use "$DERIVED/cumulative_results.dta", clear

* Collapse the data to get one observation per city
collapse (mean) mu_emp_reg (mean) sigma_emp_reg, by(city)

gen sigma_emp_reg_exp=exp(sigma_emp_reg)

gen period=1

* Save the collapsed dataset as a new file
save "$DERIVED/growth_and_instability_emp_reg_period1.dta", replace

* Second period /.

* Now load your main data to start the process
use "$DERIVED/temp.dta", clear

* Ensure the dataset is sorted appropriately
sort city_id year

* Creating variables to hold the results
gen mu_emp_reg = .
gen sigma_emp_reg = .

* limit-time period for first period

keep if year>=2009 & year<=2016

* Normalize time trend to start at 1
egen min_year = min(year), by(city_id)
gen time_trend = year - min_year + 1

* Determine the number of unique city_ids in the dataset
qui sum city_id, detail
local num_cities = r(max)

* Loop through each city and run the regression
forvalues i = 1/`num_cities' {
    * Preserve the full dataset before focusing on one city
    preserve

    * Select the data for one city at a time
    qui keep if city_id == `i'

    * Check if there are enough observations
    if _N > 4 {
        * Create a log of employment if it doesn't exist

        * Regression of ln_employment on normalized time trend to get beta_1
        qui regress ln_employment time_trend

        * Store the exponentiated beta_1 (growth rate) for the city
        scalar growth_i = exp(_b[time_trend]) - 1

        * Calculate and store the standard deviation of residuals
        qui predict residuals, residuals
        summarize residuals, detail
        scalar sd_resid_i = r(sd)

        * Assign the computed values back to the original data
        qui replace mu_emp_reg = growth_i
        qui replace sigma_emp_reg = sd_resid_i

        * Save results for this city only
        save "$DERIVED/city_results.dta", replace

        * Append to cumulative file
        qui use "$DERIVED/cumulative_results.dta", clear
        qui append using "$DERIVED/city_results.dta"
        qui save "$DERIVED/cumulative_results.dta", replace
    }

    * Restore the full dataset
    restore
}

* Load the final cumulative results
use "$DERIVED/cumulative_results.dta", clear

* Collapse the data to get one observation per city
collapse (mean) mu_emp_reg (mean) sigma_emp_reg, by(city)

gen sigma_emp_reg_exp=exp(sigma_emp_reg)

gen period=2

* Save the collapsed dataset as a new file
save "$DERIVED/growth_and_instability_emp_reg_period2.dta", replace
append using "$DERIVED/growth_and_instability_emp_reg_period1"

save  "$DERIVED/growth_and_instability_emp_reg_panel_twoperiod.dta", replace
