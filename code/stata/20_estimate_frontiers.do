*-------------------------------------------------------------------------------
* 20_estimate_frontiers.do: Estimates every frontier specification once (Tables S3 and S4) and saves the estimation sample.
* Inputs:  $DERIVED/master_local_fish_max.dta
* Outputs: $ESTIMATES/ehdf_spec{1,2,3}.ster, hhi_spec{1,2,3}.ster, ehdf_spec3_coefficients.csv,
*          $DERIVED/estimation_sample.dta
*-------------------------------------------------------------------------------
version 17
set more off

local frontier ln_x1_star ln_x2_star ln_x3_star ln_x4_star ///
    ln_x1sq ln_x2sq ln_x3sq ln_x4sq ///
    ln_x1x2 ln_x1x3 ln_x1x4 ln_x2x3 ln_x2x4 ln_x3x4 ///
    ln_s1_star ln_s1sq ln_x1s1 ln_x2s1 ln_x3s1 ln_x4s1

*==============================================================================*
* Shannon diversification indices (Table S3)
*==============================================================================*
clear
use "$DERIVED/master_local_fish_max.dta"
keep if div_fished_s != . & mu_reg != .
ehdf_prep

* Spec 1: no inefficiency controls
sfcross n_ln_y1 `frontier', dist(h) technique(bfgs nr dfp) iter(500) cost
estimates save "$ESTIMATES/ehdf_spec1", replace

* Spec 2: broader permit share
sfcross n_ln_y1 `frontier', dist(h) usigma(broader_permit_share_norm) ///
    cost technique(dfp bfgs nr) dif iter(500)
estimates save "$ESTIMATES/ehdf_spec2", replace

* Spec 3 (main): broader permit share and fishing revenue-to-wage ratio
sfcross n_ln_y1 `frontier', dist(h) ///
    usigma(broader_permit_share_norm avg_fish_ratio_im_norm) ///
    cost technique(nr) dif posthessian iter(500)
estimates save "$ESTIMATES/ehdf_spec3", replace

* Frontier coefficients for the R figures
tempname fh
file open `fh' using "$ESTIMATES/ehdf_spec3_coefficients.csv", write replace
file write `fh' "term,estimate" _n
foreach t in _cons `frontier' {
    file write `fh' "`t',`=string(_b[`t'], "%20.12f")'" _n
}
file close `fh'

* Estimation sample: the 179 rows above drop to the 177 complete cases.
* Every table and figure uses this file, with the normalization used in estimation.
assert e(N) == 177
keep if e(sample)
save "$DERIVED/estimation_sample.dta", replace

*==============================================================================*
* Inverse-HHI diversification measures (Table S4)
*==============================================================================*
clear
use "$DERIVED/master_local_fish_max.dta"
keep if div_fished_s != . & mu_reg != .
ehdf_prep, hhi

sfcross n_ln_y1 `frontier', dist(h) technique(bfgs) iter(500) cost
estimates save "$ESTIMATES/hhi_spec1", replace

sfcross n_ln_y1 `frontier', dist(h) technique(nr) usigma(broader_permit_share_norm) iter(500) cost
estimates save "$ESTIMATES/hhi_spec2", replace

sfcross n_ln_y1 `frontier', dist(h) ///
    usigma(broader_permit_share_norm avg_fish_ratio_im_norm) cost technique(dfp) posthessian iter(500)
estimates save "$ESTIMATES/hhi_spec3", replace
