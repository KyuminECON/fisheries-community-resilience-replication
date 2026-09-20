*-------------------------------------------------------------------------------
* 02_geography_longlat.do: Community longitude/latitude lookup used by the master merge and the maps.
* Inputs:  $RAW/employment-by-industry-community-and-year.csv
* Outputs: $DERIVED/long_lat.dta
*-------------------------------------------------------------------------------
version 17
set more off

clear
set more off

*Load a raw data*
insheet using "$RAW/employment-by-industry-community-and-year.csv", comma clear

* Rename to the community and year keys used in the fisheries data
* ADAPTED 2026: this script came from the 2021 folder and was written against
* an older ALARI export whose columns were `community_name` / `industry_name`.
* The raw file in data/raw -- the one every other build step reads -- uses the
* current double-underscore names. Only these column references were aligned.
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

* Construct panel structure: This is necessary since we need to use first-difference to create "Change in employment" variable*
xtset city_industry_id year
isid city_industry_id year

collapse (mean) latitude=community__latitude longitude=community__longitude ,by(city)

save "$DERIVED/long_lat.dta",replace
