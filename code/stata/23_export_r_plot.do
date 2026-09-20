*-------------------------------------------------------------------------------
* Filename:     23_export_r_plot.do
* Purpose:      Build R_plot.dta, the normalised frame that the frontier-quantile
*               figures (Fig. 4 and Fig. S.2) read.
* Inputs:       $DERIVED/master_local_fish_max.dta
* Outputs:      $DERIVED/R_plot.dta, $ESTIMATES/frontier.ster
* Requires:     Stata 17+, config/paths.do already included by 00_master.do
* Author:       Reimer (Matt)
*               Ported for the replication package 2026; ONLY paths and this
*               header were changed. Estimation logic is byte-for-byte original
*               except where a line is marked RESTORED / ADDED.
*-------------------------------------------------------------------------------
version 17
set more off

* ------------------------------------------------------------------------------
* Filename:              HDF_Estimation.do
* Last Modified:         09/02/2025
* Program Description:   Program that estimates a hyperbolic distance functions
* Authors:               Kim, Reimer
*
* NOTES:                 
*-------------------------------------------------------------------------------
clear all
set more off
* NOTE: original `global inpath ...` removed; paths come from config/paths.do

*------*
* Data *
*------*
use "$DERIVED/master_local_fish_max.dta"
*--------*
* Macros *
*--------*
local variables "mu_return sigma_reg_exp div_emp_diff_s avg_pop broader_emp_share broader_permit_share div_fished_s avg_fish_ratio_im avg_wage_pc"
local normvars
*-------------------*
* Data Manipulation *
*-------------------*

keep if div_fished_s!=. & mu_reg !=. //* Getting rid of 178-9 observations as a result from 334) /

* Calculate the geometric mean and normalize variables
foreach var in `variables' {
    * Calculate the logarithm of the variable
    gen log_`var' = log(`var')
    
    * Calculate the mean of the logarithms
    quietly summarize log_`var'
    scalar gmean_log = r(mean)
    
    * Exponentiate the mean of the logarithms to get the geometric mean
    scalar gmean_`var' = exp(gmean_log)
    
    * Normalize the variable using the geometric mean
    gen `var'_norm = `var' / gmean_`var'
    
    * Drop the intermediate log variable
    drop log_`var'
    
    * Add to local normvars
    local normvars `normvars' `var'_norm
}


* Export min, max, p25, p50, and p75 of normalized
tabstat `normvars', stat(min max p25 p50 p75) columns(var) save
matrix M = r(StatTotal)
mat2txt, matrix(M) saving("$ESTIMATES/summary_stats.txt") replace        // Export variance matrix
* Log and normalize variables for translog approximation
*s1: sigma_reg_exp_norm  / y1= mu_return_norm  / x1: population, x2: wage income per capita, x3: economic diversification, x4: fisheries diversification 
* Normalizing variabler as depedent variable with negative sign 'n' on LHS
gen n_ln_y1 = -log(mu_return_norm)
* Normalize and log
gen s1 = log(sigma_reg_exp_norm * mu_return_norm)
gen x1 = log(avg_pop_norm * mu_return_norm)
gen x2 = log(avg_wage_pc_norm * mu_return_norm)
gen x3 = log((1/div_emp_diff_s_norm) * mu_return_norm) // Using specialization measure by inverse
gen x4 = log((1/div_fished_s_norm) * mu_return_norm)   // Using specialization measure by inverse



save "$DERIVED/R_plot.dta", replace 

* ----------------------------------------------------------------------------
* TRIMMED 2026-09-18 for the replication package.
* R_plot.dta is the only output of this file that anything reads (Fig. 4, Fig. S.2).
* The remainder of the original file re-estimated the frontier and wrote
* artefacts that no script reads and that a later step overwrites; keeping
* them in the package would only invite confusion about which estimate is
* which. Nothing above this line was altered.
* ----------------------------------------------------------------------------
