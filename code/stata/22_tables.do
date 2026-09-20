*-------------------------------------------------------------------------------
* 22_tables.do: LaTeX table bodies for Tables S1-S5, written from the saved estimates.
* Inputs:  $DERIVED/estimation_sample.dta, $ESTIMATES/ehdf_spec{1,2,3}.ster, hhi_spec{1,2,3}.ster,
*          MRT_at_means.dta, NMRT_quantile_tests{,_x3}.dta, NMRT_contrasts_x{3,4}.dta
* Outputs: $TABLES/tableS{1,2,3,4,5}_*.tex (bodies for \input inside a tabular; the last row has no \\)
*-------------------------------------------------------------------------------
version 17
set more off

capture program drop fmt
program define fmt, rclass
    args b se
    local z = abs(`b' / `se')
    local p = 2 * (1 - normal(`z'))
    local stars = cond(`p' < 0.01, "***", cond(`p' < 0.05, "**", cond(`p' < 0.1, "*", "")))
    local est = string(`b', "%5.3f")
    if "`est'" == "-0.000" local est "0.000"
    return local est = "`est'" + "`stars'"
    return local se  = "(" + string(`se', "%5.3f") + ")"
end

*==============================================================================*
* Table S1: summary statistics
*==============================================================================*
use "$DERIVED/estimation_sample.dta", clear
tempname fh
file open `fh' using "$TABLES/tableS1_summary.tex", write replace text
foreach v in mu_return sigma_reg_exp div_emp_diff_s div_fished_s {
    local lab : word `=cond("`v'"=="mu_return",1,cond("`v'"=="sigma_reg_exp",2,cond("`v'"=="div_emp_diff_s",3,4)))' of ///
        "Employment Growth (Avg. Geom. Return)" "Growth Instability (Geom. Std.)" "Sectoral Diversification" "Fisheries Diversification"
    quietly summarize `v'
    local end = cond("`v'" == "div_fished_s", "", " \\")
    file write `fh' "`lab' & `r(N)' & " %5.3f (r(mean)) " & " %5.3f (r(sd)) " & " %5.3f (r(min)) " & " %5.3f (r(max)) "`end'" _n
}
file close `fh'

*==============================================================================*
* Table S2: MRT at means
*==============================================================================*
use "$ESTIMATES/MRT_at_means.dta", clear
file open `fh' using "$TABLES/tableS2_mrt_means.tex", write replace text
file write `fh' "Marginal Rate of Transformation & " %6.4f (`=estimate[1]') "$^{***}$ \\" _n
file write `fh' " & (" %5.3f (`=stderr[1]') ") \\" _n
file close `fh'

*==============================================================================*
* Tables S3 and S4: EHDF coefficients
*==============================================================================*
capture program drop ehdf_table
program define ehdf_table
    args outfile prefix
    tempname fh
    file open `fh' using "`outfile'", write replace text
    local terms   "Frontier:ln_x1_star Frontier:ln_x2_star Frontier:ln_x3_star Frontier:ln_x4_star Frontier:ln_x3sq Frontier:ln_x4sq Frontier:ln_x3x4 Frontier:ln_s1_star Frontier:ln_s1sq"
    local labels `""Population ($\alpha_{1}$)" "Wage income per capita ($\alpha_{2}$)" "Sectoral specialization ($\alpha_{3}$)" "Fisheries specialization ($\alpha_{4}$)" "Sectoral specialization squared ($\alpha_{33}$)" "Fisheries specialization squared ($\alpha_{44}$)" "Sectoral $\times$ fisheries specialization ($\alpha_{34}$)" "Economic instability ($\delta_{1}$)" "Economic instability squared ($\delta_{11}$)""'
    local ineff   "Usigma:broader_permit_share_norm Usigma:avg_fish_ratio_im_norm"
    local ilabels `""Fishing permit concentration" "Fishing revenue/wage income ratio""'

    foreach block in frontier ineff {
        if "`block'" == "frontier" {
            local tl `terms'
            local ll `"`labels'"'
        }
        else {
            file write `fh' "\midrule" _n "\textbf{Inefficiency controls} & & & \\" _n "\cmidrule(lr){1-4}" _n
            local tl `ineff'
            local ll `"`ilabels'"'
        }
        local i = 0
        foreach t of local tl {
            local ++i
            local lab : word `i' of `ll'
            local row1 "`lab'"
            local row2 ""
            forvalues m = 1/3 {
                estimates use "$ESTIMATES/`prefix'_spec`m'"
                capture local b  = _b[`t']
                capture local se = _se[`t']
                if _rc {
                    local row1 "`row1' & "
                    local row2 "`row2' & "
                }
                else {
                    fmt `b' `se'
                    local row1 "`row1' & `r(est)'"
                    local row2 "`row2' & `r(se)'"
                }
            }
            file write `fh' "`row1' \\" _n "`row2' \\" _n
        }
    }
    file write `fh' "\midrule" _n "Observations & 177 & 177 & 177" _n
    file close `fh'
end

ehdf_table "$TABLES/tableS3_ehdf.tex"     ehdf
ehdf_table "$TABLES/tableS4_ehdf_hhi.tex" hhi

*==============================================================================*
* Table S5: MRT by diversification quantile
*==============================================================================*
file open `fh' using "$TABLES/tableS5_mrt_quantiles.tex", write replace text
use "$ESTIMATES/NMRT_quantile_tests_x3.dta", clear
forvalues k = 1/3 {
    local b3_`k'  = estimate[`k']
    local se3_`k' = stderr[`k']
}
use "$ESTIMATES/NMRT_quantile_tests.dta", clear
forvalues k = 1/3 {
    local b4_`k'  = estimate[`k']
    local se4_`k' = stderr[`k']
}
local names `""Q1 (25th pct.)\textsuperscript{a}" "Q2 (50th pct.)\textsuperscript{b}" "Q3 (75th pct.)\textsuperscript{c}""'
forvalues k = 1/3 {
    local lab : word `k' of `names'
    fmt `b3_`k'' `se3_`k''
    local r3 "`r(est)'"
    local s3 "`r(se)'"
    fmt `b4_`k'' `se4_`k''
    file write `fh' "`lab' & `r3' & `r(est)' \\" _n " & `s3' & `r(se)' \\" _n
}
file write `fh' "\midrule" _n "\multicolumn{3}{l}{\textbf{Panel B.} Pairwise Wald contrasts (difference)} \\" _n "\midrule" _n
local pairs `""Q1 $-$ Q2" "Q1 $-$ Q3" "Q2 $-$ Q3""'
use "$ESTIMATES/NMRT_contrasts_x3.dta", clear
forvalues k = 1/3 {
    local c3_`k' = estimate[`k']
    local d3_`k' = stderr[`k']
}
use "$ESTIMATES/NMRT_contrasts_x4.dta", clear
forvalues k = 1/3 {
    local lab : word `k' of `pairs'
    fmt `c3_`k'' `d3_`k''
    local r3 "`r(est)'"
    local s3 "`r(se)'"
    fmt `=estimate[`k']' `=stderr[`k']'
    local end = cond(`k' == 3, "", " \\")
    file write `fh' "`lab' & `r3' & `r(est)' \\" _n " & `s3' & `r(se)'`end'" _n
}
file close `fh'
