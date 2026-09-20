*-------------------------------------------------------------------------------
* Filename:     39_panel_export_for_bayes.do
* Purpose:      Export the two-period panel that Table S6's JAGS model reads. NOTE: this is Panel_estimation.do, not the similarly-purposed Interaction/Bayesian_file_panel.do. The difference is decisive: this file normalises each variable by its geometric mean WITHIN each community, which strips the between-community variation and leaves only the across-period variation (sd of ln_x1 about 0.09 rather than 1.5). Bayesian_file_panel.do normalises by the overall geometric mean and yields posteriors an order of magnitude away from Table S6. This file also drops l_avg_pop / l_avg_wage_pc and creates city_id, matching the published panel's column set.
* Inputs:       $DERIVED/complete_panel_dataset.dta
* Outputs:      $DERIVED/processed_dataset.csv
* Requires:     Stata 17+, config/paths.do already included by 00_master.do
* Author:       Kim
*               Ported for the replication package 2026; ONLY paths and this
*               header were changed. Estimation logic is byte-for-byte original
*               except where a line is marked RESTORED / ADDED.
*-------------------------------------------------------------------------------
version 17
set more off

////////////// Panel Robust Check: Production frontier estimation /////////////
///////// 9_27 version. Code author:  Kyumin Kim //////////
///////////////////////////////////////////////////////////

// Clear workspace and set up environment
clear
set more off

// Define input path and load data
* NOTE: original `global inpath ...` removed; paths come from config/paths.do
use  "$DERIVED/complete_panel_dataset.dta"

// Keep observations with non-missing values for key variables
keep if !missing(div_fished_s, mu_emp_reg, avg_pop, avg_wage_pc)

// Generate new variable and rename for consistency
gen mu_return = 1 + mu_emp_reg
rename sigma_emp_reg_exp sigma_reg_exp


// Ensure 'city' is your community identifier (string variable)
// Use 'period' as your time variable

// Step 1: Identify cities that have observations in both periods
// First, tag cities with observations in both periods
bysort city (period): gen byte tag = (_N == 2) & (period[1] != period[2])

// Keep only the observations for cities with tag == 1
keep if tag == 1
drop tag

// Verify that the dataset is strongly balanced
bysort city: gen obs_per_city = _N
tab obs_per_city

// All cities should have 'obs_per_city' equal to 2
// Drop the verification variable
drop obs_per_city l_avg_wage_pc l_avg_pop


// Declare panel structure
encode city, gen(city_id)
xtset city_id period

codebook



// Normalize variables using their geometric mean within each community
foreach var in mu_return sigma_reg_exp div_emp_diff_s div_emp_diff avg_pop ///
                   broader_emp_share broader_permit_share div_fished_s div_fished ///
                   avg_fish_ratio_im avg_fish_ratio_im_fc avg_wage_pc {
    
    // Ensure the variable has positive values (since geometric mean is undefined for non-positive numbers)
    // Handle zeros or negatives if necessary
    count if `var' <= 0
    if r(N) > 0 {
        display as error "`var' contains " r(N) " non-positive values. Please handle these before proceeding."
        // You may choose to add a small constant, exclude these observations, or handle them appropriately
        continue, break
    }

    // Compute the natural logarithm of the variable
    gen ln_`var' = ln(`var')

    // Compute the mean of the logs within each city
    by city, sort: egen mean_ln_`var' = mean(ln_`var')

    // Exponentiate the mean of the logs to get the geometric mean within each city
    gen geomean_`var' = exp(mean_ln_`var')

    // Normalize the variable by dividing it by the geometric mean
    gen `var'_norm = `var' / geomean_`var'

    // Optionally, drop the intermediate variables
    drop ln_`var' mean_ln_`var' geomean_`var'
}




***** Making log variables for translog approximation

*s1: sigma_reg_exp_norm  / y1= mu_return_norm  / x1: population, x2: wage income per capita, x3: economic diversification

*Noramlizing variabler as depedent variable with negative sign 'n' on LHS
gen y1=mu_return_norm
gen ln_y1=log(y1)
gen n_ln_y1 = -log(y1)


