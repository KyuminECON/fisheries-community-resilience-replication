*-------------------------------------------------------------------------------
* Filename:     22_robustness_hhi.do
* Purpose:      Robustness: EHDF with the inverse-HHI diversification measure (Table S4).
* Inputs:       $DERIVED/master_local_fish_max.dta
* Outputs:      log only; coefficients read from the log
* Requires:     Stata 17+, config/paths.do already included by 00_master.do
* Author:       Reimer (Matt)
*               Ported for the replication package 2026; ONLY paths and this
*               header were changed. Estimation logic is byte-for-byte original
*               except where a line is marked RESTORED / ADDED.
*-------------------------------------------------------------------------------
version 17
set more off

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////// Enhanced hyperbolic distance function (EHDF) by diversification measure ////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

clear
set more off
* NOTE: original `global inpath ...` removed; paths come from config/paths.do
use "$DERIVED/master_local_fish_max.dta"


keep if div_fished_s!=. & mu_reg !=. //* Getting rid of 178-9 observations as a result from 334) /


*Noramlize variables using their geometric mean for convergence  and mean interpretation. 


* Calculate the geometric mean and normalize variables
foreach var in mu_return sigma_reg_exp div_emp div_emp_diff_s div_emp_diff avg_pop broader_emp_share broader_permit_share div_fished_s div_fished avg_fish_ratio_im avg_fish_ratio avg_fish_ratio_im_fc avg_wage_pc avg_fishermen {
    * Calculate the logarithm of the variable
    gen log_`var' = log(`var')
    
    * Calculate the mean of the logarithms
    summarize log_`var'
    scalar gmean_log = r(mean)
    
    * Exponentiate the mean of the logarithms to get the geometric mean
    scalar gmean = exp(gmean_log)
    
    * Normalize the variable using the geometric mean
    gen `var'_norm = `var' / gmean
    
    * Drop the intermediate log variable
    drop log_`var'
}

***** Making log variables for translog approximation

*s1: sigma_reg_exp_norm  / y1= mu_return_norm  / x1: population, x2: wage income per capita, x3: economic diversification
*Noramlizing variabler as depedent variable with negative sign 'n' on LHS


gen n_ln_y1 = -log(mu_return_norm)
gen y1=mu_return_norm

gen x1=avg_pop_norm
gen x2=avg_wage_pc_norm

* Using specailization measure by inverse
// gen x3=1/div_emp_diff_s_norm
// gen x4=1/div_fished_s_norm

// * Using diversficiation measure  direct. 
// gen x3=div_emp_diff_norm
// gen x4=div_fished_norm

gen s1=sigma_reg_exp_norm


*Noramlizing output variables using variable y1(return) using HOD and taking log
gen s1_star= sigma_reg_exp_norm *mu_return_norm
gen ln_s1_star=log(s1_star)

* Normalize the input variable; this is EHDF
gen x1_star=avg_pop_norm * mu_return_norm
gen x2_star=avg_wage_pc_norm * mu_return_norm

// gen x3_star=1/div_emp_diff_s_norm * mu_return_norm
// gen x4_star=1/div_fished_s_norm * mu_return_norm


// * Using inverse HHI
gen x3_star=1/div_emp_diff_norm * mu_return_norm
gen x4_star=1/div_fished_norm * mu_return_norm


*Taking log 
gen ln_x1_star=log(x1_star)
gen ln_x2_star=log(x2_star)
gen ln_x3_star=log(x3_star) 
gen ln_x4_star=log(x4_star) 


*Defining interaction and squared term of input and output

*Squared of input
gen ln_x1sq= 1/2 *(ln_x1_star *ln_x1_star)
gen ln_x2sq= 1/2 *(ln_x2_star *ln_x2_star)
gen ln_x3sq= 1/2 *(ln_x3_star *ln_x3_star)
gen ln_x4sq= 1/2 *(ln_x4_star *ln_x4_star) 

*Interaciton of input

* x1 
gen ln_x1x2= ln_x1_star*ln_x2_star
gen ln_x1x3= ln_x1_star*ln_x3_star
gen ln_x1x4 = ln_x1_star*ln_x4_star

* x2
gen ln_x2x3 = ln_x2_star*ln_x3_star
gen ln_x2x4 = ln_x2_star*ln_x4_star

* x3
gen ln_x3x4 = ln_x3_star*ln_x4_star

*squared of bad output: s1_star
gen ln_s1sq = 1/2 * (ln_s1_star*ln_s1_star)

*interaction of input with s1_star
gen ln_x1s1= ln_x1_star * ln_s1_star
gen ln_x2s1= ln_x2_star * ln_s1_star
gen ln_x3s1= ln_x3_star * ln_s1_star 
gen ln_x4s1= ln_x4_star * ln_s1_star


* inifital value searching for frontier estimation 
reg n_ln_y1 ln_x1_star ln_x2_star ln_x3_star ln_x4_star ln_x1sq ln_x2sq ln_x3sq ln_x4sq ln_x1x2 ln_x1x3 ln_x1x4 ln_x2x3 ln_x2x4 ln_x3x4 ln_s1_star ln_s1sq ln_x1s1 ln_x2s1 ln_x3s1 ln_x3x4
matrix b_ols=e(b)


////////////////////////////////////////////////////////////////////////////////
// Spec 1: complete elasticity and marginal product calculations
////////////////////////////////////////////////////////////////////////////////

* After running the stochastic frontier model for Spec 1:
sfcross n_ln_y1 ln_x1_star ln_x2_star ln_x3_star ln_x4_star ln_x1sq ln_x2sq ln_x3sq ln_x4sq ln_x1x2 ln_x1x3 ln_x1x4 ln_x2x3 ln_x2x4 ln_x3x4 ln_s1_star ln_s1sq ln_x1s1 ln_x2s1 ln_x3s1 ln_x4s1, dist(h) technique(bfgs) iter(500) cost

* After running the stochastic frontier model for Spec 2:(log likelihood 551, squared instability. )
sfcross n_ln_y1 ln_x1_star ln_x2_star ln_x3_star ln_x4_star ln_x1sq ln_x2sq ln_x3sq ln_x4sq ln_x1x2 ln_x1x3 ln_x1x4 ln_x2x3 ln_x2x4 ln_x3x4 ln_s1_star ln_s1sq ln_x1s1 ln_x2s1 ln_x3s1 ln_x4s1, dist(h) technique(nr) usigma(broader_permit_share_norm) iter(500) cost

* After running the stochastic frontier model for Spec 2: (loglikelihood 542)
sfcross n_ln_y1 ln_x1_star ln_x2_star ln_x3_star ln_x4_star ln_x1sq ln_x2sq ln_x3sq ln_x4sq ln_x1x2 ln_x1x3 ln_x1x4 ln_x2x3 ln_x2x4 ln_x3x4 ln_s1_star ln_s1sq ln_x1s1 ln_x2s1 ln_x3s1 ln_x4s1, dist(h) technique(bfgs) usigma(broader_permit_share_norm) iter(500) cost

*Spec 3 (nr, dfp : maxlik. :dfp is more stable)
sfcross n_ln_y1 ln_x1_star ln_x2_star ln_x3_star ln_x4_star ln_x1sq ln_x2sq ln_x3sq ln_x4sq ln_x1x2 ln_x1x3 ln_x1x4 ln_x2x3 ln_x2x4 ln_x3x4 ln_s1_star ln_s1sq ln_x1s1 ln_x2s1 ln_x3s1 ln_x4s1, dist(h) usigma(broader_permit_share_norm avg_fish_ratio_im_norm) cost technique(dfp) posthessian iter(500)

