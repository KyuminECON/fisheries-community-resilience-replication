*-------------------------------------------------------------------------------
* 12_build_master.do: Merge every piece into the master analysis file.
* Inputs:  all $DERIVED pieces built by 01-10
* Outputs: $DERIVED/master_local_fish_max.dta
*-------------------------------------------------------------------------------
version 17
set more off

* Merge all local economies data + fish diversification/ broader share

*Merge Census Code into the anlysis data set.
*use "$DERIVED/temp.dta"
*collapse (first) community__census_area__name, by(city city_id)

* Create a census_area code for fixed-effect for cluster
*encode community__census_area__name, generate(census_id)

clear

use "$DERIVED/growth_and_instability_emp_all.dta" /*growth and instability */

*merging diversification measure
merge m:1 city using "$DERIVED/diversity_emp.dta"
drop _merge

*merge diversification measure diff
merge m:1 city using "$DERIVED/diversity_emp_diff.dta"
drop _merge

*merge pop[ulation data
merge m:1 city using "$DERIVED/avg_pop_l.dta"
drop _merge
drop if city_id ==.

*merge broder reg_emp census_area id
merge m:1 city using "$DERIVED/regional_emp_share.dta"
drop _merge

*merge wage income data
merge m:1 city using "$DERIVED/avg_wage_income.dta"
drop _merge

*Merge the location information
merge m:1 city using "$DERIVED/long_lat.dta"
drop _merge

*merge spatial share of fishing permit
merge m:1 city using "$DERIVED/regional_permit_share_max.dta"
drop _merge

*merge the fish diversification information
merge m:1 city using "$DERIVED/diversity_fish_max.dta"
drop _merge

*merge the fishing revenue / wage income ratio
merge m:1 city using "$DERIVED/avg_fish_ratio.dta"
drop _merge

*merge the fishing revnue / wage income ratio with imputed numbers using Watson et al. 2021
merge m:1 city using "$DERIVED/avg_fish_ratio_im.dta"
drop _merge

*Wage Income per capita / Fisheries Income per capita computation (Should be added to Panel structure)
gen avg_wage_pc=avg_wincome/avg_pop // Before avg_emp, it used to be avg_pop //
label variable avg_wage_pc "Average wage income per capita"

*merge average fishermen
merge m:1 city using "$DERIVED/fishermen.dta"
drop _merge

*make a log-transformation from high metric to low metrics
gen l_avg_wage_pc = log(avg_wage_pc+1)
gen l_avg_pop = log(avg_pop+1)

gen div_emp2=div_emp^2
gen div_emp_diff2=div_emp_diff^2

gen div_emp_diff_s2=div_emp_diff_s^2

*Generate: Urbanity Dummy creation (Only cities in "Fairbanks North Star, Matanusk-Sustina, Anchorage, Jeaneau Borough" are urban by OMB)
gen urbanity=0
replace urbanity=1 if community__census_area__name=="Fairbanks North Star Borough" |  community__census_area__name=="Matanuska-Susitna Borough" | community__census_area__name=="Anchorage Municipality" |  community__census_area__name=="Juneau City and Borough"

*Generate Region variable: clustering boroughs for fixed effect (This classification is following the classification by Bureao of Alaskan Labor Statstics for economic analysis)
gen region_area="Southwest" if community__census_area__name=="Aleutians East Borough" | community__census_area__name=="Aleutians West Census Area" | community__census_area__name== "Bethel Census Area" | community__census_area__name== "Bristol Bay Borough" | community__census_area__name== "Dillingham Census Area" | community__census_area__name== "Kusilvak Census Area" | community__census_area__name=="Lake and Peninsula Borough"

replace region_area="Anchorage/Mat-Su" if community__census_area__name=="Matanuska-Susitna Borough" | community__census_area__name=="Anchorage Municipality" /* Anchorage/Mat-su region*/

replace region_area="Gulf Coast" if community__census_area__name=="Kodiak Island Borough" |  community__census_area__name== "Kenai Peninsula Borough" | community__census_area__name== "Valdez-Cordova Census Area"/* Bristol Bay region*/

replace region_area="Interior" if community__census_area__name=="Denali Borough" | community__census_area__name== "Fairbanks North Star Borough" |community__census_area__name=="Southeast Fairbanks Census Area" |community__census_area__name== "Yukon-Koyukuk Census Area"  /* Kodiak region*/

replace region_area="Northern" if community__census_area__name=="Northwest Arctic Borough" | community__census_area__name=="North Slope Borough" | community__census_area__name== "Nome Census Area"  /* Northern region*/

replace region_area= "Southeast" if community__census_area__name=="Haines Borough" | community__census_area__name== "Juneau City and Borough"| community__census_area__name== "Ketchikan Gateway Borough" | community__census_area__name=="Petersburg Census Area" | community__census_area__name=="Sitka City and Borough" | community__census_area__name=="Yakutat City and Borough" | community__census_area__name=="Hoonah-Angoon Census Area" | community__census_area__name=="Prince of Wales-Hyder Census Area" |community__census_area__name=="Wrangell City and Borough" | community__census_area__name== "Skagway Municipality" /* Southeast region*/

drop city_id

label variable city "city"
label variable mu_emp "Average Employment Growth (Arithmatic)"
label variable mu_emp2 "Squared Average Employment Growth (Arithmatic)"
label variable div_emp "Economic Diversification (HHI-Level)"
label variable div_emp2 "Squared Economic Diversificaiton (HHI-Level)"
label variable div_fished "Fisheries Diversification (Level-HHI)"
label variable div_fished_s "Fisheries Diversification (Level-Shannon)"
label variable sigma_emp "Growth Instability (Arithmatic)"
label variable community__census_area__name "Census area (Borough)"
label variable avg_pop "Average Population"
label variable broader_emp_share "Employment Share within Borough"
label variable broader_permit_share "Fishing Permit Share within Borough"
label variable avg_wage_pc "Average Wage per Capita"
label variable avg_fish_ratio "Fishing Earnings to Wage Income Ratio"
label variable avg_fish_ratio_im "Fishing Earnings to Wage Income Ratio (Mean Imputed)"
label variable avg_fish_ratio_im_fc "Fishing Earnings to Wage Income Ratio (Prod. factor adjusted)"
label variable region_area "Alaska Region"
label variable urbanity "Urbanity dummy"
label variable census_id "Borough"
label variable urbanity "Urbanity"
label variable l_avg_wage_pc "Log Average Wage Income per Capita"
label variable l_avg_pop "Log Average population"
label variable div_emp_diff "Economic Diversification (Growth-HHI)"
label variable div_emp_diff2 "Squared Econ. Diversificaiton (Growth-HHI)"
label variable div_emp_diff_s2 "Squared Econ. Diversification (Growth-Shannon)"
label variable div_emp_diff_s "Economic Diversification (Growth-Shannon)"

*Variable renaming for clear understanding (K: kluge-based manuall. reg: regression based geometric,)
rename mu_emp_k mu_k
rename sigma_emp_k sigma_k
rename l_sigma_emp_k l_sigma_k
rename mu_emp_appx mu_appx
rename sigma_emp_appx sigma_appx
rename mu_emp_reg mu_reg
rename sigma_emp_reg sigma_reg
rename mu_emp mu
rename sigma_emp sigma
rename mu_emp2 mu2
rename sigma_emp_reg_exp sigma_reg_exp

gen mu_k2 = mu_k^2
gen mu_appx2 = mu_appx^2
gen mu_reg2 = mu_reg^2

*Recover return from growth rate for production frontier
gen mu_return=mu_reg + 1

label variable mu_return "Average Return in Employment (Geom) "
label variable mu_reg2 "Squared Average Employment Growth"

* Generate region id
egen region_id=group(region_area)

* Create dummy for anchorage/mat-su region
gen anchorage = (region_area == "Anchorage/Mat-Su")

* Create dummy for gulf coast region
gen gulfcoast = (region_area == "Gulf Coast")

* Create dummy for interior region
gen interior = (region_area == "Interior")

* Create dummy for northern region
gen northern = (region_area == "Northern")

* Create dummy for southeast region
gen southeast = (region_area == "Southeast")

* Create dummy for southwest region
gen southwest = (region_area == "Southwest")

egen median_value = median(div_emp_diff)
generate dummy_econdiv = (div_emp_diff > median_value)

drop mu_k sigma_k l_sigma_k mu_appx sigma_appx mu sigma mu2  mu_k2 mu_appx2 dummy_econdiv median_value

*Total matched observations are 179.

save "$DERIVED/master_local_fish_max.dta", replace /* Save master data set for local economy+fish max*/

* Checks on the merges above (m:1 on city)

use "$DERIVED/master_local_fish_max.dta", clear

* 1. Shannon diversification indices are exponentials of entropy, so >= 1 by
*    construction. A value below 1 means the index was built on a bad share
*    vector (shares not summing to one, or negative employment).
foreach v in div_emp div_emp_diff_s div_fished_s {
    capture confirm variable `v'
    if !_rc {
        quietly count if `v' < 1 & !missing(`v')
        if r(N) > 0 {
            display as error "12_build_master: `v' has `r(N)' values below 1"
            exit 459
        }
    }
}

* 2. The published estimation sample. The `keep if` inside the estimation files
*    leaves 179 rows; listwise deletion across every frontier and usigma
*    regressor gives the 177 reported in Table S1 and Tables S3-S5.
preserve
    quietly keep if div_fished_s != . & mu_reg != .
    local n_keepif = _N
    foreach v in mu_return sigma_reg_exp avg_pop avg_wage_pc ///
                 div_emp_diff_s div_fished_s broader_permit_share avg_fish_ratio_im {
        quietly drop if missing(`v')
    }
    display as text "12_build_master: keep-if sample = `n_keepif', complete cases = `=_N'"
    assert _N == 177
restore

* 3. One row per community in the master file.
quietly duplicates report city
assert r(unique_value) == _N

display as text "12_build_master: all checks passed (`=_N' communities)"
