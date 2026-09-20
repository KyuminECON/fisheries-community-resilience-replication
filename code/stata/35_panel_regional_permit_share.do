*-------------------------------------------------------------------------------
* Filename:     35_panel_regional_permit_share.do
* Purpose:      Two-period panel: regional fishing-permit share.
* Inputs:       $RAW/akfish-data-CFECpermits.csv
* Outputs:      $DERIVED/regional_permit_share_max_panel_twoperiod.dta
* Requires:     Stata 17+, config/paths.do already included by 00_master.do
* Author:       Kim
*               Ported for the replication package 2026; ONLY paths and this
*               header were changed. Estimation logic is byte-for-byte original
*               except where a line is marked RESTORED / ADDED.
*-------------------------------------------------------------------------------
version 17
set more off

******* (Spatial) concentration of Share of permit *******
********************* Two period panel *******************


clear
set more off
* NOTE: original `global inpath ...` removed; paths come from config/paths.do

* Load raw data*
insheet using "$RAW/akfish-data-CFECpermits.csv", comma clear


* Removal for fishery having ZZ-TOT and "00" census code *
drop if census_num=="00_AK" | census_num=="00_CA" | census_num=="00_OR"|census_num=="00_Oth" | census_num=="00_WA" |census_num=="00_ALL"

* Only leave total values for each community 
drop if fishery!="ZZ-TOT"
drop if city=="All Cities"

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



*drop to make sure that each city at least has some amount of observations 
drop if year<2000
drop if year>2016


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


*Create "city" id variable: "city_id".
egen city_id=group(city), label


keep city year census_area fished

save "$DERIVED/temp_comp.dta", replace 


/////////////////// period 1 //////////////////////

keep if year>=2000 & year<=2008

*No fishing activity years are droped 
drop if fished==0 

* For missing data that doesn't 
bysort city: gen count = _N
drop if count < 4


**Compute braoder regional fisheries revenue share 
**Compute braoder regional fisheries revenue share 
encode census_area, generate(census_id) /*Census area is borough*/
save "$DERIVED/temp.dta", replace

* Calculate total number of fished permits by borough and year
bysort census_id year: egen total_fished_by_borough = total(fished)

* Calculate the share of fished permits for each city within its borough
gen share_of_fished = fished / total_fished_by_borough

* Calculate the average share of fished permits over time for each city within the borough
bysort city census_id: egen broader_permit_share = mean(share_of_fished)

* Optionally drop intermediate variables if they are no longer needed
drop total_fished_by_borough share_of_fished

* Label the newly created variable
label variable broader_permit_share "Average share of fishing permits within borough"

collapse (mean) broader_permit_share = broader_permit_share, by(city)

* get rid of obs that didn't do active fishing permt even though they have permit issued. 
drop if broader_permit_share==0

gen period=1

save "$DERIVED/regional_permit_share_max_period1.dta", replace


////////////////////////////////////////////////// Period 2////////////////////////////////

use "$DERIVED/temp_comp.dta", clear 

keep if year>=2009 & year<=2016

*No fishing activity years are droped 
drop if fished==0 

* For missing data that doesn't 
bysort city: gen count = _N
drop if count < 4


**Compute braoder regional fisheries revenue share 
**Compute braoder regional fisheries revenue share 
encode census_area, generate(census_id) /*Census area is borough*/
save "$DERIVED/temp.dta", replace

* Calculate total number of fished permits by borough and year
bysort census_id year: egen total_fished_by_borough = total(fished)

* Calculate the share of fished permits for each city within its borough
gen share_of_fished = fished / total_fished_by_borough

* Calculate the average share of fished permits over time for each city within the borough
bysort city census_id: egen broader_permit_share = mean(share_of_fished)

* Optionally drop intermediate variables if they are no longer needed
drop total_fished_by_borough share_of_fished

* Label the newly created variable
label variable broader_permit_share "Average share of fishing permits within borough"

collapse (mean) broader_permit_share = broader_permit_share, by(city)

* get rid of obs that didn't do active fishing permt even though they have permit issued. 
drop if broader_permit_share==0

gen period=2

save "$DERIVED/regional_permit_share_max_period2.dta", replace

append using "$DERIVED/regional_permit_share_max_period1.dta"


/// Full file saving

save "$DERIVED/regional_permit_share_max_panel_twoperiod", replace
