*-------------------------------------------------------------------------------
* Filename:     25_marginal_effects.do
* Purpose:      Community-level marginal effects for HDF and EHDF. Needed by code/R: Fig. 2 takes its high/low fisheries-diversification split from the quartiles of this frame. The HDF half is dissertation-only and is not a submitted exhibit; it is kept only because the figure code merges the two frames. NOTE: the sibling All_four_dist_comp_test.do also writes these files but references elas_x3_3 etc. that it never defines, so it cannot run; this file is complete.
* Inputs:       $DERIVED/master_local_fish_max.dta
* Outputs:      $DERIVED/marginal_effect_HDF.dta, marginal_effect_EHDF.dta
* Requires:     Stata 17+, config/paths.do already included by 00_master.do
* Author:       Kim
*               Ported for the replication package 2026; ONLY paths and this
*               header were changed. Estimation logic is byte-for-byte original
*               except where a line is marked RESTORED / ADDED.
*-------------------------------------------------------------------------------
version 17
set more off

////////////// Production frontier estimation /////////////
///////// 11/2 version. Code author:  Kyumin Kim //////////
///////////////////////////////////////////////////////////

/// Production fronteir estimation using hyperbolic distance function  //////////////

clear
set more off
* NOTE: original `global inpath ...` removed; paths come from config/paths.do
use "$DERIVED/master_local_fish_max.dta"


keep if div_fished_s!=. & mu_reg !=. & avg_pop !=. & avg_wage_pc !=. //* Getting rid of 178-9 observations as a result from 334) /

// Plot related data for Matt
* RE-ENABLED 2026: writes df_plot.dta, the only input to Matt's
* 26_hdf_mrt.do and his Fig. 1 / 5 / 6 scripts. Export only: drops unused
* columns and adds one variable label; no construction changes.
preserve
    drop div_emp sq_div_emp_diff_s sq_div_emp_diff mu_reg avg_fish_ratio_im_fc div_emp2 div_emp_diff2 div_emp_diff_s2 mu_reg2 sigma_reg
    label variable sigma_reg_exp  "Instability (Geom. Std. Dev.)"
    save "$DERIVED/df_plot.dta", replace
restore



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
gen y1=mu_return_norm
gen n_ln_y1 = -log(y1)


*Noramlizing output variables using variable y1(return) using HOD and taking log
gen s1=sigma_reg_exp_norm
gen s1_star= sigma_reg_exp_norm *mu_return_norm
gen ln_s1_star=log(s1_star)


*Redefining of input variable and taking log 
gen x1=avg_pop_norm
gen x2=avg_wage_pc_norm
// gen x3=1/div_emp_diff_s_norm
// gen x4=1/div_fished_s_norm

gen x3=1/div_emp_diff_norm
gen x4=1/div_fished_norm


gen ln_x1=log(x1)
gen ln_x2=log(x2)
gen ln_x3=log(x3)
gen ln_x4=log(x4)


*Defining interaction and squared term of input and output

*Squared of input
gen ln_x1sq= 1/2 *(ln_x1 *ln_x1)
gen ln_x2sq= 1/2 *(ln_x2 *ln_x2)
gen ln_x3sq= 1/2 *(ln_x3 *ln_x3)
gen ln_x4sq= 1/2 *(ln_x4 *ln_x4)

*Interaciton of input
gen ln_x1x2= ln_x1*ln_x2
gen ln_x1x3= ln_x1*ln_x3
gen ln_x1x4= ln_x1*ln_x4

gen ln_x2x3 = ln_x2*ln_x3
gen ln_x2x4 = ln_x2*ln_x4 
gen ln_x3x4 = ln_x3*ln_x4 


*squared of bad output: s1_star
gen ln_s1sq = 1/2 * (ln_s1_star*ln_s1_star)

*interaction of input with s1_star
gen ln_x1s1= ln_x1 * ln_s1_star
gen ln_x2s1= ln_x2 * ln_s1_star
gen ln_x3s1= ln_x3 * ln_s1_star 
gen ln_x4s1= ln_x4 * ln_s1_star 