*Noramlizing output variables using variable y1(return) using HOD and taking log
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



/// data export 

// /// data export 
export delimited using "$DERIVED/processed_dataset.csv", replace


//
//
// *Defining interaction and squared term of input and output
//
// *Squared of input
// gen ln_x1sq= 1/2 *(ln_x1 *ln_x1)
// gen ln_x2sq= 1/2 *(ln_x2 *ln_x2)
// gen ln_x3sq= 1/2 *(ln_x3 *ln_x3)
// gen ln_x4sq= 1/2 *(ln_x4 *ln_x4)
//
// *Interaciton of input
// gen ln_x1x2= ln_x1*ln_x2
// gen ln_x1x3= ln_x1*ln_x3
// gen ln_x1x4= ln_x1*ln_x4
//
// gen ln_x2x3 = ln_x2*ln_x3
// gen ln_x2x4 = ln_x2*ln_x4 
// gen ln_x3x4 = ln_x3*ln_x4 
//
//
// *squared of bad output: s1_star
// gen ln_s1sq = 1/2 * (ln_s1_star*ln_s1_star)
//
// *interaction of input with s1_star
// gen ln_x1s1= ln_x1 * ln_s1_star
// gen ln_x2s1= ln_x2 * ln_s1_star
// gen ln_x3s1= ln_x3 * ln_s1_star 
// gen ln_x4s1= ln_x4 * ln_s1_star 
//
//
//
// // Time-varying ishift term 
// gen time=1 if period==2 
// replace time=0 if time==.
//
//
//
// gen ln_emp_share = log(broader_emp_share_norm)
// gen ln_fish_share = log(broader_permit_share_norm)
// gen ln_fish_ratio = log(avg_fish_ratio_im_norm)
//
// //////////
//
//
//
// * inifital value searching for frontier estimation (if needed for convergence issue)
// reg n_ln_y1 ln_x1 ln_x2 ln_x3 ln_x4  ln_x1sq ln_x2sq ln_x3sq ln_x4sq ln_x1x2 ln_x1x3 ln_x1x4 ln_x2x3 ln_x2x4 ln_x3x4 ln_s1_star ln_s1sq ln_x1s1 ln_x2s1 ln_x3s1 ln_x4s1
// matrix b_ols=e(b)
//
//
// *Spect1 (no control)
// sfcross  n_ln_y1 ln_x1 ln_x2 ln_x3 ln_x4  ln_x1sq ln_x2sq ln_x3sq ln_x4sq ln_x1x2 ln_x1x3 ln_x1x4 ln_x2x3 ln_x2x4 ln_x3x4 ln_s1_star ln_s1sq ln_x1s1 ln_x2s1 ln_x3s1 ln_x4s1 time, dist(h)  technique(nr)  iter(500)
//
// *Spect2 (broader share)
// sfcross  n_ln_y1 ln_x1 ln_x2 ln_x3 ln_x4  ln_x1sq ln_x2sq ln_x3sq ln_x4sq ln_x1x2 ln_x1x3 ln_x1x4 ln_x2x3 ln_x2x4 ln_x3x4 ln_s1_star ln_s1sq ln_x1s1 ln_x2s1 ln_x3s1 ln_x4s1 time, dist(h) usigma(broader_emp_share_norm broader_permit_share_norm) technique(nr) iter(500) dif 
//
// *Spec3: 
// sfcross  n_ln_y1 ln_x1 ln_x2 ln_x3 ln_x4  ln_x1sq ln_x2sq ln_x3sq ln_x4sq ln_x1x2 ln_x1x3 ln_x1x4 ln_x2x3 ln_x2x4 ln_x3x4 ln_s1_star ln_s1sq ln_x1s1 ln_x2s1 ln_x3s1 ln_x4s1 time, dist(h) usigma(broader_emp_share_norm broader_permit_share_norm avg_fish_ratio_im_norm) technique(bfgs) iter(500)
//
// *Spect4: (Time-varying efficiency)
// sfcross  n_ln_y1 ln_x1 ln_x2 ln_x3 ln_x4  ln_x1sq ln_x2sq ln_x3sq ln_x4sq ln_x1x2 ln_x1x3 ln_x1x4 ln_x2x3 ln_x2x4 ln_x3x4 ln_s1_star ln_s1sq ln_x1s1 ln_x2s1 ln_x3s1 ln_x4s1 time, dist(h) usigma(broader_emp_share_norm broader_permit_share_norm avg_fish_ratio_im_norm time) technique(dfp) iter(500)
//
//
//
// ///// With time dummry 
//
// * inifital value searching for frontier estimation (if needed for convergence issue)
// reg n_ln_y1 ln_x1 ln_x2 ln_x3 ln_x4  ln_x1sq ln_x2sq ln_x3sq ln_x4sq ln_x1x2 ln_x1x3 ln_x1x4 ln_x2x3 ln_x2x4 ln_x3x4 ln_s1_star ln_s1sq ln_x1s1 ln_x2s1 ln_x3s1 ln_x4s1 time
// matrix b_ols=e(b)
//
//
//
// *Spect1 (no control)
// sfcross  n_ln_y1 ln_x1 ln_x2 ln_x3 ln_x4  ln_x1sq ln_x2sq ln_x3sq ln_x4sq ln_x1x2 ln_x1x3 ln_x1x4 ln_x2x3 ln_x2x4 ln_x3x4 ln_s1_star ln_s1sq ln_x1s1 ln_x2s1 ln_x3s1 ln_x4s1 time , dist(h) technique(nr)  iter(500)
//
//
// *Spect2 (broader share)
// sfcross  n_ln_y1 ln_x1 ln_x2 ln_x3 ln_x4  ln_x1sq ln_x2sq ln_x3sq ln_x4sq ln_x1x2 ln_x1x3 ln_x1x4 ln_x2x3 ln_x2x4 ln_x3x4 ln_s1_star ln_s1sq ln_x1s1 ln_x2s1 ln_x3s1 ln_x4s1 time, dist(h) usigma(broader_permit_share_norm ) technique(bfgs) iter(500) dif 
//
//
// *Spect3 (broader share)
// sfcross  n_ln_y1 ln_x1 ln_x2 ln_x3 ln_x4  ln_x1sq ln_x2sq ln_x3sq ln_x4sq ln_x1x2 ln_x1x3 ln_x1x4 ln_x2x3 ln_x2x4 ln_x3x4 ln_s1_star ln_s1sq ln_x1s1 ln_x2s1 ln_x3s1 ln_x4s1 time, dist(h) usigma(broader_emp_share_norm ) technique(bfgs) iter(500) dif 
//
// *Spec (time broader- share fish)
// *Spect2 (broader share)
// sfcross  n_ln_y1 ln_x1 ln_x2 ln_x3 ln_x4  ln_x1sq ln_x2sq ln_x3sq ln_x4sq ln_x1x2 ln_x1x3 ln_x1x4 ln_x2x3 ln_x2x4 ln_x3x4 ln_s1_star ln_s1sq ln_x1s1 ln_x2s1 ln_x3s1 ln_x4s1 time, dist(h) usigma(broader_permit_share_norm avg_fish_ratio_im_norm ) technique(bfgs) iter(500) dif 
//
//
//
// *Inspection mode , step wise. 
//
//
// *No control
// sfcross  n_ln_y1 ln_x1 ln_x2 ln_x3 ln_x4  ln_x1sq ln_x2sq ln_x3sq ln_x4sq ln_x1x2 ln_x1x3 ln_x1x4 ln_x2x3 ln_x2x4 ln_x3x4 ln_s1_star ln_s1sq ln_x1s1 ln_x2s1 ln_x3s1 ln_x4s1 time , dist(h) technique(nr)  iter(500)
//
//
// *Emp share
// sfcross  n_ln_y1 ln_x1 ln_x2 ln_x3 ln_x4  ln_x1sq ln_x2sq ln_x3sq ln_x4sq ln_x1x2 ln_x1x3 ln_x1x4 ln_x2x3 ln_x2x4 ln_x3x4 ln_s1_star ln_s1sq ln_x1s1 ln_x2s1 ln_x3s1 ln_x4s1 time , dist(h) technique(nr) usigma(broader_emp_share_norm)  iter(500)
//
// *fish share
// sfcross  n_ln_y1 ln_x1 ln_x2 ln_x3 ln_x4  ln_x1sq ln_x2sq ln_x3sq ln_x4sq ln_x1x2 ln_x1x3 ln_x1x4 ln_x2x3 ln_x2x4 ln_x3x4 ln_s1_star ln_s1sq ln_x1s1 ln_x2s1 ln_x3s1 ln_x4s1 time , dist(h) usigma(broader_permit_share_norm) technique(nr)  iter(500)
//
// *avg fishereis ratio 
// sfcross  n_ln_y1 ln_x1 ln_x2 ln_x3 ln_x4  ln_x1sq ln_x2sq ln_x3sq ln_x4sq ln_x1x2 ln_x1x3 ln_x1x4 ln_x2x3 ln_x2x4 ln_x3x4 ln_s1_star ln_s1sq ln_x1s1 ln_x2s1 ln_x3s1 ln_x4s1 time , usigma(avg_fish_ratio_im_norm) dist(h) technique(nr)  iter(500)
//
//
// * share+fish_ratiop
// sfcross  n_ln_y1 ln_x1 ln_x2 ln_x3 ln_x4  ln_x1sq ln_x2sq ln_x3sq ln_x4sq ln_x1x2 ln_x1x3 ln_x1x4 ln_x2x3 ln_x2x4 ln_x3x4 ln_s1_star ln_s1sq ln_x1s1 ln_x2s1 ln_x3s1 ln_x4s1 time , dist(h) technique(nr) usigma(avg_fish_ratio_im_norm broader_emp_share_norm)  iter(500)
//
//
// * fish+avg_fish_ratio_im
// sfcross  n_ln_y1 ln_x1 ln_x2 ln_x3 ln_x4  ln_x1sq ln_x2sq ln_x3sq ln_x4sq ln_x1x2 ln_x1x3 ln_x1x4 ln_x2x3 ln_x2x4 ln_x3x4 ln_s1_star ln_s1sq ln_x1s1 ln_x2s1 ln_x3s1 ln_x4s1 time , dist(h) technique(nr) usigma(avg_fish_ratio_im_norm broader_permit_share_norm)  iter(500)
//
//
// * braoders 
// sfcross  n_ln_y1 ln_x1 ln_x2 ln_x3 ln_x4  ln_x1sq ln_x2sq ln_x3sq ln_x4sq ln_x1x2 ln_x1x3 ln_x1x4 ln_x2x3 ln_x2x4 ln_x3x4 ln_s1_star ln_s1sq ln_x1s1 ln_x2s1 ln_x3s1 ln_x4s1 time , dist(h) technique(nr) usigma(broader_emp_share_norm broader_permit_share_norm)  iter(500)
//
//
// //////
//
// *No control
// sfcross  n_ln_y1 ln_x1 ln_x2 ln_x3 ln_x4  ln_x1sq ln_x2sq ln_x3sq ln_x4sq ln_x1x2 ln_x1x3 ln_x1x4 ln_x2x3 ln_x2x4 ln_x3x4 ln_s1_star ln_s1sq ln_x1s1 ln_x2s1 ln_x3s1 ln_x4s1 time , dist(h) technique(nr)  iter(500)
//
//
// *Emp share
// sfcross  n_ln_y1 ln_x1 ln_x2 ln_x3 ln_x4  ln_x1sq ln_x2sq ln_x3sq ln_x4sq ln_x1x2 ln_x1x3 ln_x1x4 ln_x2x3 ln_x2x4 ln_x3x4 ln_s1_star ln_s1sq ln_x1s1 ln_x2s1 ln_x3s1 ln_x4s1 time , dist(h) technique(nr) usigma(ln_emp_share)  iter(500)
//
// *fish share
// sfcross  n_ln_y1 ln_x1 ln_x2 ln_x3 ln_x4  ln_x1sq ln_x2sq ln_x3sq ln_x4sq ln_x1x2 ln_x1x3 ln_x1x4 ln_x2x3 ln_x2x4 ln_x3x4 ln_s1_star ln_s1sq ln_x1s1 ln_x2s1 ln_x3s1 ln_x4s1 time , dist(h) usigma(ln_fish_share) technique(nr)  iter(500)
//
// *avg fishereis ratio 
// sfcross  n_ln_y1 ln_x1 ln_x2 ln_x3 ln_x4  ln_x1sq ln_x2sq ln_x3sq ln_x4sq ln_x1x2 ln_x1x3 ln_x1x4 ln_x2x3 ln_x2x4 ln_x3x4 ln_s1_star ln_s1sq ln_x1s1 ln_x2s1 ln_x3s1 ln_x4s1 time , usigma(ln_fish_ratio) dist(h) technique(nr)  iter(500)
//
//
// * share+fish_ratiop
// sfcross  n_ln_y1 ln_x1 ln_x2 ln_x3 ln_x4  ln_x1sq ln_x2sq ln_x3sq ln_x4sq ln_x1x2 ln_x1x3 ln_x1x4 ln_x2x3 ln_x2x4 ln_x3x4 ln_s1_star ln_s1sq ln_x1s1 ln_x2s1 ln_x3s1 ln_x4s1 time , dist(h) technique(nr) usigma(ln_emp_share ln_fish_ratio)  iter(500)
//
//
// * fish+avg_fish_ratio_im
// sfcross  n_ln_y1 ln_x1 ln_x2 ln_x3 ln_x4  ln_x1sq ln_x2sq ln_x3sq ln_x4sq ln_x1x2 ln_x1x3 ln_x1x4 ln_x2x3 ln_x2x4 ln_x3x4 ln_s1_star ln_s1sq ln_x1s1 ln_x2s1 ln_x3s1 ln_x4s1 time , dist(h) technique(nr) usigma(ln_fish_share ln_fish_ratio)  iter(500)
//
//
// * braoders 
// sfcross  n_ln_y1 ln_x1 ln_x2 ln_x3 ln_x4  ln_x1sq ln_x2sq ln_x3sq ln_x4sq ln_x1x2 ln_x1x3 ln_x1x4 ln_x2x3 ln_x2x4 ln_x3x4 ln_s1_star ln_s1sq ln_x1s1 ln_x2s1 ln_x3s1 ln_x4s1 time , dist(h) technique(nr) usigma(ln_emp_share ln_fish_share)  iter(500)
//
// *
// sfcross  n_ln_y1 ln_x1 ln_x2 ln_x3 ln_x4  ln_x1sq ln_x2sq ln_x3sq ln_x4sq ln_x1x2 ln_x1x3 ln_x1x4 ln_x2x3 ln_x2x4 ln_x3x4 ln_s1_star ln_s1sq ln_x1s1 ln_x2s1 ln_x3s1 ln_x4s1 time , dist(h) technique(nr) usigma(ln_emp_share ln_fish_share ln_fish_ratio)  iter(500)
//
//
//
//
// ///////////////////////////////
//
//
// drop y1 n_ln_y1 s1_star ln_s1_star x2 x1 x3 x4 ln_x1 ln_x2 ln_x3 ln_x4 ln_x1sq ln_x2sq ln_x3sq ln_x4sq ln_x1x2 ln_x1x3 ln_x1x4 ln_x2x3 ln_x2x4 ln_x3x4 ln_s1sq ln_x1s1 ln_x2s1 ln_x3s1 ln_x4s1
//
//
//
// //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// ///// the enhanced hyperbolic distnace fuctnion: Production fronteir estimation using hyperbolic distance function  //////////////
// //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// // Clear workspace and set up environment
// clear
// set more off
//
// // Define input path and load data
// global inpath "/Users/kyuminkim/Google Drive/Dissertation /Alaska fisheries diversification/current working/all_data"
// use  "$DERIVED/complete_panel_dataset.dta"
//
// // Keep observations with non-missing values for key variables
// keep if !missing(div_fished_s, mu_emp_reg, avg_pop, avg_wage_pc)
//
// // Generate new variable and rename for consistency
// gen mu_return = 1 + mu_emp_reg
// rename sigma_emp_reg_exp sigma_reg_exp
//
//
// // Ensure 'city' is your community identifier (string variable)
// // Use 'period' as your time variable
//
// // Step 1: Identify cities that have observations in both periods
// // First, tag cities with observations in both periods
// bysort city (period): gen byte tag = (_N == 2) & (period[1] != period[2])
//
// // Keep only the observations for cities with tag == 1
// keep if tag == 1
// drop tag
//
// // Verify that the dataset is strongly balanced
// bysort city: gen obs_per_city = _N
// tab obs_per_city
//
// // All cities should have 'obs_per_city' equal to 2
// // Drop the verification variable
// drop obs_per_city
//
// // Normalize variables using their geometric mean within each community
// foreach var in mu_return sigma_reg_exp div_emp_diff_s div_emp_diff avg_pop ///
//                    broader_emp_share broader_permit_share div_fished_s div_fished ///
//                    avg_fish_ratio_im avg_fish_ratio_im_fc avg_wage_pc {
//    
//     // Ensure the variable has positive values (since geometric mean is undefined for non-positive numbers)
//     // Handle zeros or negatives if necessary
//     count if `var' <= 0
//     if r(N) > 0 {
//         display as error "`var' contains " r(N) " non-positive values. Please handle these before proceeding."
//         // You may choose to add a small constant, exclude these observations, or handle them appropriately
//         continue, break
//     }
//
//     // Compute the natural logarithm of the variable
//     gen ln_`var' = ln(`var')
//
//     // Compute the mean of the logs within each city
//     by city, sort: egen mean_ln_`var' = mean(ln_`var')
//
//     // Exponentiate the mean of the logs to get the geometric mean within each city
//     gen geomean_`var' = exp(mean_ln_`var')
//
//     // Normalize the variable by dividing it by the geometric mean
//     gen `var'_norm = `var' / geomean_`var'
//
//     // Optionally, drop the intermediate variables
//     drop ln_`var' mean_ln_`var' geomean_`var'
// }
//
//
//
// gen n_ln_y1 = -log(mu_return_norm)
// gen y1=mu_return_norm
//
//
//
// *Noramlizing output variables using variable y1(return) using HOD and taking log
// gen s1_star= sigma_reg_exp_norm *mu_return_norm
// gen ln_s1_star=log(s1_star)
//
//
// *Redefining of input variable and taking log 
// gen x1_star=avg_pop_norm * mu_return_norm
// gen x2_star=avg_wage_pc_norm * mu_return_norm
// gen x3_star=div_emp_diff_s_norm * mu_return_norm
// gen x4_star=div_fished_s_norm * mu_return_norm
//
//
// gen ln_x1_star=log(x1_star)
// gen ln_x2_star=log(x2_star)
// gen ln_x3_star=log(1/x3_star) // making it as specialization index. 
// gen ln_x4_star=log(1/x4_star) 
//
//
// *Defining interaction and squared term of input and output
//
// *Squared of input
// gen ln_x1sq= 1/2 *(ln_x1_star *ln_x1_star)
// gen ln_x2sq= 1/2 *(ln_x2_star *ln_x2_star)
// gen ln_x3sq= 1/2 *(ln_x3_star *ln_x3_star)
// gen ln_x4sq= 1/2 *(ln_x4_star *ln_x4_star) 
//
// *Interaciton of input
// gen ln_x1x2= ln_x1_star*ln_x2_star
// gen ln_x1x3= ln_x1_star*ln_x3_star
// gen ln_x1x4 = ln_x1_star*ln_x4_star
//
// gen ln_x2x3 = ln_x2_star*ln_x3_star
// gen ln_x2x4 = ln_x2_star*ln_x4_star
//
// gen ln_x3x4 = ln_x3_star*ln_x4_star
//
//
// *squared of bad output: s1_star
// gen ln_s1sq = 1/2 * (ln_s1_star*ln_s1_star)
//
// *interaction of input with s1_star
// gen ln_x1s1= ln_x1_star * ln_s1_star
// gen ln_x2s1= ln_x2_star * ln_s1_star
// gen ln_x3s1= ln_x3_star * ln_s1_star 
// gen ln_x4s1= ln_x4_star * ln_s1_star
//
// // Time-varying ishift term 
// gen time=1 if period==2 
// replace time=0 if time==.
//
//
//
// *Spec 1 (nr, dfp : maxlik. :dfp is more stable)
// sfcross n_ln_y1 ln_x1_star ln_x2_star ln_x3_star ln_x4_star ln_x1sq ln_x2sq ln_x3sq ln_x4sq ln_x1x2 ln_x1x3 ln_x1x4 ln_x2x3 ln_x2x4 ln_x3x4 ln_s1_star ln_s1sq ln_x1s1 ln_x2s1 ln_x3s1 ln_x4s1 time, dist(h) technique(nr) dif
//
//
// *Spec 2 (nr, dfp : maxlik. :dfp is more stable)
// sfcross n_ln_y1 ln_x1_star ln_x2_star ln_x3_star ln_x4_star ln_x1sq ln_x2sq ln_x3sq ln_x4sq ln_x1x2 ln_x1x3 ln_x1x4 ln_x2x3 ln_x2x4 ln_x3x4 ln_s1_star ln_s1sq ln_x1s1 ln_x2s1 ln_x3s1 ln_x4s1 time, dist(h) usigma(broader_emp_share_norm broader_permit_share_norm ) technique(nr)
//
//
//
// *Spec 3 (nr, dfp : maxlik. :dfp is more stable)
// sfcross n_ln_y1 ln_x1_star ln_x2_star ln_x3_star ln_x4_star ln_x1sq ln_x2sq ln_x3sq ln_x4sq ln_x1x2 ln_x1x3 ln_x1x4 ln_x2x3 ln_x2x4 ln_x3x4 ln_s1_star ln_s1sq ln_x1s1 ln_x2s1 ln_x3s1 ln_x4s1 time, dist(h) usigma(broader_emp_share_norm broader_permit_share_norm avg_fish_ratio_im_norm) technique(nr)
//
// *Spec 3_t time (nr, dfp : maxlik. :dfp is more stable)
// sfcross n_ln_y1 ln_x1_star ln_x2_star ln_x3_star ln_x4_star ln_x1sq ln_x2sq ln_x3sq ln_x4sq ln_x1x2 ln_x1x3 ln_x1x4 ln_x2x3 ln_x2x4 ln_x3x4 ln_s1_star ln_s1sq ln_x1s1 ln_x2s1 ln_x3s1 ln_x4s1 time, dist(h) usigma(broader_emp_share_norm broader_permit_share_norm avg_fish_ratio_im_norm time) technique(nr)
//
//
// /////// experiments //////
//
//
//
// *No control
// sfcross n_ln_y1 ln_x1_star ln_x2_star ln_x3_star ln_x4_star ln_x1sq ln_x2sq ln_x3sq ln_x4sq ln_x1x2 ln_x1x3 ln_x1x4 ln_x2x3 ln_x2x4 ln_x3x4 ln_s1_star ln_s1sq ln_x1s1 ln_x2s1 ln_x3s1 ln_x4s1 time, dist(h) technique(nr)  iter(500)
//
// *Emp share
// sfcross n_ln_y1 ln_x1_star ln_x2_star ln_x3_star ln_x4_star ln_x1sq ln_x2sq ln_x3sq ln_x4sq ln_x1x2 ln_x1x3 ln_x1x4 ln_x2x3 ln_x2x4 ln_x3x4 ln_s1_star ln_s1sq ln_x1s1 ln_x2s1 ln_x3s1 ln_x4s1 time, dist(h) technique(nr) usigma(broader_emp_share_norm)  iter(500)
//
// *fish share
// sfcross n_ln_y1 ln_x1_star ln_x2_star ln_x3_star ln_x4_star ln_x1sq ln_x2sq ln_x3sq ln_x4sq ln_x1x2 ln_x1x3 ln_x1x4 ln_x2x3 ln_x2x4 ln_x3x4 ln_s1_star ln_s1sq ln_x1s1 ln_x2s1 ln_x3s1 ln_x4s1 time, dist(h) usigma(broader_permit_share_norm) technique(nr)  iter(500)
//
// *avg fishereis ratio 
// sfcross n_ln_y1 ln_x1_star ln_x2_star ln_x3_star ln_x4_star ln_x1sq ln_x2sq ln_x3sq ln_x4sq ln_x1x2 ln_x1x3 ln_x1x4 ln_x2x3 ln_x2x4 ln_x3x4 ln_s1_star ln_s1sq ln_x1s1 ln_x2s1 ln_x3s1 ln_x4s1 time, usigma(avg_fish_ratio_im_norm) dist(h) technique(dfp)  iter(500)
//
// * share+fish_ratiop
// sfcross n_ln_y1 ln_x1_star ln_x2_star ln_x3_star ln_x4_star ln_x1sq ln_x2sq ln_x3sq ln_x4sq ln_x1x2 ln_x1x3 ln_x1x4 ln_x2x3 ln_x2x4 ln_x3x4 ln_s1_star ln_s1sq ln_x1s1 ln_x2s1 ln_x3s1 ln_x4s1 time, dist(h) technique(nr) usigma(avg_fish_ratio_im_norm broader_emp_share_norm)  iter(500)
//
// * fish+avg_fish_ratio_im
// sfcross n_ln_y1 ln_x1_star ln_x2_star ln_x3_star ln_x4_star ln_x1sq ln_x2sq ln_x3sq ln_x4sq ln_x1x2 ln_x1x3 ln_x1x4 ln_x2x3 ln_x2x4 ln_x3x4 ln_s1_star ln_s1sq ln_x1s1 ln_x2s1 ln_x3s1 ln_x4s1 time, dist(h) technique(nr) usigma(avg_fish_ratio_im_norm broader_permit_share_norm)  iter(500)
//
//
// * braoders 
// sfcross n_ln_y1 ln_x1_star ln_x2_star ln_x3_star ln_x4_star ln_x1sq ln_x2sq ln_x3sq ln_x4sq ln_x1x2 ln_x1x3 ln_x1x4 ln_x2x3 ln_x2x4 ln_x3x4 ln_s1_star ln_s1sq ln_x1s1 ln_x2s1 ln_x3s1 ln_x4s1 time , dist(h) technique(nr) usigma(broader_emp_share_norm broader_permit_share_norm)  iter(500)
//
//
//
// *Testing marginal product of economic diversification  
// nlcom  - _b[ln_x3_star] / (1+ _b[ln_s1_star] + _b[ln_x1_star]+ _b[ln_x3_star] + _b[ln_x4_star]) // For economic growth y1 -- using homogeneity condition ( 1+ bad elas + \sum input elasticity)
// nlcom  - _b[ln_x3_star] / (_b[ln_s1_star])  // For instability 
// nlcom (- (1+ _b[ln_s1_star] + _b[ln_x1_star]+ _b[ln_x3_star] + _b[ln_x4_star])/(_b[ln_s1_star])) * (- _b[ln_x3_star] /  (1+ _b[ln_s1_star] + _b[ln_x1_star]+ _b[ln_x3_star] + _b[ln_x4_star])) // Using chanin rule ds/dx3 = ds/dy * dy /dx3 
//
// *Testing marginal product of fisheries diversification 
// nlcom - _b[ln_x4_star] / (1+ _b[ln_s1_star] + _b[ln_x1_star]+ _b[ln_x3_star] + _b[ln_x4_star])
// nlcom - _b[ln_x4_star] / ( _b[ln_s1_star])
// nlcom (- (1+ _b[ln_s1_star] + _b[ln_x1_star]+ _b[ln_x3_star] + _b[ln_x4_star])/(_b[ln_s1_star])) * (- _b[ln_x4_star] /  (1+ _b[ln_s1_star] + _b[ln_x1_star]+ _b[ln_x3_star] + _b[ln_x4_star])) // Using chanin rule ds/dx3 = ds/dy * dy /dx4 
//


