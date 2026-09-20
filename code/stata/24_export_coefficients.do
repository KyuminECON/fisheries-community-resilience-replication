*-------------------------------------------------------------------------------
* Filename:     24_export_coefficients.do
* Purpose:      Export the EHDF spec-3 coefficient vector that the R frontier
*               figures need, so R never hardcodes estimates again.
* Inputs:       $ESTIMATES/frontier_spec3.ster  (written by 21_ehdf_nmrt.do)
* Outputs:      $ESTIMATES/ehdf_spec3_coefficients.csv
* Requires:     Stata 17+
* Author:       Added for the replication package, 2026.
*
* WHY this file exists: the original Frontier_diversification.R carried the whole
* parameter vector as literals under the comment
*     "# Coefficients (from Stata output screenshot)"
* and those transcribed numbers do not match any saved .ster exactly (e.g. the
* x4 first-order term was -0.0050609 in R versus -0.0055695 in a clean run).
* Exporting them here makes the Stata -> R handoff explicit and self-updating.
* No specification changes; this only moves numbers that already existed.
*-------------------------------------------------------------------------------

*==============================================================================*
* Setup
*==============================================================================*
version 17
set more off

estimates use "$ESTIMATES/frontier_spec3"

*==============================================================================*
* Main: pull the frontier equation coefficients into a tidy long file
*==============================================================================*
tempname fh
file open `fh' using "$ESTIMATES/ehdf_spec3_coefficients.csv", write replace
file write `fh' "term,estimate" _n

local terms ///
    _cons ///
    ln_x1_star ln_x2_star ln_x3_star ln_x4_star ///
    ln_x1sq ln_x2sq ln_x3sq ln_x4sq ///
    ln_x1x2 ln_x1x3 ln_x1x4 ln_x2x3 ln_x2x4 ln_x3x4 ///
    ln_s1_star ln_s1sq ///
    ln_x1s1 ln_x2s1 ln_x3s1 ln_x4s1

foreach t of local terms {
    local b = _b[`t']
    file write `fh' "`t',`=string(`b', "%20.12f")'" _n
}
file close `fh'

*==============================================================================*
* Checks
*==============================================================================*
* The R frontier solver divides by these; a missing coefficient would fail
* silently and produce an empty plot rather than an error.
foreach t of local terms {
    capture assert !missing(_b[`t'])
    if _rc {
        display as error "24_export_coefficients: coefficient `t' is missing"
        exit 459
    }
}

preserve
    import delimited "$ESTIMATES/ehdf_spec3_coefficients.csv", clear varnames(1)
    assert _N == 21
    display as text "24_export_coefficients: wrote `=_N' coefficients"
restore

display as text "Saved: $ESTIMATES/ehdf_spec3_coefficients.csv"