*Only keep complete fishing communities. 
drop if missing(n_ln_y1, ln_x1, ln_x2, ln_x3, ln_x4, ln_x1sq, ln_x2sq, ln_x3sq, ln_x4sq, ln_x1x2, ln_x1x3, ln_x1x4, ln_x2x3, ln_x2x4, ln_x3x4, ln_s1_star, ln_s1sq, ln_x1s1, ln_x2s1, ln_x3s1, ln_x4s1)

// // For Bayesian Analysis 
// export delimited using "$DERIVED/processed_dataset.csv", replace


* Create a new variable indicating the quantile group with specilization index 
xtile quantile_group_econ =x3, nq(4)

xtile quantile_group_fish =x4, nq(4) 




/////////////////////// Summary statsticis table ///////////////


sum mu_return sigma_reg_exp div_emp_diff_s div_fished_s avg_pop broader_emp_share broader_permit_share avg_wage_pc avg_fish_ratio_im





///// Estimation for frontier hyperbolic (output) distance function. 




* inifital value searching for frontier estimation (if needed for convergence issue)
reg n_ln_y1 ln_x1 ln_x2 ln_x3 ln_x4  ln_x1sq ln_x2sq ln_x3sq ln_x4sq ln_x1x2 ln_x1x3 ln_x1x4 ln_x2x3 ln_x2x4 ln_x3x4 ln_s1_star ln_s1sq ln_x1s1 ln_x2s1 ln_x3s1 ln_x4s1
matrix b_ols=e(b)



//
// reg n_ln_y1 ln_x1 ln_x2 ln_x1sq ln_x2sq ln_x1x2 ln_s1_star ln_s1sq ln_x1s1 ln_x2s1 
// matrix b_ols=e(b)



*Spec1 (No control) (nr: converges, maxlik)
sfcross n_ln_y1 ln_x1 ln_x2 ln_x3 ln_x4  ln_x1sq ln_x2sq ln_x3sq ln_x4sq ln_x1x2 ln_x1x3 ln_x1x4 ln_x2x3 ln_x2x4 ln_x3x4 ln_s1_star ln_s1sq ln_x1s1 ln_x2s1 ln_x3s1 ln_x4s1, dist(h) technique(nr) svfront(b_ols)
predict u_sigma, u

predict te1, jlms

** Testing MRT
nlcom  -(1 + _b[ln_s1_star]) /(_b[ln_s1_star])

*Testing marginal product of x3 evaluted at mean 
nlcom  -_b[ln_x3] / (1+ _b[ln_s1_star]) // For economic growth y1
nlcom  -_b[ln_x3] / (_b[ln_s1_star]) // For instability 
nlcom (-(1 + _b[ln_s1_star])/(_b[ln_s1_star])) * (- _b[ln_x3] / (1+ _b[ln_s1_star])) // Using chanin rule ds/dx3 = ds/dy * dy /dx3 

*Testing marginal. production of x4
nlcom - _b[ln_x4] / (1+ _b[ln_s1_star])
nlcom - _b[ln_x4] / (_b[ln_s1_star]) //
nlcom (-(1 + _b[ln_s1_star])/(_b[ln_s1_star])) * (- _b[ln_x4] / (1+ _b[ln_s1_star])) // Using chanin rule ds/dx3 = ds/dy * dy /dx3 


predictnl elas_x1_1 = _b[ln_x1] + _b[ln_x1sq]*ln_x1  + _b[ln_x1x4]*ln_x4
predictnl elas_x2_1 =  _b[ln_x2sq]*ln_x2 + _b[ln_x2x3]*ln_x3 + _b[ln_x2s1]*ln_s1_star
predictnl elas_x3_1 = _b[ln_x3] + _b[ln_x2x3]*ln_x2 
predictnl elas_s1_1 = _b[ln_s1_star] + _b[ln_x2s1]*ln_x2 
predictnl elas_y1_1 = ( 1+ elas_s1_1 ) // Using homogeneity condition 

