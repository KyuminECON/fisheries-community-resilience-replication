*-------------------------------------------------------------------------------
* 39_panel_export_for_bayes.do: Export the two-period panel that the Table S6 JAGS model reads.
* Inputs:  $DERIVED/complete_panel_dataset.dta
* Outputs: $DERIVED/processed_dataset.csv
*-------------------------------------------------------------------------------
version 17
set more off

* Panel Robust Check: Production frontier estimation

clear
set more off

use  "$DERIVED/complete_panel_dataset.dta"

keep if !missing(div_fished_s, mu_emp_reg, avg_pop, avg_wage_pc)

gen mu_return = 1 + mu_emp_reg
rename sigma_emp_reg_exp sigma_reg_exp

bysort city (period): gen byte tag = (_N == 2) & (period[1] != period[2])

keep if tag == 1
drop tag

bysort city: gen obs_per_city = _N
tab obs_per_city

drop obs_per_city l_avg_wage_pc l_avg_pop

encode city, gen(city_id)
xtset city_id period

codebook

foreach var in mu_return sigma_reg_exp div_emp_diff_s div_emp_diff avg_pop ///
                   broader_emp_share broader_permit_share div_fished_s div_fished ///
                   avg_fish_ratio_im avg_fish_ratio_im_fc avg_wage_pc {

    count if `var' <= 0
    if r(N) > 0 {
        display as error "`var' contains " r(N) " non-positive values. Please handle these before proceeding."
        continue, break
    }

    gen ln_`var' = ln(`var')

    by city, sort: egen mean_ln_`var' = mean(ln_`var')

    gen geomean_`var' = exp(mean_ln_`var')

    gen `var'_norm = `var' / geomean_`var'

    drop ln_`var' mean_ln_`var' geomean_`var'
}

* Making log variables for translog approximation

*s1: sigma_reg_exp_norm  / y1= mu_return_norm  / x1: population, x2: wage income per capita, x3: economic diversification

*Negative log of growth as the dependent variable
gen y1=mu_return_norm
gen ln_y1=log(y1)
gen n_ln_y1 = -log(y1)

*Normalize by growth (homogeneity) and take logs
gen s1=sigma_reg_exp_norm
gen ln_s1=log(s1)
gen s1_star= sigma_reg_exp_norm *mu_return_norm
gen ln_s1_star=log(s1_star)

*Redefining of input variable and taking log
gen x1=avg_pop_norm
gen x2=avg_wage_pc_norm
gen x3=1/div_emp_diff_s_norm
gen x4=1/div_fished_s_norm

gen ln_x1=log(x1)
gen ln_x2=log(x2)
gen ln_x3=log(x3)
gen ln_x4=log(x4)

* data export

export delimited using "$DERIVED/processed_dataset.csv", replace
