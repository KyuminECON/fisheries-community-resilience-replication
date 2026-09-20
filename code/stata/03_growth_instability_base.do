*-------------------------------------------------------------------------------
* 03_growth_instability_base.do: Arithmetic growth and instability; the geometric step below merges this in.
* Inputs:  $RAW/employment-by-industry-community-and-year.csv
* Outputs: $DERIVED/growth_and_instability_emp.dta, level_employment.dta
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

* Construct panel structure: This is necessary since we need to use first-difference to create "Change in employment" variable*
xtset city_industry_id year
isid city_industry_id year

* Growth and instability compute for employment  (Equation (9) in Kluge (2018)
** Employment opportunity in non-fisheries sectors

*1) Growth rate, "mu" computation  (unbalanced panel; growth is not log-approximated)

collapse (sum) sum_employment_city_year=employment, by(year city city_id)
label variable sum_employment_city_year "Sum of employement of each year and city"

xtset city_id year /*Set panel for first-difference*/

gen growth_rate=D.sum_employment_city_year/L.sum_employment_city_year /*growth rate is computed by formula "(emp_t+1 - emp_t) / emp_t" */
gen emp_difference=D.sum_employment_city_year

collapse (mean) mu_emp=growth_rate emp_diff=emp_difference  (sd) sigma_emp=growth_rate, by(city city_id)
gen mu_emp2=mu_emp^2 /* Generate Squared term of growth in employment*/

drop if mu_emp==. | sigma_emp ==.

label variable mu_emp2 "Squared average employment growth rate"
label variable mu_emp "Average employment growth rate"
label variable sigma_emp "Instability in employment"
save "$DERIVED/growth_and_instability_emp.dta", replace /* save What should be merged later */

* computing geometric growth rate

clear
use "$DERIVED/temp.dta"

collapse (sum) sum_employment_city_year=employment, by(year city city_id)
tsset city_id year

* Generate the natural logarithm of fishing earnings
gen ln_employment = ln(sum_employment_city_year)

* Run the fixed effects regression
xtreg ln_employment year, fe /*Same with c.year : time trend method*/
*Compute residuals for instability measure
predict residuals, residuals

* Retrieve the coefficients for each city (city-specific effects)
predict double city_effects, u

* Compute the geometric growth rate for each city
gen geom_growth_rate = exp(_b[year] + city_effects) - 1

*compute the instability measuring using residuasl
egen sigma_geom= sd(residuals), by (city_id)

collapse (mean) mu_emp_geom=geom_growth_rate sigma_emp_geom=sigma_geom, by(city_id city)
gen mu2_emp_geom=mu_emp_geom^2

drop if sigma_emp_geom==.

*Only overlapped with local economies obs period.
save "$DERIVED/growth_rate_instability_geom_local.dta",replace

* Compute Level-employement variable (Not growth anlaysis but level variable)

use "$DERIVED/temp.dta"
collapse (mean) avg_employment=employment (sd) std_employment=employment, by(city city_id)
sum avg_employment
gen norm_avg_employment=(avg_employment-`r(min)')/ (`r(max)'-`r(min)')

sum std_employment
gen norm_std_employment=(std_employment- `r(min)')/ (`r(max)'-`r(min)')

label variable norm_avg_employment "Normalized average employment"
label variable norm_std_employment "(Instability) Normalized standard deviation of employment"
gen norm_avg_employment_sq = norm_avg_employment^2
gen norm_std_employment_sq = norm_std_employment^2
save "$DERIVED/level_employment.dta",replace /*What should be merged*/

*Merge Census Code into the anlysis data set.
*use "$DERIVED/temp.dta"
*collapse (first) community__census_area__name, by(city city_id)

* Create a census_area code for fixed-effect for cluster
*encode community__census_area__name, generate(census_id)