*Impact of x3 on y1 and s1 


predictnl mp_x3_y1_1 = -(elas_x3_1/elas_y1_1) * (y1/x3) // computing mp on growth
predictnl mrt_s_y_1 = - (elas_y1_1/elas_s1_1) * (s1_star/y1) // mrt community wise
predictnl mp_x3_s1_1 = mrt_s_y_1 * mp_x3_y1_1 // commuitng mp on instability 





codebook mp_x3_y1_1 mp_x3_s1_1 





*Anova test by 
anova mp_x3_y1_1 quantile_group_econ, 
pwcompare quantile_group_econ, mcompare(bonferroni)



/////////////////////////////////////////////////////////////////////////////////


*Spec 2: (Local employment / fisheries / variable ) (nr, bhhh, bfgs, maxlik)
sfcross n_ln_y1 ln_x1 ln_x2 ln_x3 ln_x4  ln_x1sq ln_x2sq ln_x3sq ln_x4sq ln_x1x2 ln_x1x3 ln_x1x4 ln_x2x3 ln_x2x4 ln_x3x4 ln_s1_star ln_s1sq ln_x1s1 ln_x2s1 ln_x3s1 ln_x4s1, dist(h) usigma(broader_permit_share_norm) technique(nr)

predict te2, jlms

** Testing MRT
nlcom -(1 + _b[ln_s1_star]) /(_b[ln_s1_star])

*Testing marginal product of x3
nlcom  -_b[ln_x3]/ (1+ _b[ln_s1_star]) // For economic growth y1
nlcom  -_b[ln_x3] / (_b[ln_s1_star]) // For instability 
nlcom (-(1 + _b[ln_s1_star])/(_b[ln_s1_star])) * (- _b[ln_x3] / (1+ _b[ln_s1_star])) // Using chanin rule ds/dx3 = ds/dy * dy /dx3 

*Testing marginal product of x4
nlcom  -_b[ln_x4]/ (1+ _b[ln_s1_star]) // For economic growth y1
//nlcom -(_b[ln_s1_star]) /(1 + _b[ln_s1_star])  * -(_b[ln_x4] / (_b[ln_s1_star]) // For instability 
nlcom  -_b[ln_x4] / (_b[ln_s1_star]) // For instability 
nlcom (-(1 + _b[ln_s1_star])/(_b[ln_s1_star])) * (- _b[ln_x4] / (1+ _b[ln_s1_star])) // Using chanin rule ds/dx3 = ds/dy * dy /dx4


////////////////// excluding non significnat interaction term for computing elasticity 

predictnl elas_x1_2 = _b[ln_x1] + _b[ln_x1sq]*ln_x1  + _b[ln_x1x4]*ln_x4
predictnl elas_x2_2 =  _b[ln_x2sq]*ln_x2 + _b[ln_x2x3]*ln_x3 + _b[ln_x2s1]*ln_s1_star
predictnl elas_x3_2 = _b[ln_x3] + _b[ln_x2x3]*ln_x2 
predictnl elas_s1_2 = _b[ln_s1_star] + _b[ln_x2s1]*ln_x2 
predictnl elas_y1_2 =  ( 1+ elas_s1_1 )  // Using homogeneity condition 

*Impact of x3 on y1 and s1 

predictnl mp_x3_y1_2 = -(elas_x3_2/elas_y1_2) * (y1/x3) // computing mp on growth
predictnl mrt_s_y_2 = - (elas_y1_2/elas_s1_2) * (s1_star/y1) // mrt community wise
predictnl mp_x3_s1_2 = mrt_s_y_2 * mp_x3_y1_2 // commuitng mp on instability 

codebook mp_x3_y1_2 mp_x3_s1_2


///////////////////////////////////////////////////////////////////////////////////


*Spec 3 (All controls using fisheries variable, nr: maxlik) 

