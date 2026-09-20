*-------------------------------------------------------------------------------
* Filename:     11_fishermen.do
* Purpose:      Average number of permit-holding fishermen per community.
* Inputs:       $RAW/akfish-data-CFECpermits.csv
* Outputs:      $DERIVED/fishermen.dta
* Requires:     Stata 17+, config/paths.do already included by 00_master.do
* Author:       Kim
*               Ported for the replication package 2026; ONLY paths and this
*               header were changed. Estimation logic is byte-for-byte original
*               except where a line is marked RESTORED / ADDED.
*-------------------------------------------------------------------------------
version 17
set more off

*************************************************************
**      Number of fishermen ****
*************************************************************

clear
set more off
* NOTE: original `global inpath ...` removed; paths come from config/paths.do

* Load raw data*
insheet using "$RAW/akfish-data-CFECpermits.csv", comma clear

* Removal for fishery having ZZ-TOT and "00" census code *
drop if census_num=="00_AK" | census_num=="00_CA" | census_num=="00_OR"|census_num=="00_Oth" | census_num=="00_WA" |census_num=="00_ALL"

* Only leave total values 
drop if fishery!="ZZ-TOT"

*Borough adjustment needed since some cities' borough has been changed over time. 
replace census_area = "HOONAH-ANGOON CA" if census_area == "SKAGWAY-HOONAH-ANGOON CA"
replace census_area = "KUSILVAK CENSUS AREA" if census_area == "WADE HAMPTON CA"
replace census_area = "PRINCE OF WALES-HYDER CA" if census_area == "PR OF WALES-OUTER KTKN CA"
replace census_area = "PETERSBURG CA" if census_area == "WRANGELL-PETERSBURG CA"

replace census_area = "HOONAH-ANGOON CA" if city == "Skagway" // Historically,  Skagway has bee in Hoonah census area for a long time. 
replace census_area = "PETERSBURG CA" if city == "Wrangell" // For the same reason.

* Changing the name of city that have different names from that of local economies dataset. 
replace city = "Circle" if city == "Circle City"
replace city = "Manley Hot Springs" if city == "Manley Hot Spring"
replace city = "Saint Mary's" if city == "Saint Marys"
replace city = "Tenakee Springs" if city == "Tenakee"
replace city = "McKinley Park" if city == "Denali Park"
replace city = "Saint George" if city == "Saint George Isl"
replace city = "McGrath" if city == "Mcgrath"
replace city = "Sutton-Alpine" if city == "Sutton"
replace city = "Saint Paul" if city == "Saint Paul Island"
replace city = "Clark's Point" if city == "Clarks Point"

drop if year<1990

*For city-fishery level aggregation, we drop observations of "city=all cities"
drop if city=="All Cities"

*Only leave "All Fisheries Combined"
drop if fishery_grp!="All Fisheries Combined"

label variable year "Year"
label variable census_num "Census Number"
label variable census_area "Census Area"
label variable city "City"
label variable fishery "Fishery Code"
label variable type "Type of Record"
label variable permit_holder "Number of permit holders"
label variable issued "Number of permits issued"
label variable fishermen "Number of fishermen who fished"
label variable est_earn "Estimated gross earnings"
label variable lbs_landed "Total pounds landed"
label variable fished "Number of permits fished"
label variable lbs_excl "Total pounds excl confidential data"
label variable est_excl "Estimated earnings excl confidential data"
label variable ppl_excl "Total permits excl confidential data"
label variable fishery_desc "Fishery Description "
label variable permit_excl "Number of permits excl confidential data "

*For observations with 0 active fished permits: This implies that there is no fishing earnings (i.e. est_earn=0)
*drop if fished == 0

*Create "city" id variable: "city_id".
egen city_id=group(city), label
egen census_id=group(census_area), label


drop if year<2000 | year>2016

***************** Covariate of each fishing communities **********

collapse (mean) avg_fishermen=fishermen, by (city)

* Normalization. 

label variable avg_fishermen "Average Number of fishermen"

save "$DERIVED/fishermen.dta", replace 

******************************

