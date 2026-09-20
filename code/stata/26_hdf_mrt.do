*-------------------------------------------------------------------------------
* Filename:     26_hdf_mrt.do
* Purpose:      Marginal rates of transformation: at means, their elasticities with
*               respect to each diversification margin, the cross-partial, the 3x3
*               quantile grid, and the full 5th-95th percentile grid.
*               Source of the in-text estimates and of Figures 1, 5 and 6.
* Inputs:       $DERIVED/df_plot.dta   (written by 25_marginal_effects.do)
* Outputs:      $ESTIMATES/frontier.ster, distance_elasticities.ster,
*               MRT_elasticity_diversification.dta, MRT_elasticity_diff_test.dta,
*               MRT_crosspartial.dta, MRT_emp_fish.dta, MRT_emp_fish_5-95.dta,
*               summary_stats.txt, frontier_V.txt
* Requires:     Stata 17+, sfcross, parmest, mat2txt
* Author:       Matthew N. Reimer, 09/02/2025. Supplied 2026-09-18.
*               Ported for the replication package: ONLY the paths and this header
*               were changed. Estimation logic is byte-for-byte Matt's.
*
* WHY this file matters: it is the only source of the numbers reported in the text
*   - dMRT_dlnDiv_industrial / _fisheries  -> the 0.77 and 0.31 elasticities
*   - diff_industrial_v_fisheries          -> the equality test, p = 0.173
*   - NMRT_crosspartial                    -> 0.237 (SE 0.160)
*   - Differences_Q3Q3_Q3Q1                -> the 25th-vs-75th difference-in-differences
* and of the MRT grids that Figures 5 and 6 plot.
*
* NOTE on file names: mat2txt appends ".txt" only when the saving() string
* contains no period, and it inspects the whole path -- so a package unpacked
* under a directory such as ~/.local would otherwise get extensionless files.
* The extension is therefore written out explicitly.
*
* NOTE on evaluation points: the quantile blocks below draw percentiles from the
* NORMALIZED diversification measures, div_emp_diff_s_norm and div_fished_s_norm.
* That is the scale the regressors x3 and x4 are built in, so the evaluation
* points and the coefficients are expressed in the same units.
*-------------------------------------------------------------------------------
version 17
set more off

* Filename:              HDF_Estimation.do
* Last Modified:         09/02/2025
* Program Description:   Program that estimates a hyperbolic distance functions
* Authors: 				 Kim, Reimer
*
* NOTES:                 
*-------------------------------------------------------------------------------
clear all
set more off
* NOTE: original `global inpath ...` removed; paths come from config/paths.do

*------*
* Data *
*------*
use "$DERIVED/df_plot.dta", clear

*--------*
* Macros *
*--------*
local variables "mu_return sigma_reg_exp div_emp_diff_s avg_pop broader_emp_share broader_permit_share div_fished_s avg_fish_ratio_im avg_wage_pc"
local normvars

*-------------------*
* Data Manipulation *
*-------------------*
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
mat2txt, matrix(M) saving("$ESTIMATES/summary_stats.txt") replace		// Export variance matrix


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


*---------------------*
* Frontier Estimation *
*---------------------*
gen half = 0.5
local frontier "c.x1 c.x2 c.x3 c.x4 c.half#c.x1#c.x1 c.half#c.x2#c.x2 c.half#c.x3#c.x3 c.half#c.x4#c.x4 c.x1#c.x2 c.x1#c.x3 c.x1#c.x4 c.x2#c.x3 c.x2#c.x4 c.x3#c.x4 c.s1 c.half#c.s1#c.s1 c.x1#c.s1 c.x2#c.s1 c.x3#c.s1 c.x4#c.s1"