sfcross  n_ln_y1 ln_x1 ln_x2 ln_x3 ln_x4  ln_x1sq ln_x2sq ln_x3sq ln_x4sq ln_x1x2 ln_x1x3 ln_x1x4 ln_x2x3 ln_x2x4 ln_x3x4 ln_s1_star ln_s1sq ln_x1s1 ln_x2s1 ln_x3s1 ln_x4s1, dist(h) usigma( broader_permit_share_norm avg_fish_ratio_im_norm) technique(bfgs) svfront(b_ols) iter(500)

//
// sfcross  n_ln_y1 ln_x1 ln_x2 ln_x3 ln_x4  ln_x1sq ln_x2sq ln_x3sq ln_x4sq ln_x1x2 ln_x1x3 ln_x1x4 ln_x2x3 ln_x2x4 ln_x3x4 ln_s1_star ln_s1sq ln_x1s1 ln_x2s1 ln_x3s1 ln_x4s1, dist(h) usigma(broader_emp_share_norm broader_permit_share_norm avg_fish_ratio_im_norm ln_x1 ln_x3 ln_x4) technique(bfgs) svfront(b_ols) iter(500)
//
predict u_sigma_3, u
predict te3, jlms

** Testing MRT
nlcom -(1 +  _b[ln_s1_star]) /(_b[ln_s1_star] )

* To see hessian matrix 
matrix cov_matrix = e(V)
matrix list cov_matrix


*Testing marginal product of economic diversification

nlcom  - _b[ln_x3] / (1+ _b[ln_s1_star]) // For economic growth y1
nlcom  - _b[ln_x3] / (_b[ln_s1_star]) // For instability 
nlcom (-(1 + _b[ln_s1_star])/(_b[ln_s1_star])) * (- _b[ln_x3] / (1+ _b[ln_s1_star])) // Using chanin rule ds/dx3 = ds/dy * dy /dx3 



*Testing marginal product of fisheries diversification 
nlcom -_b[ln_x4] / (1+ _b[ln_s1_star]) // For economic growth y1 
nlcom -_b[ln_x4] / (_b[ln_s1_star]) // For instabiltiy 
nlcom (-(1 + _b[ln_s1_star])/(_b[ln_s1_star])) * (- _b[ln_x4] / (1+ _b[ln_s1_star])) // Using chanin rule ds/dx3 = ds/dy * dy /dx4 



////////////////// excluding non significnat interaction term for computing elasticity without noise 

*Elasiticity (Up to close level of 10%, 15%)

*x1 
predictnl elas_x1_3 = _b[ln_x1] + _b[ln_x1sq]*ln_x1 + _b[ln_x1x2]*ln_x2 + _b[ln_x1x4]*ln_x4

*x2 
predictnl elas_x2_3 =  _b[ln_x2sq]*ln_x2 + _b[ln_x1x2]*ln_x1 +   _b[ln_x2s1]*ln_s1_star

*x3 
predictnl elas_x3_3 = _b[ln_x3] + _b[ln_x3x4]*ln_x4 

*x4
predictnl elas_x4_3 = _b[ln_x4] + _b[ln_x4sq]*ln_x4  + _b[ln_x1x4]*ln_x1 + _b[ln_x3x4]*ln_x3 

*s1 
predictnl elas_s1_3 = _b[ln_s1_star] + _b[ln_x2s1]*ln_x2 

*y1
predictnl elas_y1_3 =  ( 1+ elas_s1_1 ) // Using homogeneity condition 




*Impact of x3 on y1 and s1 


predictnl mp_x3_y1_3 = -(elas_x3_3/elas_y1_3) * (y1/x3) // computing mp on growth
predictnl mrt_s_y_3 = - (elas_y1_3/elas_s1_3) * (s1/y1) // mrt community wise
predictnl mp_x3_s1_3 = mrt_s_y_3 * mp_x3_y1_3 // commuitng mp on instability 


*Impact of x4 on y1 and s1 


predictnl mp_x4_y1_3 = -(elas_x4_3/elas_y1_3) * (y1/x4) // computing mp on growth
predictnl mp_x4_s1_3 = mrt_s_y_3 * mp_x4_y1_3 // commuitng mp on instability 

