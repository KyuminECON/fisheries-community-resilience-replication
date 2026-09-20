*-------------------------------------------------------------------------------
* Filename:     20_ehdf_main.do
* Purpose:      Main EHDF estimation: specs 1-3 and community-level marginal products.
* Inputs:       $DERIVED/master_local_fish_max.dta
* Outputs:      $ESTIMATES/ehdf_spec1-3.ster, $DERIVED/marginal_effect_EHDF_div_only.dta
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

gen x3_star=1/div_emp_diff_s_norm * mu_return_norm
gen x4_star=1/div_fished_s_norm * mu_return_norm


// * Using inverse HHI
// gen x3_star=1/div_emp_diff_norm * mu_return_norm
// gen x4_star=1/div_fished_s_norm * mu_return_norm


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
sfcross n_ln_y1 ln_x1_star ln_x2_star ln_x3_star ln_x4_star ln_x1sq ln_x2sq ln_x3sq ln_x4sq ln_x1x2 ln_x1x3 ln_x1x4 ln_x2x3 ln_x2x4 ln_x3x4 ln_s1_star ln_s1sq ln_x1s1 ln_x2s1 ln_x3s1 ln_x4s1, dist(h) technique(bfgs nr dfp) iter(500) cost

// sfcross n_ln_y1 ln_x1_star ln_x2_star ln_x3_star ln_x4_star ln_x1sq ln_x2sq ln_x3sq ln_x4sq ln_x1x2 ln_x1x3 ln_x1x4 ln_x2x3 ln_x2x4 ln_x3x4 ln_s1_star ln_s1sq ln_x1s1 ln_x2s1 ln_x3s1 ln_x4s1, dist(h) technique(bfgs) iter(500) cost

*technique(dfp bfgs)
*technique(bfgs nr dfp) * best for maximization 
*technique(bfgs nr bhhh)

estimates store spec1

********** Testing at means (therefor log at means are zero) for MRT and MP:  **********

** Testing MRT 
nlcom  -(1 + _b[ln_s1_star] + _b[ln_x1_star]+ _b[ln_x2_star] + _b[ln_x3_star] + _b[ln_x4_star]) /(_b[ln_s1_star])

** Testing marginal products at means (using only first-order terms)
* Economic diversification
nlcom  -_b[ln_x3_star] / (1+ _b[ln_s1_star] + _b[ln_x1_star]+ _b[ln_x2_star] + _b[ln_x3_star] + _b[ln_x4_star]) // For economic growth y1
nlcom  -_b[ln_x3_star] / (_b[ln_s1_star]) // For instability 

* Fisheries diversification
nlcom -_b[ln_x4_star] / (1+ _b[ln_s1_star] + _b[ln_x1_star]+ _b[ln_x2_star] + _b[ln_x3_star] + _b[ln_x4_star]) // For economic growth y1
nlcom -_b[ln_x4_star] / (_b[ln_s1_star]) // For instability

////////////////////////////////////////////////////////////////////////////////
// COMPLETE Elasticity Calculations for Spec 1 (including ALL terms)
////////////////////////////////////////////////////////////////////////////////

* Elasticity with respect to x1
predictnl elas_x1_1_e = _b[ln_x1_star] + ///
    _b[ln_x1sq]*ln_x1_star + ///
    _b[ln_x1x2]*ln_x2_star + ///
    _b[ln_x1x3]*ln_x3_star + ///
    _b[ln_x1x4]*ln_x4_star + ///
    _b[ln_x1s1]*ln_s1_star

* Elasticity with respect to x2
predictnl elas_x2_1_e = _b[ln_x2_star] + ///
    _b[ln_x2sq]*ln_x2_star + ///
    _b[ln_x1x2]*ln_x1_star + ///
    _b[ln_x2x3]*ln_x3_star + ///
    _b[ln_x2x4]*ln_x4_star + ///
    _b[ln_x2s1]*ln_s1_star

