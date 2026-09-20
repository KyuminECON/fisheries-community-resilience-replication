*-------------------------------------------------------------------------------
* 08_diversification_fisheries.do: Fisheries Shannon diversification index from CFEC permit portfolios.
* Inputs:  $RAW/akfish-data-CFECpermits.csv
* Outputs: $DERIVED/diversity_fish_max.dta, diversity_fish_shannon.dta
*-------------------------------------------------------------------------------
version 17
set more off

* Diversification of fisheries and fishing capacity for local economy data (2024,3,19)

*Starting....*
clear
set more off

* Load raw data*
insheet using "$RAW/akfish-data-CFECpermits.csv", comma clear

* Removal for fishery having ZZ-TOT and "00" census code *
drop if census_num=="00_AK" | census_num=="00_CA" | census_num=="00_OR"|census_num=="00_Oth" | census_num=="00_WA" |census_num=="00_ALL"

drop if fishery=="ZZ-TOT"

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

*For city-fishery level aggregation, we drop observations of "city=all cities"
drop if city=="All Cities"

*Truncate non-overlapped period
drop if year<2000
drop if year>2016

*Create "city" id variable: "city_id".
egen city_id=group(city)

*Create "fishery" id: variable: "fishery_id"
egen fishery_id=group(fishery)

*Create a new panel ID "city_fishery_id" to reduce the data to 2D panel from 3D panel. (Not creating dummy)
sort year, stable
gen city_fishery=city+"-"+fishery
egen city_fishery_id=group(city_fishery), label

save "$DERIVED/temp.dta", replace

*Set Panel frame
xtset city_fishery_id year
isid city_fishery_id year

* Calculate total number of fished permits by borough and year
bysort city year: egen sum_fished = total(fished)

gen share_fished=fished/sum_fished
gen share_sq_fished=share_fished^2

save "$DERIVED/temp.dta", replace

collapse (sum) share_sq_fished, by(city year)

*non-active fish permit removed
drop if share_sq_fished ==0

* Exclude short-observation periods fishing communities
* Filter out cities with less than 8 observations over the observation period
bysort city: gen count = _N
drop if count < 7

gen inv_share_sq = 1 /share_sq_fished

collapse (mean) div_fished=inv_share_sq, by(city)
label variable div_fished "Average diversification measure by active permits"

*Save HHI diversity measure by active fisheries. (whole fishing periods)
save "$DERIVED/diversity_fish_max.dta", replace

* Shannon-entropy based diverisfication

use "$DERIVED/temp.dta",replace

*drop fishing community that didn't do fishing (fished=0) in a given year
drop if sum_fished==0

* Calculate Shannon's index
gen shannon=-share_fished*ln(share_fished)

*Sum Shannon's index for each city and year
egen shannon_index = sum(shannon), by(city year)

*Exponentiate
gen div_fished_s= exp(shannon_index)

*Now average over the years for each city
collapse (mean) div_fished_s=div_fished_s, by(year city)
label variable div_fished_s "Average Shannon diversity measure by active permits"

bysort city: gen count = _N
drop if count < 7

* Save the file for plotting over time

save "$DERIVED/diversity_fish_time_trend.dta", replace

collapse (mean) div_fished_s=div_fished_s, by(city)

* Save the average Shannon diversity measure by city (whole fishing periods)
save "$DERIVED/diversity_fish_shannon.dta", replace
merge m:1 city using "$DERIVED/diversity_fish_max.dta"
drop _merge

* Save all together
save "$DERIVED/diversity_fish_max.dta", replace