codebook mp_x3_y1_3 mp_x3_s1_3 mp_x4_y1_3 mp_x4_s1_3 


// Keep only the specified variables
keep mu_return sigma_reg_exp div_emp div_emp_diff_s div_emp_diff avg_pop broader_emp_share broader_permit_share div_fished_s div_fished avg_fish_ratio_im avg_fish_ratio avg_fish_ratio_im_fc avg_wage_pc avg_fishermen city mp_x3_y1_3 mp_x3_s1_3 mp_x4_y1_3 mp_x4_s1_3

// Save the dataset in Stata format
save "$DERIVED/marginal_effect_HDF.dta", replace






//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
///// the enhanced hyperbolic distnace fuctnion: Production fronteir estimation using hyperbolic distance function  //////////////
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
// gen x3=1/div_emp_diff_s_norm
// gen x4=1/div_fished_s_norm

gen x3=1/div_emp_diff_norm
gen x4=1/div_fished_norm

gen s1=sigma_reg_exp_norm


*Noramlizing output variables using variable y1(return) using HOD and taking log
gen s1_star= sigma_reg_exp_norm *mu_return_norm
gen ln_s1_star=log(s1_star)


*Redefining of input variable and taking log 
gen x1_star=avg_pop_norm * mu_return_norm
gen x2_star=avg_wage_pc_norm * mu_return_norm
gen x3_star=div_emp_diff_s_norm * mu_return_norm
gen x4_star=div_fished_s_norm * mu_return_norm


gen ln_x1_star=log(x1_star)
gen ln_x2_star=log(x2_star)
gen ln_x3_star=log(1/x3_star) // making it as specialization index. 
gen ln_x4_star=log(1/x4_star) 


*Defining interaction and squared term of input and output

*Squared of input
gen ln_x1sq= 1/2 *(ln_x1_star *ln_x1_star)
gen ln_x2sq= 1/2 *(ln_x2_star *ln_x2_star)
gen ln_x3sq= 1/2 *(ln_x3_star *ln_x3_star)
gen ln_x4sq= 1/2 *(ln_x4_star *ln_x4_star) 

*Interaciton of input
gen ln_x1x2= ln_x1_star*ln_x2_star
gen ln_x1x3= ln_x1_star*ln_x3_star
gen ln_x1x4 = ln_x1_star*ln_x4_star

gen ln_x2x3 = ln_x2_star*ln_x3_star
gen ln_x2x4 = ln_x2_star*ln_x4_star

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


///////
 
*Spec 1:  No control in inefficiency term (nr: convergence, maxlik)
sfcross n_ln_y1 ln_x1_star ln_x2_star ln_x3_star ln_x4_star ln_x1sq ln_x2sq ln_x3sq ln_x4sq ln_x1x2 ln_x1x3 ln_x1x4 ln_x2x3 ln_x2x4 ln_x3x4 ln_s1_star ln_s1sq ln_x1s1 ln_x2s1 ln_x3s1 ln_x4s1, dist(h) technique(nr) iter(300)

predict te_1_e,jlms 

********** All testing are evaluated at means

** Testing MRT 
nlcom  -(1 + _b[ln_s1_star] + _b[ln_x1_star]+ _b[ln_x2_star] + _b[ln_x3_star] + _b[ln_x4_star]) /(_b[ln_s1_star])



*Testing marginal product of economic diversification  
nlcom  - _b[ln_x3_star] / (1+ _b[ln_s1_star] + _b[ln_x1_star]+ _b[ln_x2_star] + _b[ln_x3_star] + _b[ln_x4_star]) // For economic growth y1 -- using homogeneity condition. 
nlcom  - _b[ln_x3_star] / (_b[ln_s1_star]) // For instability 
nlcom (- (1+ 1+ _b[ln_s1_star] + _b[ln_x1_star]+ _b[ln_x2_star] + _b[ln_x3_star] + _b[ln_x4_star])/(_b[ln_s1_star])) * (- _b[ln_x3_star] /  (1+ 1+ _b[ln_s1_star] + _b[ln_x1_star]+ _b[ln_x2_star] + _b[ln_x3_star] + _b[ln_x4_star])) // Using chanin rule ds/dx3 = ds/dy * dy /dx3 