* Elasticity with respect to x3 (economic diversification)
predictnl elas_x3_1_e = _b[ln_x3_star] + ///
    _b[ln_x3sq]*ln_x3_star + ///
    _b[ln_x1x3]*ln_x1_star + ///
    _b[ln_x2x3]*ln_x2_star + ///
    _b[ln_x3x4]*ln_x4_star + ///
    _b[ln_x3s1]*ln_s1_star

* Elasticity with respect to x4 (fisheries diversification)
predictnl elas_x4_1_e = _b[ln_x4_star] + ///
    _b[ln_x4sq]*ln_x4_star + ///
    _b[ln_x1x4]*ln_x1_star + ///
    _b[ln_x2x4]*ln_x2_star + ///
    _b[ln_x3x4]*ln_x3_star + ///
    _b[ln_x4s1]*ln_s1_star

* Elasticity with respect to s1 (instability)
predictnl elas_s1_1_e = _b[ln_s1_star] + ///
    _b[ln_s1sq]*ln_s1_star + ///
    _b[ln_x1s1]*ln_x1_star + ///
    _b[ln_x2s1]*ln_x2_star + ///
    _b[ln_x3s1]*ln_x3_star + ///
    _b[ln_x4s1]*ln_x4_star

* Elasticity with respect to y1 (using homogeneity condition)
predictnl elas_y1_1_e = 1 + elas_s1_1_e + elas_x1_1_e + elas_x2_1_e + elas_x3_1_e + elas_x4_1_e

////////////////////////////////////////////////////////////////////////////////
// Marginal Product Calculations for Spec 1
////////////////////////////////////////////////////////////////////////////////

* Marginal Rate of Transformation (community-wise)
predictnl mrt_s_y_1_e = -(elas_y1_1_e/elas_s1_1_e) * (s1_star/y1)

* Impact of x3 (economic diversification) on y1 and s1
predictnl mp_x3_y1_1_e = -(elas_x3_1_e/elas_y1_1_e) * (y1/x3_star) // MP on growth
predictnl mp_x3_s1_1_e = mrt_s_y_1_e * mp_x3_y1_1_e // MP on instability (using chain rule)  This is by chain-rule ds/dx3 = ds/dy * dy/dx3

* Impact of x4 (fisheries diversification) on y1 and s1
predictnl mp_x4_y1_1_e = -(elas_x4_1_e/elas_y1_1_e) * (y1/x4_star) // MP on growth
predictnl mp_x4_s1_1_e = mrt_s_y_1_e * mp_x4_y1_1_e // MP on instability (using chain rule) 

* Summary statistics
codebook mp_x3_y1_1_e mp_x3_s1_1_e mp_x4_y1_1_e mp_x4_s1_1_e


//////////////////////////////////////////////////////////////////////////
//// Spec 2: CORRECTED Elasticity and Marginal Product Calculations //////
//////////////////////////////////////////////////////////////////////////

* Run the stochastic frontier model for Spec 2
sfcross n_ln_y1 ln_x1_star ln_x2_star ln_x3_star ln_x4_star ln_x1sq ln_x2sq ln_x3sq ln_x4sq ln_x1x2 ln_x1x3 ln_x1x4 ln_x2x3 ln_x2x4 ln_x3x4 ln_s1_star ln_s1sq ln_x1s1 ln_x2s1 ln_x3s1 ln_x4s1, dist(h) usigma(broader_permit_share_norm) cost technique(dfp bfgs nr) dif iter(500) 
estimates store spec2   // RESTORED (approved): spec1 and spec3 stored theirs, spec2 did not
/////// dfp

* technique(dfp bfgs nr) (best)

