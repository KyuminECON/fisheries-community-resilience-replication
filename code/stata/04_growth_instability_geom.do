*-------------------------------------------------------------------------------
* Filename:     04_growth_instability_geom.do
* Purpose:      Geometric employment growth (return) and its instability, per community.
* Inputs:       $RAW/employment-by-industry-community-and-year.csv
* Outputs:      $DERIVED/growth_and_instability_emp_all.dta
* Requires:     Stata 17+, config/paths.do already included by 00_master.do
* Author:       Kim
*               Ported for the replication package 2026; ONLY paths and this
*               header were changed. Estimation logic is byte-for-byte original
*               except where a line is marked RESTORED / ADDED.
*-------------------------------------------------------------------------------
version 17
set more off

***************************************************************************************** 
***************************** Local Economy Dataset Preperation *************************
************************* Kyumin Kim and Matthew Reimer *********************************
******************************** 2023_10_15 version**************************************
*****************************************************************************************


clear
set more off
* NOTE: original `global inpath ...` removed; paths come from config/paths.do

*Load a raw data* -- this dataset has up-to-date available data (from 2014 -> 2016)
insheet using "$RAW/employment-by-industry-community-and-year.csv", comma clear

*Rename Commuinty_name -> "city", "periodyear" ->"year" since fisheries data uses "city" and "year" for community id and time and for my convinience
rename community__name city
rename periodyear year
rename industry__name industry
rename emp employment

*Create city_id
egen city_id =group(city)

*Generate industy
egen industry_id = group(industry) 

*Generate an unique ID to set two-dimensional panel: The original data is 3-dimensinal.   
sort year, stable
gen city_industry=city+"-"+industry
egen city_industry_id=group(city_industry), label


*Save file
save "$DERIVED/temp.dta",replace


******* Growth and instability compute for employment  (Equation (9) in Kluge (2018)  *****


************* Log-difference for growth rate approximation ***************************

* Construct panel structure: This is necessary since we need to use first-difference to create "Change in employment" variable* 
xtset city_industry_id year
isid city_industry_id year 


*1) Growth rate, "mu" computation  (The original data is imbalanced panel. DO NOT USE log approximation for growth computation.)

collapse (sum) sum_employment_city_year=employment, by(year city) /*sum employment over industry*/
label variable sum_employment_city_year "Sum of employement of each year and city"
rename sum_employment_city_year employment

egen city_id=group(city)
xtset city_id year

gen ln_employment = log(employment)

save "$DERIVED/temp.dta",replace 

*Making Log-difference for apprixmate growth rate
gen growth_appx=D.ln_employment

collapse (mean) mu_emp_appx=growth_appx (sd) sigma_emp_appx=growth_appx, by(city)

drop if sigma_emp_appx==.


* Save the file. 
save "$DERIVED/growth_and_instability_emp_appx.dta", replace 


***************** Regression-Based Computation *****************************

clear
* NOTE: original `global inpath ...` removed; paths come from config/paths.do

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
    if _N > 7 {  
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

* Save the collapsed dataset as a new file
save "$DERIVED/growth_and_instability_emp_reg.dta", replace

********************** Kluge-based Calculation **********************************

use "$DERIVED/temp.dta",clear 

drop ln_employment

* Sort by city and year, crucial for time series operations
sort city_id year

* Declare the panel data structure
xtset city_id year

* Generate the logarithm of employment
gen ln_employment = log(employment)

* Generate the log difference of employment (which is the log of growth rates)
by city_id: gen log_growth_rate = D.ln_employment

* Count the number of non-missing observations for each city
by city_id: egen count = count(log_growth_rate)

* Now exclude cities with less than 8 observations
drop if count < 8

* Re-generate the mean of log growth rates for each remaining city
by city_id: egen mean_log_growth = mean(log_growth_rate)

* Calculate the geometric mean growth rate for each city
by city_id: gen geo_mean_growth = exp(mean_log_growth) - 1

* Generate the squared deviation from the mean for each city
by city_id: gen sq_dev = (log_growth_rate - mean_log_growth)^2

* Sum the squared deviations
by city_id: egen sum_sq_dev = sum(sq_dev)

* Calculate the variance of the log growth rates
by city_id: gen variance_log_growth = sum_sq_dev / (count - 1)

* Generate the standard deviation of the log growth rates
by city_id: gen sd_log_growth = sqrt(variance_log_growth)

* Calculate the geometric standard deviation for each city
by city_id: gen geo_sd_growth = exp(sd_log_growth)

* Now we have the average geometric growth rate and geometric standard deviation by city
* Keep only the city identifier, geometric mean growth, and geometric SD
keep city_id city geo_mean_growth geo_sd_growth

* Collapse into cross-sectional data with the mean growth rate and standard deviation for each city
collapse (mean) mu_emp_k=geo_mean_growth sigma_emp_k=geo_sd_growth, by(city)

gen l_sigma_emp_k= log(sigma_emp_k) 

* Save the results
save "$DERIVED/growth_and_instability_emp_k.dta", replace // geometric formulation itself. 



*Now all merge using other growth data

merge m:1 city using "$DERIVED/growth_and_instability_emp_appx.dta" // Log-difference 
drop _merge
merge m:1 city using "$DERIVED/growth_and_instability_emp_reg.dta" // Regression based
drop _merge
merge m:1 city using "$DERIVED/growth_and_instability_emp.dta" // Original data -based on arithmatic 
drop _merge 

drop emp_diff
drop city_id

label variable mu_emp_k "Average Growth(Kluge)"
label variable sigma_emp_k "Std. Deviation of Growth (Kluge)"
label variable l_sigma_emp_k "Logged Std. Dev. of Growth (Kluge)"
label variable mu_emp_appx "Average Grwoth (log_diff)"
label variable mu_emp_reg "Average Growth (reg)"
label variable sigma_emp_reg "Std Dev. (reg)"
label variable mu_emp "Average Growtth (Arith)"
label variable sigma_emp "Std Dev (Arith)"
label variable sigma_emp_appx "Std Dev. (log_diff)"
label variable sigma_emp_reg_exp "Std. Dev. (Expentiated sigma_emp_reg)"





save "$DERIVED/growth_and_instability_emp_all.dta", replace // geometric formulation itself. 
