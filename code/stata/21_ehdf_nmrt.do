*-------------------------------------------------------------------------------
* Filename:     21_ehdf_nmrt.do
* Purpose:      EHDF spec 3 plus MRT at means and at diversification quantiles (Tables S2, S5).
* Inputs:       $DERIVED/master_local_fish_max.dta
* Outputs:      $ESTIMATES/frontier_spec3.ster, NMRT_quantile_tests.dta,
*               NMRT_quantile_tests_x3.dta, NMRT_contrasts_x3.dta, NMRT_contrasts_x4.dta
* Requires:     Stata 17+, config/paths.do already included by 00_master.do
* Author:       Reimer (Matt)
*               Ported for the replication package 2026; ONLY paths and this
*               header were changed. Estimation logic is byte-for-byte original
*               except where a line is marked RESTORED / ADDED.
*-------------------------------------------------------------------------------
version 17
set more off

*----------------------------------------------
* Filename:              HDF_Estimation_MATCH_v2spec3_with_NMRT.do
* Last Modified:         10/09/2025
* Program Description:   EHDF (v2 Spec 3 aligned) + NMRT post-estimation tests
* Authors:               Kim, Reimer
*----------------------------------------------
clear all
set more off
* NOTE: original `global inpath ...` removed; paths come from config/paths.do

use "$DERIVED/master_local_fish_max.dta", clear

*=== Ensure SAME SAMPLE as v2 ===*
keep if div_fished_s!=. & mu_reg!=.