// ********** Testing at means **********
// ** Testing MRT 
// nlcom -(1+ _b[ln_s1_star] + _b[ln_x1_star]+ _b[ln_x2_star]+ _b[ln_x3_star] + _b[ln_x4_star]) /(_b[ln_s1_star])
//
// ** Testing marginal products at means (using only first-order terms) * Economic diversification
// nlcom -_b[ln_x3_star] / (1 + _b[ln_s1_star] + _b[ln_x1_star] +_b[ln_x2_star] + _b[ln_x3_star] + _b[ln_x4_star]) // For economic growth y1
// nlcom -_b[ln_x3_star] / (_b[ln_s1_star])  // For instability 
//
// * Fisheries diversification 
// nlcom -_b[ln_x4_star] / (1+ _b[ln_s1_star] + _b[ln_x1_star] +_b[ln_x2_star] + _b[ln_x3_star] + _b[ln_x4_star]) // For economic growth y1
// nlcom -_b[ln_x4_star] / (_b[ln_s1_star]) // For instability
//
// ////////////////////////////////////////////////////////////////////////////////
// // CORRECTED Elasticity Calculations for Spec 2 (including ALL terms)
// ////////////////////////////////////////////////////////////////////////////////
//
// * Elasticity with respect to x1
* RESTORED (approved 2026-09-15): the spec2 block was commented out while
* the downstream `keep` and `estimates restore spec2` still referenced it,
* so the file could not run end to end. Post-estimation export only.
predictnl elas_x1_2_e = _b[ln_x1_star] + ///
    _b[ln_x1sq]*ln_x1_star + ///
    _b[ln_x1x2]*ln_x2_star + ///
    _b[ln_x1x3]*ln_x3_star + ///
    _b[ln_x1x4]*ln_x4_star + ///
    _b[ln_x1s1]*ln_s1_star
//
// * Elasticity with respect to x2
* RESTORED (approved 2026-09-15): the spec2 block was commented out while
* the downstream `keep` and `estimates restore spec2` still referenced it,
* so the file could not run end to end. Post-estimation export only.
predictnl elas_x2_2_e = _b[ln_x2_star] + ///
    _b[ln_x2sq]*ln_x2_star + ///
    _b[ln_x1x2]*ln_x1_star + ///
    _b[ln_x2x3]*ln_x3_star + ///
    _b[ln_x2x4]*ln_x4_star + ///
    _b[ln_x2s1]*ln_s1_star
//
// * Elasticity with respect to x3 (economic diversification)
* RESTORED (approved 2026-09-15): the spec2 block was commented out while
* the downstream `keep` and `estimates restore spec2` still referenced it,
* so the file could not run end to end. Post-estimation export only.
predictnl elas_x3_2_e = _b[ln_x3_star] + ///
    _b[ln_x3sq]*ln_x3_star + ///
    _b[ln_x1x3]*ln_x1_star + ///
    _b[ln_x2x3]*ln_x2_star + ///
    _b[ln_x3x4]*ln_x4_star + ///
    _b[ln_x3s1]*ln_s1_star
//
// * Elasticity with respect to x4 (fisheries diversification)
* RESTORED (approved 2026-09-15): the spec2 block was commented out while
* the downstream `keep` and `estimates restore spec2` still referenced it,
* so the file could not run end to end. Post-estimation export only.
predictnl elas_x4_2_e = _b[ln_x4_star] + ///
    _b[ln_x4sq]*ln_x4_star + ///
    _b[ln_x1x4]*ln_x1_star + ///
    _b[ln_x2x4]*ln_x2_star + ///
    _b[ln_x3x4]*ln_x3_star + ///
    _b[ln_x4s1]*ln_s1_star
//
// * CORRECTED: Elasticity with respect to s1 (instability) - must include ALL interaction terms
* RESTORED (approved 2026-09-15): the spec2 block was commented out while
* the downstream `keep` and `estimates restore spec2` still referenced it,
* so the file could not run end to end. Post-estimation export only.
predictnl elas_s1_2_e = _b[ln_s1_star] + ///
    _b[ln_s1sq]*ln_s1_star + ///
    _b[ln_x1s1]*ln_x1_star + ///
    _b[ln_x2s1]*ln_x2_star + ///
    _b[ln_x3s1]*ln_x3_star + ///
    _b[ln_x4s1]*ln_x4_star