*Testing marginal product of fisheries diversification 
nlcom - _b[ln_x4_star] / (1+ _b[ln_s1_star] + _b[ln_x1_star]+ _b[ln_x2_star] + _b[ln_x3_star] + _b[ln_x4_star])
nlcom - _b[ln_x4_star] / (_b[ln_s1_star])

////////////////// excluding non significnat interaction term for computing elasticity 




predictnl elas_x1_1_e = _b[ln_x1_star] + _b[ln_x1sq]*ln_x1_star  + _b[ln_x1x4]*ln_x4_star
predictnl elas_x2_1_e =  _b[ln_x2sq]*ln_x2_star + _b[ln_x2x3]*ln_x3_star + _b[ln_x2s1]*ln_s1_star
predictnl elas_x3_1_e = _b[ln_x3_star] + _b[ln_x2x3]*ln_x2_star 
predictnl elas_s1_1_e = _b[ln_s1_star] + _b[ln_x2s1]*ln_x2_star 
predictnl elas_y1_1_e = (  1+ elas_s1_1_e + elas_x1_1_e + elas_x2_1_e + elas_x3_1_e ) // Using homogeneity condition 


*Impact of x3 on y1 and s1 


predictnl mp_x3_y1_1_e = -(elas_x1_1_e/elas_y1_1_e) * (y1/x3_star) // computing mp on growth
predictnl mrt_s_y_1_e = -(elas_y1_1_e/elas_s1_1_e) * (s1_star/y1) // mrt community wise
predictnl mp_x3_s1_1_e = mrt_s_y_1_e * mp_x3_y1_1_e // commuitng mp on instability 

codebook mp_x3_y1_1_e mp_x3_s1_1_e


///////////////////////////////////////////////////////////////////////////////////



*Spec 2: Local economy only variables (bfgs: maxlik)
sfcross n_ln_y1 ln_x1_star ln_x2_star ln_x3_star ln_x4_star ln_x1sq ln_x2sq ln_x3sq ln_x4sq ln_x1x2 ln_x1x3 ln_x1x4 ln_x2x3 ln_x2x4 ln_x3x4 ln_s1_star ln_s1sq ln_x1s1 ln_x2s1 ln_x3s1 ln_x4s1, dist(h) usigma(broader_permit_share_norm)  technique(bfgs) 
**** Testing MRT evaluated
nlcom - (1+ _b[ln_s1_star] + _b[ln_x1_star]+ _b[ln_x2_star] + _b[ln_x3_star] + _b[ln_x4_star])  /_b[ln_s1_star]

***
predict te_2_e,jlms 


** Testing MRT

nlcom -(1+ _b[ln_s1_star] + _b[ln_x1_star]+ _b[ln_x2_star]+ _b[ln_x3_star] + _b[ln_x4_star]) /(_b[ln_s1_star])

*Testing marginal product of economic specialization  
nlcom  - _b[ln_x3_star] / (1 + _b[ln_s1_star] + _b[ln_x1_star] +_b[ln_x2_star] + _b[ln_x3_star] + _b[ln_x4_star]) // For economic growth y1 -- using homogeneity condition ( 1+ bad elas + \sum input elasticity)
nlcom  - _b[ln_x3_star] / (_b[ln_s1_star])  // For instability 
nlcom (- (1+ _b[ln_s1_star] + _b[ln_x1_star]+ _b[ln_x3_star] + _b[ln_x4_star])/(_b[ln_s1_star])) * (- _b[ln_x3_star] /  (1+ _b[ln_s1_star] + _b[ln_x1_star]+ _b[ln_x3_star] + _b[ln_x4_star])) // Using chanin rule ds/dx3 = ds/dy * dy /dx3 

