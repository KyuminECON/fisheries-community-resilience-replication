*-------------------------------------------------------------------------------
* Filename:     37_panel_fish_ratio.do
* Purpose:      Two-period panel: imputed fishing revenue to wage ratio.
* Inputs:       $RAW/akfish-data-CFECpermits.csv
* Outputs:      $DERIVED/avg_fish_ratio_im_panel_twoperiod.dta
* Requires:     Stata 17+, config/paths.do already included by 00_master.do
* Author:       Kim
*               Ported for the replication package 2026; ONLY paths and this
*               header were changed. Estimation logic is byte-for-byte original
*               except where a line is marked RESTORED / ADDED.
*-------------------------------------------------------------------------------
version 17
set more off

************ Fishing revenue imputation for missing fisheries *****************************************
*********** Following the procedure of Watson et al. (2021)'s imputation*******************************
********************* Kyumin Kim **********************************************************************
********************************* Panel Imputation ****************************************************


*Starting....*
clear
set more off
* NOTE: original `global inpath ...` removed; paths come from config/paths.do

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


*Save tempeporary file*
save "$DERIVED/temp.dta", replace

******* Imputation number 1 - mean value imputation in a given year for missing fishery in a community**********
*******1) Within a given year, filling the missing fishing variables**********
******This imputation procedure follows 1) For missing fishery in a given year and in a communit, 2) observe the revenue of same fisheries in differnet community
****** 3) compute the average of revenue of the same fishery per permit (which is 'fished') across all communities in a given year, this mean values are imputed for missing values.

* Load the temporary data file


* Drop the fisheries that didn't participate in active fishing activity 
drop if fished==0

* Step 1: Calculate the mean revenue per permit for each fishery in each year
bysort fishery year: egen mean_revenue_per_permit = mean(est_earn / fished)

* Step 2: Multiply the mean revenue per permit by the number of permits to get the imputed revenue
gen imputed_est_earn = mean_revenue_per_permit * fished
rename imputed_est_earn est_earn_mean_imputed


******** Imputation2: productivity-factor adjusted revenue imputatioin ********************************
* Step 1: Calculate the community-specific average earning per fishing permits across all fisheries and all years by city
bysort city: egen total_earnings_per_city = total(est_earn_mean_imputed)
bysort city: egen total_fished_per_city = total(fished)
gen avg_earn_per_fisher_city = total_earnings_per_city / total_fished_per_city

* Step 2: Calculate the overall average earning per fisher across all communities
egen total_earnings_all = total(est_earn_mean_imputed)
egen total_fished_all = total(fished)
gen avg_earn_per_fisher_all = total_earnings_all / total_fished_all

* Step 3: Compute the community-specific productivity factor
gen productivity_factor = avg_earn_per_fisher_city / avg_earn_per_fisher_all

* Step 4: Adjust the previously imputed values using the productivity factor
gen est_earn_ft_adj = est_earn_mean_imputed * productivity_factor



*Correlation test if imputed values are close enought to original values 
corr est_earn est_earn_mean_imputed est_earn_ft_adj if est_earn !=. & est_earn_mean_imputed !=. & est_earn_ft_adj !=.

*Now, replacing the missing values of original earning data with the imputed values. 

* Step 5-1: Replace missing values in est_earn with imputed values
gen est_earn_rep= est_earn 
replace est_earn = est_earn_mean_imputed if missing(est_earn)


* Step 5-2: Replace missing values in est_earn with imputed values
replace est_earn_rep = est_earn_ft_adj  if missing(est_earn_rep)



****************** Now create aggregated fishing revenue over fishing communities for merging data at year and community level ******************
collapse (sum) est_earn_mean = est_earn est_earn_ft_adj=est_earn_rep, by(city year)

save "$DERIVED/temp.dta", replace 


/////////////////////////// period 1 //////////////////////////////////////////////

keep if year>=2000 & year<=2008

* Exclude short-observation periods fishing communities
* Filter out cities with less than 8 observations over the observation period
bysort city: gen count = _N
drop if count < 4


********* modification below 
merge m:1 city year using "$DERIVED/wages_year_city_period1.dta", keep(3)
* Drop less observation local economy dataset *****

gen fish_wage_ratio_im= est_earn_mean / wages
gen fish_wage_ratio_im_fc = est_earn_ft_adj / wages


collapse (mean) avg_fish_ratio_im = fish_wage_ratio_im avg_fish_ratio_im_fc=fish_wage_ratio_im_fc, by (city)

gen period=1

*Now make the average ratio 
save "$DERIVED/avg_fish_ratio_im_period1.dta", replace 




/////////////////////////////////////////////////////////////////////////////
//////////////////////////////////// peiord 2 ///////////////////////////////

use "$DERIVED/temp.dta", clear

keep if year >= 2009 & year <=2016


* Exclude short-observation periods fishing communities
* Filter out cities with less than 8 observations over the observation period
bysort city: gen count = _N
drop if count < 4

*After this, total observed fishing communities are 193 again. 


********* modification below 
merge m:1 city year using "$DERIVED/wages_year_city_period2.dta", keep(3)
* Drop less observation local economy dataset *****

gen fish_wage_ratio_im= est_earn_mean / wages
gen fish_wage_ratio_im_fc = est_earn_ft_adj / wages

* 175 cities left 
collapse (mean) avg_fish_ratio_im = fish_wage_ratio_im avg_fish_ratio_im_fc=fish_wage_ratio_im_fc, by (city)

gen period=2 

*Now make the average ratio 
save "$DERIVED/avg_fish_ratio_im_period2.dta", replace
append using "$DERIVED/avg_fish_ratio_im_period1.dta" 

save "$DERIVED/avg_fish_ratio_im_panel_twoperiod", replace