//
// * CORRECTED: Elasticity with respect to y1 (using homogeneity condition) - must include elas_x4_2_e
* RESTORED (approved 2026-09-15): the spec2 block was commented out while
* the downstream `keep` and `estimates restore spec2` still referenced it,
* so the file could not run end to end. Post-estimation export only.
predictnl elas_y1_2_e = 1 + elas_s1_2_e + elas_x1_2_e + elas_x2_2_e + elas_x3_2_e + elas_x4_2_e
//
// ////////////////////////////////////////////////////////////////////////////////
// // CORRECTED Marginal Product Calculations for Spec 2
// ////////////////////////////////////////////////////////////////////////////////
//
// * Marginal Rate of Transformation (community-wise)
* RESTORED (approved 2026-09-15): the spec2 block was commented out while
* the downstream `keep` and `estimates restore spec2` still referenced it,
* so the file could not run end to end. Post-estimation export only.
predictnl mrt_s_y_2_e = -(elas_y1_2_e/elas_s1_2_e) * (s1_star/y1)
//
// * CORRECTED: Impact of x3 (economic diversification) on y1 and s1
* RESTORED (approved 2026-09-15): the spec2 block was commented out while
* the downstream `keep` and `estimates restore spec2` still referenced it,
* so the file could not run end to end. Post-estimation export only.
predictnl mp_x3_y1_2_e = -(elas_x3_2_e/elas_y1_2_e) * (y1/x3_star) // MP on growth (was using elas_x1_2_e incorrectly)
* RESTORED (approved 2026-09-15): the spec2 block was commented out while
* the downstream `keep` and `estimates restore spec2` still referenced it,
* so the file could not run end to end. Post-estimation export only.
predictnl mp_x3_s1_2_e = mrt_s_y_2_e * mp_x3_y1_2_e // MP on instability
//
// * NEW: Impact of x4 (fisheries diversification) on y1 and s1
* RESTORED (approved 2026-09-15): the spec2 block was commented out while
* the downstream `keep` and `estimates restore spec2` still referenced it,
* so the file could not run end to end. Post-estimation export only.
predictnl mp_x4_y1_2_e = -(elas_x4_2_e/elas_y1_2_e) * (y1/x4_star) // MP on growth









* RESTORED (approved 2026-09-15): the spec2 block was commented out while
* the downstream `keep` and `estimates restore spec2` still referenced it,
* so the file could not run end to end. Post-estimation export only.
predictnl mp_x4_s1_2_e = mrt_s_y_2_e * mp_x4_y1_2_e // MP on instability
//
// * Summary statistics
// codebook mp_x3_y1_2_e mp_x3_s1_2_e mp_x4_y1_2_e mp_x4_s1_2_e
//
// * Optional: Display summary statistics
// summarize mp_x3_y1_2_e mp_x3_s1_2_e mp_x4_y1_2_e mp_x4_s1_2_e, detail
//
// ///////////////////////////////////////////////////////////////////////////////////


*Spec 3 (nr, dfp : maxlik. :dfp is more stable)
sfcross n_ln_y1 ln_x1_star ln_x2_star ln_x3_star ln_x4_star ln_x1sq ln_x2sq ln_x3sq ln_x4sq ln_x1x2 ln_x1x3 ln_x1x4 ln_x2x3 ln_x2x4 ln_x3x4 ln_s1_star ln_s1sq ln_x1s1 ln_x2s1 ln_x3s1 ln_x4s1, dist(h) usigma(broader_permit_share_norm avg_fish_ratio_im_norm) cost technique(nr) dif posthessian iter(500)
predict inef,u 
estimates store spec3


///

//
// *---- Export city, inef, longitude, latitude as inefficiency.dta ----*
// preserve
//
// * Verify required variables exist
// foreach v in city inef longitude latitude {
//     capture confirm variable `v'
//     if _rc {
//         di as error "Required variable `v' not found. Aborting export."
//         restore
//         exit 198
//     }
// }
//
// * Keep only needed variables (and order them nicely)
// keep city inef longitude latitude
// order city longitude latitude inef
//
// * Optional: compress to reduce file size
// compress
//
// * Save to your data folder
// save "$DERIVED/inefficiency.dta", replace
//
// restore


///



* To see hessian matrix 
matrix cov_matrix = e(V)
matrix list cov_matrix


*MRT testing 
nlcom - (1+ _b[ln_s1_star] + _b[ln_x1_star]+ _b[ln_x2_star] + _b[ln_x3_star] + _b[ln_x4_star]) /(_b[ln_s1_star])