* Model: Efficiency heterogeneity,  no regional fixed effects
sfcross n_ln_y1 `frontier', dist(h) iter(300) cost usigma(broader_permit_share_norm avg_fish_ratio_im_norm)
estimates save "$ESTIMATES/frontier", replace
estimates store frontier
parmest , saving("$ESTIMATES/frontier", replace)
matrix V = e(V)
mat2txt, matrix(V) saving("$ESTIMATES/frontier_V.txt") replace		// Export variance matrix
margins, dydx(s1 x1 x2 x3 x4) post
estimates save "$ESTIMATES/distance_elasticities", replace
estimates store distance_elasticities

*----------------*
* MRTs (AT MEAN) *
*----------------*
* Evaluate elasticities at means 
estimates restore frontier

* MRTs (Equation 5, at means)
nlcom (NMRT: -(_b[s1] / (1 + _b[s1] + _b[x1] + _b[x2] + _b[x3] + _b[x4]))) 

*----------------------*
* CONTRIBUTION TO MRTs *
*----------------------*
estimates restore frontier

* Equation 6, at means *
local sumalpha "(_b[x1]+_b[x2]+_b[x3]+_b[x4])"
local sumcross3 "(_b[c.half#c.x3#c.x3]+_b[c.x1#c.x3]+_b[c.x2#c.x3]+_b[c.x3#c.x4])"
local sumcross4 "(_b[c.half#c.x4#c.x4]+_b[c.x1#c.x4]+_b[c.x2#c.x4]+_b[c.x3#c.x4])"
nlcom (dMRT_dlnDiv_industrial: -1*( -(1/(1+_b[s1]+`sumalpha')^2) * ((1+`sumalpha')*_b[x3#s1] - _b[s1]*`sumcross3') )) ///
      (dMRT_dlnDiv_fisheries:  -1*( -(1/(1+_b[s1]+`sumalpha')^2) * ((1+`sumalpha')*_b[x4#s1] - _b[s1]*`sumcross4') )), post
parmest, saving("$ESTIMATES/MRT_elasticity_diversification", replace)

* Test for differences between fisheries and sectoral diversification*
nlcom (diff_industrial_v_fisheries: _b[dMRT_dlnDiv_industrial] - _b[dMRT_dlnDiv_fisheries]), post
parmest, saving("$ESTIMATES/MRT_elasticity_diff_test", replace)

*-------------------*
* CROSS-PARTIAL MRT *
*-------------------*
* Second cross-partial of MRT w.r.t. ln(x3), ln(x4), evaluated at the means.
* Tests whether the two diversification margins interact,
* as distinct from the DiD test above, which spans the 25th-75th percentile range.
estimates restore frontier

local D0 "(1+_b[s1]+_b[x1]+_b[x2]+_b[x3]+_b[x4])"
local R3 "(_b[x3#s1]+(_b[half#x3#x3]+_b[x1#x3]+_b[x2#x3]+_b[x3#x4]))"
local R4 "(_b[x4#s1]+(_b[half#x4#x4]+_b[x1#x4]+_b[x2#x4]+_b[x3#x4]))"

nlcom (NMRT_crosspartial: (`D0'*(_b[x3#s1]*`R4' + _b[x4#s1]*`R3') - 2*_b[s1]*`R3'*`R4') / (`D0'^3)), post

parmest, saving("$ESTIMATES/MRT_crosspartial", replace)

*------------------*
* MRTs (QUANTILES) *
*------------------*
* Get quantiles of normalized diversification

	* Sectoral Diversification
	quietly summarize div_emp_diff_s_norm, detail
	scalar x3_q1 = r(p25)
	scalar x3_q2 = r(p50)
	scalar x3_q3 = r(p75)
	
	* Fisheries Diversification
	quietly summarize div_fished_s_norm, detail
	scalar x4_q1 = r(p25)
	scalar x4_q2 = r(p50)
	scalar x4_q3 = r(p75)

* Take logs and convert to specialization
	* Sectoral Diversification
	scalar ln_x3_q1 = ln(1/x3_q1)
	scalar ln_x3_q2 = ln(1/x3_q2)
	scalar ln_x3_q3 = ln(1/x3_q3)
	
	* Fisheries Diversification
	scalar ln_x4_q1 = ln(1/x4_q1)
	scalar ln_x4_q2 = ln(1/x4_q2)
	scalar ln_x4_q3 = ln(1/x4_q3)

* Evaluate elasticities at quantiles
estimates restore frontier
margins, dydx(s1 x1 x2 x3 x4) at(x3=( `=ln_x3_q1' `=ln_x3_q2' `=ln_x3_q3' ) ///
								 x4=( `=ln_x4_q1' `=ln_x4_q2' `=ln_x4_q3' )) ///
								 atmeans post

* MRTs (at means) and "differences-across-percentiles"
matrix list e(b)	  
nlcom (NMRT_X3Q1_X4Q1: -(_b[s1:1._at] / (1 + _b[s1:1._at] + _b[x1:1._at] + _b[x2:1._at] + _b[x3:1._at] + _b[x4:1._at]))) ///
      (NMRT_X3Q1_X4Q2: -(_b[s1:2._at] / (1 + _b[s1:2._at] + _b[x1:2._at] + _b[x2:2._at] + _b[x3:2._at] + _b[x4:2._at]))) ///
      (NMRT_X3Q1_X4Q3: -(_b[s1:3._at] / (1 + _b[s1:3._at] + _b[x1:3._at] + _b[x2:3._at] + _b[x3:3._at] + _b[x4:3._at]))) ///
      (NMRT_X3Q2_X4Q1: -(_b[s1:4._at] / (1 + _b[s1:4._at] + _b[x1:4._at] + _b[x2:4._at] + _b[x3:4._at] + _b[x4:4._at]))) ///
      (NMRT_X3Q2_X4Q2: -(_b[s1:5._at] / (1 + _b[s1:5._at] + _b[x1:5._at] + _b[x2:5._at] + _b[x3:5._at] + _b[x4:5._at]))) ///
      (NMRT_X3Q2_X4Q3: -(_b[s1:6._at] / (1 + _b[s1:6._at] + _b[x1:6._at] + _b[x2:6._at] + _b[x3:6._at] + _b[x4:6._at]))) ///
      (NMRT_X3Q3_X4Q1: -(_b[s1:7._at] / (1 + _b[s1:7._at] + _b[x1:7._at] + _b[x2:7._at] + _b[x3:7._at] + _b[x4:7._at]))) ///
      (NMRT_X3Q3_X4Q2: -(_b[s1:8._at] / (1 + _b[s1:8._at] + _b[x1:8._at] + _b[x2:8._at] + _b[x3:8._at] + _b[x4:8._at]))) ///
      (NMRT_X3Q3_X4Q3: -(_b[s1:9._at] / (1 + _b[s1:9._at] + _b[x1:9._at] + _b[x2:9._at] + _b[x3:9._at] + _b[x4:9._at]))) ///
      (Differences_Q3Q3_Q3Q1: ///
         ( -(_b[s1:9._at]/(1+_b[s1:9._at]+_b[x1:9._at]+_b[x2:9._at]+_b[x3:9._at]+_b[x4:9._at])) ///
         - -(_b[s1:7._at]/(1+_b[s1:7._at]+_b[x1:7._at]+_b[x2:7._at]+_b[x3:7._at]+_b[x4:7._at])) ) ///
       - ( -(_b[s1:3._at]/(1+_b[s1:3._at]+_b[x1:3._at]+_b[x2:3._at]+_b[x3:3._at]+_b[x4:3._at])) ///
         - -(_b[s1:1._at]/(1+_b[s1:1._at]+_b[x1:1._at]+_b[x2:1._at]+_b[x3:1._at]+_b[x4:1._at])) ) ///
      ), ///
      post
	  
parmest , saving("$ESTIMATES/MRT_emp_fish", replace)

*----------------------------*
* MRT GRID: 5-95 PERCENTILES *
*----------------------------*

tempfile temp1 temp2    // Temporary Files

* Empty dataset for initializing results
preserve
	clear
	set obs 0
	gen x = -99
	save `temp1'
restore

* Loop through multiple quantiles
forvalues q = 5(5)95 {
	forvalues p = 5(5)95 {
	
		* Get quantile of normalized diversification
		quietly centile div_emp_diff_s_norm, centile(`q')
		scalar q = r(c_1)
		quietly centile div_fished_s_norm, centile(`p')
		scalar p = r(c_1)
		
		* Take logs and convert to specialization
		scalar ln_q = ln(1/q)
		scalar ln_p = ln(1/p)
		
		* Evaluate elasticities at quantile
		estimates restore frontier
		margins, dydx(s1 x1 x2 x3 x4) at(x3=( `=ln_q' ) x4=( `=ln_p' )) atmeans post
		
		* MRTs (at means and quantile)
		nlcom (NMRT_`q'_`p': -(_b[s1] / (1 + _b[s1] + _b[x1] + _b[x2] + _b[x3] + _b[x4]))), post
		parmest , saving(`temp2', replace)
		
		* Save and append
		preserve
			use `temp2', clear
			append using `temp1'
			save `temp1', replace
		restore
	}
}
* Load appended data set and save
preserve
	use `temp1', clear
	save "$ESTIMATES/MRT_emp_fish_5-95", replace
restore
