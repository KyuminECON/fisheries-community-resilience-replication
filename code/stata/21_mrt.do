*-------------------------------------------------------------------------------
* 21_mrt.do: Marginal rate of transformation (MRT) from the main frontier (spec 3): at means, its elasticities
*            with respect to each diversification margin, the cross-partial, and grids at diversification percentiles.
* Inputs:  $DERIVED/estimation_sample.dta, $ESTIMATES/ehdf_spec3.ster
* Outputs: $ESTIMATES/MRT_at_means.dta, MRT_elasticity_diversification.dta, MRT_elasticity_diff_test.dta, MRT_crosspartial.dta,
*          NMRT_quantile_tests{,_x3}.dta, NMRT_contrasts_x{3,4}.dta, MRT_emp_fish.dta, MRT_emp_fish_5-95.dta
*-------------------------------------------------------------------------------
version 17
set more off

clear
use "$DERIVED/estimation_sample.dta"
estimates use "$ESTIMATES/ehdf_spec3"
estimates store spec3

* Homogeneity of the distance function gives
*     MRT = -eps_s / (1 + eps_s + eps_x1 + eps_x2 + eps_x3 + eps_x4),
* where each elasticity is the first-order coefficient plus the second-order terms in the
* log regressors. L3 = ln_x3_star and L4 = ln_x4_star are set by the caller; every other
* log regressor is at zero.
capture program drop nmrt_expr
program define nmrt_expr, rclass
    args l3 l4
    local es "(_b[ln_s1_star] + _b[ln_x3s1]*`l3' + _b[ln_x4s1]*`l4')"
    local e1 "(_b[ln_x1_star] + _b[ln_x1x3]*`l3' + _b[ln_x1x4]*`l4')"
    local e2 "(_b[ln_x2_star] + _b[ln_x2x3]*`l3' + _b[ln_x2x4]*`l4')"
    local e3 "(_b[ln_x3_star] + _b[ln_x3sq]*`l3' + _b[ln_x3x4]*`l4')"
    local e4 "(_b[ln_x4_star] + _b[ln_x4sq]*`l4' + _b[ln_x3x4]*`l3')"
    return local expr "(-`es' / (1 + `es' + `e1' + `e2' + `e3' + `e4'))"
end

* ln(1/percentile) of a normalized diversification measure, i.e. the specialization regressor
capture program drop spec_at
program define spec_at
    args name var p
    quietly _pctile `var', p(`p')
    scalar `name' = ln(1 / r(r1))
end

scalar L_ZERO = 0

*==============================================================================*
* MRT at means (Table S2)
*==============================================================================*
nmrt_expr L_ZERO L_ZERO
nlcom (MRT_at_means: `r(expr)'), post
parmest, saving("$ESTIMATES/MRT_at_means.dta", replace)