* MRT testing (inverse)
nlcom - 1/((1+ _b[ln_s1_star] + _b[ln_x1_star]+ _b[ln_x2_star] + _b[ln_x3_star] + _b[ln_x4_star]) /(_b[ln_s1_star]))

*Testing marginal product 
nlcom  -_b[ln_x3_star] / (1+ _b[ln_s1_star] + _b[ln_x1_star]+ _b[ln_x2_star] + _b[ln_x3_star] + _b[ln_x4_star]) // For economic growth y1
nlcom  - _b[ln_x3_star] / (_b[ln_s1_star]) // For instability directly. 
nlcom (- (1+ _b[ln_s1_star] + _b[ln_x1_star]+ _b[ln_x3_star] + _b[ln_x4_star])/(_b[ln_s1_star])) * (- _b[ln_x3_star] /  (1+ _b[ln_s1_star] + _b[ln_x1_star]+ _b[ln_x3_star] + _b[ln_x4_star])) // Using chanin rule ds/dx3 = ds/dy * dy /dx3  evaluted at means. 


*Testing marginal product 
nlcom  -_b[ln_x4_star] / (1+ _b[ln_s1_star] + _b[ln_x1_star]+ _b[ln_x2_star] + _b[ln_x3_star] + _b[ln_x4_star]) // For economic growth y1
nlcom  - _b[ln_x4_star] / (_b[ln_s1_star]) // For instability 
nlcom (- (1+ _b[ln_s1_star] + _b[ln_x1_star]+ _b[ln_x2_star] + _b[ln_x3_star]  + _b[ln_x4_star])/(_b[ln_s1_star])) * (- _b[ln_x4_star] /  (1+ _b[ln_s1_star] + _b[ln_x1_star]+ _b[ln_x2_star] + _b[ln_x3_star] + _b[ln_x4_star])) // Using chanin rule ds/dx3 = ds/dy * dy /dx4 


// Including all variables, I estimate the elasticity for each input and s1 and y1.  
* Elasticity with respect to x_1 
 
predictnl elas_x1_3_e_a= _b[ln_x1_star] +  _b[ln_x1sq]*ln_x1_star + _b[ln_x1x2]*ln_x2_star + _b[ln_x1x3]*ln_x3_star + _b[ln_x1x4]*ln_x4_star +_b[ln_x1s1]*ln_s1_star

* Elaticity with response to x_2 
predictnl elas_x2_3_e_a = _b[ln_x2_star] + _b[ln_x2sq]*ln_x2_star + _b[ln_x1x2]*ln_x1_star + _b[ln_x2x3]*ln_x3_star + _b[ln_x2x4]*ln_x4_star + _b[ln_x2s1]*ln_s1_star

// Elasticity with respect to x3_star
predictnl elas_x3_3_e_a = ///
    _b[ln_x3_star] + ///
    _b[ln_x3sq]*ln_x3_star + ///
    _b[ln_x1x3]*ln_x1_star + ///
    _b[ln_x2x3]*ln_x2_star + ///
    _b[ln_x3x4]*ln_x4_star + ///
    _b[ln_x3s1]*ln_s1_star

// Elasticity with respect to x4_star
predictnl elas_x4_3_e_a = ///
    _b[ln_x4_star] + ///
    _b[ln_x4sq]*ln_x4_star + ///
    _b[ln_x1x4]*ln_x1_star + ///
    _b[ln_x2x4]*ln_x2_star + ///
    _b[ln_x3x4]*ln_x3_star + ///
    _b[ln_x4s1]*ln_s1_star
	
*s1 
predictnl elas_s1_3_e_a =  ( _b[ln_s1_star] + ///
        _b[ln_s1sq]*ln_s1_star + ///
        _b[ln_x1s1]*ln_x1_star + ///
        _b[ln_x2s1]*ln_x2_star + ///
        _b[ln_x3s1]*ln_x3_star + ///
        _b[ln_x4s1]*ln_x4_star )
		
*y1
predictnl elas_y1_3_e_a =  ( 1+ elas_s1_3_e_a + elas_x1_3_e_a + elas_x2_3_e_a + elas_x3_3_e_a + elas_x4_3_e_a ) // Using homogeneity condition 


