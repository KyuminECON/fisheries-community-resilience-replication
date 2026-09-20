*-------------------------------------------------------------------------------
* Filename:     09_fish_wage_ratio.do
* Purpose:      Ratio of fishing revenue to wage income, unimputed.
* Inputs:       $RAW/akfish-data-CFECpermits.csv, $DERIVED/wages_year_city.dta
* Outputs:      $DERIVED/avg_fish_ratio.dta
* Requires:     Stata 17+, config/paths.do already included by 00_master.do
* Author:       Kim
*               Ported for the replication package 2026; ONLY paths and this
*               header were changed. Estimation logic is byte-for-byte original
*               except where a line is marked RESTORED / ADDED.
*-------------------------------------------------------------------------------
version 17
set more off

*********************************
** Fisheries Diversification ****
*** Kyumin Kim and Matt Reimer***
*********************************

clear
* NOTE: original `global inpath ...` removed; paths come from config/paths.do




* Load raw data*
insheet using "$RAW/akfish-data-CFECpermits.csv", comma clear

* Removal for fishery having ZZ-TOT and "00" census code *
drop if census_num=="00_AK" | census_num=="00_CA" | census_num=="00_OR"|census_num=="00_Oth" | census_num=="00_WA" |census_num=="00_ALL"


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


*only using data overlapped

drop if year<2000
drop if year>2016

* Only leave total values 
drop if fishery!="ZZ-TOT"

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

*For missing data for est. earnings, we drop observations with no earning data.
*drop if est_earn==.


* Using given information about earning excluding small fisheries, 
*After removing time and cities that have zero fishing activities :: When nothing is fished, there is no fishing revenue. 
replace est_earn=0 if fished==0 /* zero permit-held cities and year dropped*/

sort city year
gen avg_earn_permit = est_earn/issued
gen avg_earn_permit_excl=est_excl/permit_excl

*drop if est_earn !=. | est_excl !=. if you want to see what cities do not have any info 
gen diff_permit= fished-permit_excl 

*Generate adjusted values by adding by "diff_permit * avg_earn_permit" to east_excl as interporlated earnings
gen est_missing_adj=diff_permit*avg_earn_permit_excl + est_excl  

* Generate a new variable for the sum initially setting it to zero or missing
gen total_earnings = est_earn + est_missing_adj

* Correct for cases where est_earn is missing
replace total_earnings = est_missing_adj if missing(est_earn) & !missing(est_missing_adj)

* Correct for cases where est_missing_adj is missing
replace total_earnings = est_earn if !missing(est_earn) & missing(est_missing_adj)

* In cases where both are missing, total_earnings should be missing
replace total_earnings = . if missing(est_earn) & missing(est_missing_adj)

drop est_earn est_missing_adj

*Finishg complimenting fihsing earnings through fishing earning that excludes small fisheries.  
rename total_earnings est_earn


// Exclude fishing communities that have any reported values for fishing revenue at a given year 
drop if est_earn ==.  

* Filter out cities with less than 7 observations over the observation period
bysort city: gen count = _N
drop if count < 7
**********Note that: fishing commutieis that have 0 values at a given year for earning is there are permit holders but they didn't fish. 

********* modification below 
merge m:1 city year using "$DERIVED/wages_year_city.dta"

gen fish_wage_ratio = est_earn / wages

collapse (mean) avg_fish_ratio = fish_wage_ratio, by (city)

*Drop fishing communities that do not have sufficient observations in 2000-2016 & No fishing earning reports 
drop if avg_fish_ratio==.

save "$DERIVED/avg_fish_ratio.dta", replace
