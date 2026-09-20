*-------------------------------------------------------------------------------
* Filename:     02_geography_longlat.do
* Purpose:      Community longitude/latitude lookup used by the master merge and the maps.
* Inputs:       $RAW/employment-by-industry-community-and-year.csv
* Outputs:      $DERIVED/long_lat.dta
* Requires:     Stata 17+, config/paths.do already included by 00_master.do
* Author:       Kim
*               Ported for the replication package 2026; ONLY paths and this
*               header were changed. Estimation logic is byte-for-byte original
*               except where a line is marked RESTORED / ADDED.
*-------------------------------------------------------------------------------
version 17
set more off

clear
set more off
* NOTE: original `global inpath ...` removed; paths come from config/paths.do

*Load a raw data*
insheet using "$RAW/employment-by-industry-community-and-year.csv", comma clear

*Rename Commuinty_name -> "city", "periodyear" ->"year" since fisheries data uses "city" and "year" for community id and time and for my convinience
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

*Generate an unique ID to set two-dimensional panel: The original data is 3-dimensinal.   
sort year, stable
gen city_industry=city+"-"+industry
egen city_industry_id=group(city_industry), label

* Construct panel structure: This is necessary since we need to use first-difference to create "Change in employment" variable* 
xtset city_industry_id year
isid city_industry_id year 

collapse (mean) latitude=community__latitude longitude=community__longitude ,by(city) 

save "$DERIVED/long_lat.dta",replace
