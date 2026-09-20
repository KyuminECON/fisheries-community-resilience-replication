*-------------------------------------------------------------------------------
* 06_regional_emp_share.do: Community employment share within its shared borough.
* Inputs:  $RAW/employment-by-industry-community-and-year.csv
* Outputs: $DERIVED/regional_emp_share.dta
*-------------------------------------------------------------------------------
version 17
set more off

* Broader employment Share

clear
set more off

* Load the dataset
insheet using "$RAW/employment-by-industry-community-and-year.csv", comma clear

* Rename variables for consistency
rename community__name city
rename periodyear year
rename industry__name industry
rename emp employment
encode community__census_area__name, generate(census_id)

* Collapse to sum employment by city, census area, and year
collapse (sum) total_emp=employment, by(city census_id community__census_area__name year)

* For communities that have insufficient observaitons over time, removal.
bysort city: gen count = _N
drop if count < 8

* Calculate the total employment for each borough and year
bysort census_id year : egen total_emp_by_borough = total(total_emp)

* Calculate the employment share of each city within its borough per year
gen emp_share = total_emp / total_emp_by_borough

* Calculate the average employment share over time for each city within the borough
bysort city census_id: egen broader_emp_share = mean(emp_share)

* Label the newly created variable
label variable broader_emp_share "Average employment share within borough"

* Drop intermediate variables to clean up the dataset
drop total_emp total_emp_by_borough emp_share

* Making cross-sectional structure
collapse (mean) broader_emp_share=broader_emp_share,by(city census_id community__census_area__name)

* Save the dataset with the new variable
save "$DERIVED/regional_emp_share.dta", replace