*Impact of x3 on y1 and s1 
predictnl mp_x3_y1_3_e = -(elas_x3_3_e/elas_y1_3_e) * (y1/x3) // computing mp on growth
predictnl mrt_s_y_3_e = - (elas_y1_3_e/elas_s1_3_e) * (s1/y1) // mrt community wise
predictnl mp_x3_s1_3_e = mrt_s_y_3_e * mp_x3_y1_3_e // This is by chain-rule ds/dx3 = ds/dy * dy/dx3


*Impact of x4 on y1 and s1 
predictnl mp_x4_y1_3_e = -(elas_x4_3_e/elas_y1_3_e) * (y1/x4) // computing mp on growth
predictnl mp_x4_s1_3_e = mrt_s_y_3_e * mp_x4_y1_3_e // commuitng mp on instability 

codebook mp_x3_y1_3_e mp_x3_s1_3_e mp_x4_y1_3_e mp_x4_s1_3_e 



// /// preparation of shadow value price computation 
//
// *Price (value) of employment growth comuptation 
// sum avg_emp // Average employment over community during th year
// *The value of 1% (unit) return Growth employment 
// gen unit_emp_growth= 0.01 *avg_emp // 1% economic growth equivalent number of employment// 
//
// * Community additional income by 1% growth 
// 
// gen wage_income = avg_wage_pc * avg_pop
// gen wage_income_per_emp = wage_income/avg_emp
//
// gen p_y_wage = unit_emp_growth * wage_income_per_emp // 1% economic growth in employment equivlanet to generated wage income to economy 
//
// * Compute shadow value of specilaization  p_y = MP(=elas/elas) *p_x  
// gen shadow_x3 = mp_x3_y1_3_e *p_y_wage
// gen shadow_x4 = mp_x4_y1_3_e * p_y_wage 


keep n_ln_y1 y1 x1 x2 x3 x4 s1 s1_star ln_s1_star x1_star x2_star x3_star x4_star ln_x1_star ln_x2_star ln_x3_star ln_x4_star ln_x1sq ln_x2sq ln_x3sq ln_x4sq ln_x1x2 ln_x1x3 ln_x1x4 ln_x2x3 ln_x2x4 ln_x3x4 ln_s1sq ln_x1s1 ln_x2s1 ln_x3s1 ln_x4s1 elas_x1_1_e elas_x2_1_e elas_x3_1_e elas_x4_1_e elas_s1_1_e elas_y1_1_e mrt_s_y_1_e mp_x3_y1_1_e mp_x3_s1_1_e mp_x4_y1_1_e mp_x4_s1_1_e elas_x1_2_e elas_x2_2_e elas_x3_2_e elas_x4_2_e elas_s1_2_e elas_y1_2_e mrt_s_y_2_e mp_x3_y1_2_e mp_x3_s1_2_e mp_x4_y1_2_e mp_x4_s1_2_e elas_x1_3_e_a elas_x2_3_e_a elas_x3_3_e_a elas_x4_3_e_a elas_s1_3_e_a elas_y1_3_e_a mp_x3_y1_3_e mrt_s_y_3_e mp_x3_s1_3_e mp_x4_y1_3_e mp_x4_s1_3_e

// Save the dataset
save "$DERIVED/marginal_effect_EHDF_div_only.dta", replace


* Save estimation results to disk (spec3 is currently active)
estimates save "$ESTIMATES/ehdf_spec3.ster", replace

estimates restore spec2
estimates save "$ESTIMATES/ehdf_spec2.ster", replace

estimates restore spec1
estimates save "$ESTIMATES/ehdf_spec1.ster", replace

* ----------------------------------------------------------------------------
* TRIMMED 2026-09-18 for the replication package.
* Table S3's three specifications are complete at this point.
* The remainder of the original file re-estimated the frontier and wrote
* artefacts that no script reads and that a later step overwrites; keeping
* them in the package would only invite confusion about which estimate is
* which. Nothing above this line was altered.
* ----------------------------------------------------------------------------