*Testing marginal product of fisheries diversification 
nlcom - _b[ln_x4_star] / (1+ _b[ln_s1_star] + _b[ln_x1_star] +_b[ln_x2_star] + _b[ln_x3_star] + _b[ln_x4_star])
nlcom - _b[ln_x4_star] / ( _b[ln_s1_star])
nlcom (- (1+ _b[ln_s1_star] + _b[ln_x1_star]+ _b[ln_x2_star] + _b[ln_x3_star] + _b[ln_x4_star])/(_b[ln_s1_star])) * (- _b[ln_x4_star] /  (1+ _b[ln_s1_star] + _b[ln_x1_star]+_b[ln_x2_star]+ _b[ln_x3_star] + _b[ln_x4_star])) // Using chanin rule ds/dx3 = ds/dy * dy /dx4 


////////////////// computing elasticity for communitiy wise


predictnl elas_x1_2_e = _b[ln_x1_star] +  _b[ln_x1sq]*ln_x1_star + _b[ln_x1x2]*ln_x2_star + _b[ln_x1x3]*ln_x3_star + _b[ln_x1x4]*ln_x4_star +_b[ln_x1s1]*ln_s1_star
predictnl elas_x2_2_e = _b[ln_x2_star] + _b[ln_x2sq]*ln_x2_star + _b[ln_x1x2]*ln_x1_star + _b[ln_x2x3]*ln_x3_star + _b[ln_x2x4]*ln_x4_star + _b[ln_x2s1]*ln_s1_star

predictnl elas_x3_2_e = ///
    _b[ln_x3_star] + ///
    _b[ln_x3sq]*ln_x3_star + ///
    _b[ln_x1x3]*ln_x1_star + ///
    _b[ln_x2x3]*ln_x2_star + ///
    _b[ln_x3x4]*ln_x4_star + ///
    _b[ln_x3s1]*ln_s1_star


// Elasticity with respect to x4_star
predictnl elas_x4_2_e = ///
    _b[ln_x4_star] + ///
    _b[ln_x4sq]*ln_x4_star + ///
    _b[ln_x1x4]*ln_x1_star + ///
    _b[ln_x2x4]*ln_x2_star + ///
    _b[ln_x3x4]*ln_x3_star + ///
    _b[ln_x4s1]*ln_s1_star
	

predictnl elas_s1_2_e = _b[ln_s1_star] + _b[ln_x2s1]*ln_x2_star 

predictnl elas_y1_2_e = (  1+ elas_s1_2_e + elas_x1_2_e + elas_x2_2_e + elas_x3_2_e ) // Using homogeneity condition 


*Impact of x3 on y1 and s1 


predictnl mp_x3_y1_2_e = -(elas_x1_2_e/elas_y1_2_e) * (y1/x3_star) // computing mp on growth
predictnl mrt_s_y_2_e = -(elas_y1_2_e/elas_s1_2_e) * (s1_star/y1) // mrt community wise
predictnl mp_x3_s1_2_e = mrt_s_y_2_e * mp_x3_y1_2_e // commuitng mp on instability 

codebook mp_x3_y1_2_e mp_x3_s1_2_e

///////////////////////////////////////////////////////////////////////////////////


*Spec 3 (nr, dfp : maxlik. :dfp is more stable)
sfcross n_ln_y1 ln_x1_star ln_x2_star ln_x3_star ln_x4_star ln_x1sq ln_x2sq ln_x3sq ln_x4sq ln_x1x2 ln_x1x3 ln_x1x4 ln_x2x3 ln_x2x4 ln_x3x4 ln_s1_star ln_s1sq ln_x1s1 ln_x2s1 ln_x3s1 ln_x4s1, dist(h) usigma(broader_permit_share_norm avg_fish_ratio_im_norm) technique(nr) posthessian

* To see hessian matrix 
matrix cov_matrix = e(V)
matrix list cov_matrix

*Efficiency extraction 
predict te_3_e,jlms