*==============================================================================*
* Elasticity of the MRT with respect to ln diversification, and cross-partial (at means)
*==============================================================================*
estimates restore spec3
local d    "(1 + _b[ln_s1_star] + _b[ln_x1_star] + _b[ln_x2_star] + _b[ln_x3_star] + _b[ln_x4_star])"
local a    "(1 + _b[ln_x1_star] + _b[ln_x2_star] + _b[ln_x3_star] + _b[ln_x4_star])"
local sum3 "(_b[ln_x3sq] + _b[ln_x1x3] + _b[ln_x2x3] + _b[ln_x3x4])"
local sum4 "(_b[ln_x4sq] + _b[ln_x1x4] + _b[ln_x2x4] + _b[ln_x3x4])"
nlcom (dMRT_dlnDiv_industrial: (`a' * _b[ln_x3s1] - _b[ln_s1_star] * `sum3') / `d'^2) ///
      (dMRT_dlnDiv_fisheries:  (`a' * _b[ln_x4s1] - _b[ln_s1_star] * `sum4') / `d'^2), post
parmest, saving("$ESTIMATES/MRT_elasticity_diversification", replace)

nlcom (diff_industrial_v_fisheries: _b[dMRT_dlnDiv_industrial] - _b[dMRT_dlnDiv_fisheries]), post
parmest, saving("$ESTIMATES/MRT_elasticity_diff_test", replace)

* Second cross-partial of the MRT with respect to ln(x3) and ln(x4)
estimates restore spec3
local r3 "(_b[ln_x3s1] + `sum3')"
local r4 "(_b[ln_x4s1] + `sum4')"
nlcom (NMRT_crosspartial: (`d' * (_b[ln_x3s1] * `r4' + _b[ln_x4s1] * `r3') - 2 * _b[ln_s1_star] * `r3' * `r4') / `d'^3), post
parmest, saving("$ESTIMATES/MRT_crosspartial", replace)

*==============================================================================*
* MRT at the 25th, 50th and 75th percentiles (Table S5 and the 3x3 grid of Fig. 6b)
*==============================================================================*
forvalues k = 1/3 {
    local p = 25 * `k'
    spec_at L3_Q`k' div_emp_diff_s_norm `p'
    spec_at L4_Q`k' div_fished_s_norm `p'
}

* Table S5: one margin varies, the other at its median
foreach x in 3 4 {
    estimates restore spec3
    local spec ""
    forvalues k = 1/3 {
        if `x' == 3 {
            nmrt_expr L3_Q`k' L4_Q2
        }
        else {
            nmrt_expr L3_Q2 L4_Q`k'
        }
        local spec `"`spec' (NMRT_x`x'_Q`k': `r(expr)')"'
    }
    nlcom `spec', post
    test (NMRT_x`x'_Q1 = NMRT_x`x'_Q2)
    test (NMRT_x`x'_Q1 = NMRT_x`x'_Q3)
    test (NMRT_x`x'_Q2 = NMRT_x`x'_Q3)
    if `x' == 3 {
        parmest, saving("$ESTIMATES/NMRT_quantile_tests_x3.dta", replace)
    }
    else {
        parmest, saving("$ESTIMATES/NMRT_quantile_tests.dta", replace)
    }

    nlcom (x`x'_Q1_minus_Q2: _b[NMRT_x`x'_Q1] - _b[NMRT_x`x'_Q2]) ///
          (x`x'_Q1_minus_Q3: _b[NMRT_x`x'_Q1] - _b[NMRT_x`x'_Q3]) ///
          (x`x'_Q2_minus_Q3: _b[NMRT_x`x'_Q2] - _b[NMRT_x`x'_Q3]), post
    parmest, saving("$ESTIMATES/NMRT_contrasts_x`x'.dta", replace)
}

* 3x3 grid and the difference-in-differences between the corner cells
estimates restore spec3
local spec ""
forvalues i = 1/3 {
    forvalues j = 1/3 {
        nmrt_expr L3_Q`i' L4_Q`j'
        local e`i'`j' "`r(expr)'"
        local spec `"`spec' (NMRT_X3Q`i'_X4Q`j': `e`i'`j'')"'
    }
}
local spec `"`spec' (Differences_Q3Q3_Q3Q1: (`e33' - `e31') - (`e13' - `e11'))"'
nlcom `spec', post
parmest, saving("$ESTIMATES/MRT_emp_fish", replace)

*==============================================================================*
* MRT grid at the 5th-95th percentiles (Figs. 5 and 6a)
*==============================================================================*
tempfile grid one
local first 1
forvalues q = 5(5)95 {
    spec_at Lq div_emp_diff_s_norm `q'
    forvalues p = 5(5)95 {
        spec_at Lp div_fished_s_norm `p'
        estimates restore spec3
        nmrt_expr Lq Lp
        nlcom (NMRT_`q'_`p': `r(expr)'), post
        parmest, saving(`one', replace)
        preserve
            use `one', clear
            if !`first' append using `grid'
            save `grid', replace
        restore
        local first 0
    }
}
preserve
    use `grid', clear
    save "$ESTIMATES/MRT_emp_fish_5-95", replace
restore