*=== Geometric-mean normalization (as in v2) ===*
foreach var in mu_return sigma_reg_exp div_emp div_emp_diff_s div_emp_diff ///
                 avg_pop broader_emp_share broader_permit_share ///
                 div_fished_s div_fished ///
                 avg_fish_ratio_im avg_fish_ratio avg_fish_ratio_im_fc ///
                 avg_wage_pc avg_fishermen {
    gen log_`var' = log(`var')
    quietly summarize log_`var'
    scalar gmean = exp(r(mean))
    gen `var'_norm = `var'/gmean
    drop log_`var'
}

*=== EHDF transforms ===*
gen n_ln_y1 = -log(mu_return_norm)
gen y1      =  mu_return_norm

* inputs pre-star (not used in regression but kept for clarity)
gen x1 = avg_pop_norm
gen x2 = avg_wage_pc_norm
gen x3 = 1/div_emp_diff_s_norm   // specialization (inverse diversification)
gen x4 = 1/div_fished_s_norm     // specialization (inverse diversification)

* bad output and "star" transforms
gen s1      = sigma_reg_exp_norm
gen s1_star = sigma_reg_exp_norm * mu_return_norm
gen x1_star = avg_pop_norm       * mu_return_norm
gen x2_star = avg_wage_pc_norm   * mu_return_norm
gen x3_star = (1/div_emp_diff_s_norm) * mu_return_norm
gen x4_star = (1/div_fished_s_norm)   * mu_return_norm

gen ln_s1_star = log(s1_star)
gen ln_x1_star = log(x1_star)
gen ln_x2_star = log(x2_star)
gen ln_x3_star = log(x3_star)
gen ln_x4_star = log(x4_star)

* squares (1/2 factor) and interactions
gen ln_x1sq = 0.5*(ln_x1_star^2)
gen ln_x2sq = 0.5*(ln_x2_star^2)
gen ln_x3sq = 0.5*(ln_x3_star^2)
gen ln_x4sq = 0.5*(ln_x4_star^2)

gen ln_x1x2 = ln_x1_star*ln_x2_star
gen ln_x1x3 = ln_x1_star*ln_x3_star
gen ln_x1x4 = ln_x1_star*ln_x4_star
gen ln_x2x3 = ln_x2_star*ln_x3_star
gen ln_x2x4 = ln_x2_star*ln_x4_star
gen ln_x3x4 = ln_x3_star*ln_x4_star

gen ln_s1sq = 0.5*(ln_s1_star^2)

gen ln_x1s1 = ln_x1_star*ln_s1_star
gen ln_x2s1 = ln_x2_star*ln_s1_star
gen ln_x3s1 = ln_x3_star*ln_s1_star
gen ln_x4s1 = ln_x4_star*ln_s1_star

*=== Frontier estimation: v2 Spec 3 ===*
capture which parmest
if _rc ssc install parmest

sfcross n_ln_y1 ///
    ln_x1_star ln_x2_star ln_x3_star ln_x4_star ///
    ln_x1sq ln_x2sq ln_x3sq ln_x4sq ///
    ln_x1x2 ln_x1x3 ln_x1x4 ln_x2x3 ln_x2x4 ln_x3x4 ///
    ln_s1_star ln_s1sq ln_x1s1 ln_x2s1 ln_x3s1 ln_x4s1, ///
    dist(h) cost ///
    usigma(broader_permit_share_norm avg_fish_ratio_im_norm) ///
    technique(nr) dif posthessian iter(500)

estimates store frontier_spec3
estimates save "$ESTIMATES/frontier_spec3", replace
matrix V = e(V)
mat2txt, matrix(V) saving("$ESTIMATES/frontier_spec3_V.txt") replace
parmest, saving("$ESTIMATES/frontier_spec3_parms.dta", replace)

*--------------------------------------------------------------------
* MRT and the elasticities behind it
*
* Homogeneity of the distance function gives
*     MRT = - eps_s / ( 1 + eps_s + eps_x1 + eps_x2 + eps_x3 + eps_x4 )
*
* Each eps is a translog elasticity: the first-order coefficient plus every
* second-order term that involves that regressor, evaluated at the point of
* interest.  Writing L3 = ln_x3_star, L4 = ln_x4_star and holding every other
* log regressor at zero (its geometric mean):
*
*     eps_s  = b_s1 + b_x3s1*L3 + b_x4s1*L4
*     eps_x1 = b_x1 + b_x1x3*L3 + b_x1x4*L4
*     eps_x2 = b_x2 + b_x2x3*L3 + b_x2x4*L4
*     eps_x3 = b_x3 + b_x3sq*L3 + b_x3x4*L4
*     eps_x4 = b_x4 + b_x4sq*L4 + b_x3x4*L3
*
* At L3 = L4 = 0 the denominator collapses to
*     1 + b_s1 + b_x1 + b_x2 + b_x3 + b_x4,
* which is the at-means expression used for Table S2.  One template therefore
* serves both tables: Table S2 is this formula at L3 = L4 = 0, and Table S5 is
* the same formula at the diversification quantiles.
*--------------------------------------------------------------------

* Elasticity building blocks.  L3TOK and L4TOK are placeholders replaced by a
* scalar name before each nlcom call, so evaluation keeps full precision.
local ES "(_b[ln_s1_star] + _b[ln_x3s1]*L3TOK + _b[ln_x4s1]*L4TOK)"
local E1 "(_b[ln_x1_star] + _b[ln_x1x3]*L3TOK + _b[ln_x1x4]*L4TOK)"
local E2 "(_b[ln_x2_star] + _b[ln_x2x3]*L3TOK + _b[ln_x2x4]*L4TOK)"
local E3 "(_b[ln_x3_star] + _b[ln_x3sq]*L3TOK + _b[ln_x3x4]*L4TOK)"
local E4 "(_b[ln_x4_star] + _b[ln_x4sq]*L4TOK + _b[ln_x3x4]*L3TOK)"
local MRT "-`ES' / (1 + `ES' + `E1' + `E2' + `E3' + `E4')"

*--------------------------------------------------------------------
* Table S2: MRT at means (every log regressor at zero)
*--------------------------------------------------------------------
scalar L_ZERO = 0

local e : subinstr local MRT "L3TOK" "(L_ZERO)", all
local e : subinstr local e   "L4TOK" "(L_ZERO)", all
nlcom (NMRT_y_given_s_at_means: `e')

* Save the scalar result if desired:
matrix b = r(b)
scalar NMRT_means = b[1,1]
scalar list NMRT_means

*--------------------------------------------------------------------
* Table S5: MRT at diversification quantiles
*
* Quantiles come from the NORMALIZED diversification measures and are turned
* into specialization, L = ln(1/q).  The margin that is not being varied is
* held at its own MEDIAN quantile, so Table S5 is exactly the middle row and
* the middle column of the Fig. 6b grid built by 26_hdf_mrt.do.
*--------------------------------------------------------------------
quietly summarize div_emp_diff_s_norm, detail
scalar L3_Q1 = ln(1/r(p25))   // low sectoral diversification  -> high specialization
scalar L3_Q2 = ln(1/r(p50))
scalar L3_Q3 = ln(1/r(p75))   // high sectoral diversification -> low specialization

quietly summarize div_fished_s_norm, detail
scalar L4_Q1 = ln(1/r(p25))   // low fisheries diversification
scalar L4_Q2 = ln(1/r(p50))
scalar L4_Q3 = ln(1/r(p75))   // high fisheries diversification

*========================*
* NMRT (dy/ds) varying x3, fisheries held at its median quantile
*========================*
estimates restore frontier_spec3

local SPEC ""
forvalues k = 1/3 {
    local e : subinstr local MRT "L3TOK" "(L3_Q`k')", all
    local e : subinstr local e   "L4TOK" "(L4_Q2)",   all
    local SPEC `"`SPEC' (NMRT_x3_Q`k': `e')"'
}
nlcom `SPEC', post

* Pairwise tests across x3 quantiles
test (NMRT_x3_Q1 = NMRT_x3_Q2)
test (NMRT_x3_Q1 = NMRT_x3_Q3)
test (NMRT_x3_Q2 = NMRT_x3_Q3)

cap which parmest
if !_rc parmest, saving("$ESTIMATES/NMRT_quantile_tests_x3.dta", replace)

* Table S5 Panel B: the same three contrasts as point estimates.
* `test` above returns only the Wald chi2 and its p-value; the table reports the
* difference itself with a standard error, so the contrasts are also run through
* nlcom on the posted vector. No new quantity -- the same comparisons, reported
* in the form the table needs.
nlcom (x3_Q1_minus_Q2: _b[NMRT_x3_Q1] - _b[NMRT_x3_Q2]) ///
      (x3_Q1_minus_Q3: _b[NMRT_x3_Q1] - _b[NMRT_x3_Q3]) ///
      (x3_Q2_minus_Q3: _b[NMRT_x3_Q2] - _b[NMRT_x3_Q3]), post

cap which parmest
if !_rc parmest, saving("$ESTIMATES/NMRT_contrasts_x3.dta", replace)

*========================*
* NMRT (dy/ds) varying x4, sectoral held at its median quantile
*========================*
estimates restore frontier_spec3

local SPEC ""
forvalues k = 1/3 {
    local e : subinstr local MRT "L3TOK" "(L3_Q2)",   all
    local e : subinstr local e   "L4TOK" "(L4_Q`k')", all
    local SPEC `"`SPEC' (NMRT_x4_Q`k': `e')"'
}
nlcom `SPEC', post

* Pairwise tests across x4 quantiles
test (NMRT_x4_Q1 = NMRT_x4_Q2)
test (NMRT_x4_Q1 = NMRT_x4_Q3)
test (NMRT_x4_Q2 = NMRT_x4_Q3)

* Optionally save NMRT results
cap which parmest
if !_rc parmest, saving("$ESTIMATES/NMRT_quantile_tests.dta", replace)

* Table S5 Panel B: the same three contrasts as point estimates.
* `test` above returns only the Wald chi2 and its p-value; the table reports the
* difference itself with a standard error, so the contrasts are also run through
* nlcom on the posted vector. No new quantity -- the same comparisons, reported
* in the form the table needs.
nlcom (x4_Q1_minus_Q2: _b[NMRT_x4_Q1] - _b[NMRT_x4_Q2]) ///
      (x4_Q1_minus_Q3: _b[NMRT_x4_Q1] - _b[NMRT_x4_Q3]) ///
      (x4_Q2_minus_Q3: _b[NMRT_x4_Q2] - _b[NMRT_x4_Q3]), post

cap which parmest
if !_rc parmest, saving("$ESTIMATES/NMRT_contrasts_x4.dta", replace)