*MRT testing
nlcom -(1+ _b[ln_s1_star] + _b[ln_x1_star]+ _b[ln_x2_star] + _b[ln_x3_star] + _b[ln_x4_star]) /(_b[ln_s1_star])

*Testing marginal product 
nlcom  -_b[ln_x3_star] / (1+ _b[ln_s1_star] + _b[ln_x1_star]+ _b[ln_x2_star] + _b[ln_x3_star] + _b[ln_x4_star]) // For economic growth y1
nlcom  - _b[ln_x3_star] / (_b[ln_s1_star]) // For instability 
nlcom (- (1+ _b[ln_s1_star] + _b[ln_x1_star]+ _b[ln_x3_star] + _b[ln_x4_star])/(_b[ln_s1_star])) * (- _b[ln_x3_star] /  (1+ _b[ln_s1_star] + _b[ln_x1_star]+ _b[ln_x3_star] + _b[ln_x4_star])) // Using chanin rule ds/dx3 = ds/dy * dy /dx3  evaluted at means. 


*Testing marginal product 
nlcom  -_b[ln_x4_star] / (1+ _b[ln_s1_star] + _b[ln_x1_star]+ _b[ln_x2_star] + _b[ln_x3_star] + _b[ln_x4_star]) // For economic growth y1
nlcom  - _b[ln_x4_star] / (_b[ln_s1_star]) // For instability 
nlcom (- (1+ _b[ln_s1_star] + _b[ln_x1_star]+ _b[ln_x2_star] + _b[ln_x3_star]  + _b[ln_x4_star])/(_b[ln_s1_star])) * (- _b[ln_x4_star] /  (1+ _b[ln_s1_star] + _b[ln_x1_star]+ _b[ln_x2_star] + _b[ln_x3_star] + _b[ln_x4_star])) // Using chanin rule ds/dx3 = ds/dy * dy /dx4 



///// Efficiency estimates



//////// Including all variables, I estimate the elasticity for each input and s1 and y1.  
*x1 
predictnl elas_x1_3_e_a= _b[ln_x1_star] +  _b[ln_x1sq]*ln_x1_star + _b[ln_x1x2]*ln_x2_star + _b[ln_x1x3]*ln_x3_star + _b[ln_x1x4]*ln_x4_star +_b[ln_x1s1]*ln_s1_star

*x2 
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
predictnl mp_x3_s1_3_e = mrt_s_y_3_e * mp_x3_y1_3_e // commuitng mp on instability 


*Impact of x4 on y1 and s1 


predictnl mp_x4_y1_3_e = -(elas_x4_3_e/elas_y1_3_e) * (y1/x4) // computing mp on growth
predictnl mp_x4_s1_3_e = mrt_s_y_3_e * mp_x4_y1_3_e // commuitng mp on instability 

codebook mp_x3_y1_3_e mp_x3_s1_3_e mp_x4_y1_3_e mp_x4_s1_3_e 



/// preparation of shadow value price computation 

*Price (value) of employment growth comuptation 
sum avg_emp // Average employment over community during th year
*The value of 1% (unit) return Growth employment 
gen unit_emp_growth= 0.01 *avg_emp // 1% economic growth equivalent number of employment// 

* Community additional income by 1% growth 
 
gen wage_income = avg_wage_pc * avg_pop
gen wage_income_per_emp = wage_income/avg_emp

gen p_y_wage = unit_emp_growth * wage_income_per_emp // 1% economic growth in employment equivlanet to generated wage income to economy 

* Compute shadow value of specilaization  p_y = MP(=elas/elas) *p_x  
gen shadow_x3 = mp_x3_y1_3_e *p_y_wage
gen shadow_x4 = mp_x4_y1_3_e * p_y_wage 

// Keep only the specified variables
keep mp_x3_y1_3_e mp_x3_s1_3_e mp_x4_y1_3_e mp_x4_s1_3_e city latitude longitude

// Save the dataset
save "$DERIVED/marginal_effect_EHDF.dta", replace


//	
