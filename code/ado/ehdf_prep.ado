*! ehdf_prep: geometric-mean normalization and translog terms for the EHDF
*  Variables are stored as floats, as in the estimation reported in the paper.
*  Creates <var>_norm for the analysis variables, then the dependent variable n_ln_y1,
*  the log "star" variables ln_x1_star ... ln_x4_star and ln_s1_star (homogeneity-normalized
*  by growth), and their squares (with the 1/2 factor) and interactions.
*  Option hhi uses the inverse-HHI diversification measures instead of the Shannon indices.
program define ehdf_prep
    version 17
    syntax [, HHI]

    local normvars mu_return sigma_reg_exp div_emp div_emp_diff_s div_emp_diff ///
        avg_pop broader_emp_share broader_permit_share div_fished_s div_fished ///
        avg_fish_ratio_im avg_fish_ratio avg_fish_ratio_im_fc avg_wage_pc avg_fishermen
    foreach var of local normvars {
        quietly {
            gen log_`var' = log(`var')
            summarize log_`var'
            gen `var'_norm = `var' / exp(r(mean))
            drop log_`var'
        }
    }

    if "`hhi'" == "" {
        local div3 div_emp_diff_s_norm
        local div4 div_fished_s_norm
    }
    else {
        local div3 div_emp_diff_norm
        local div4 div_fished_norm
    }

    gen n_ln_y1 = -log(mu_return_norm)
    gen s1_star = sigma_reg_exp_norm * mu_return_norm
    gen x1_star = avg_pop_norm * mu_return_norm
    gen x2_star = avg_wage_pc_norm * mu_return_norm
    gen x3_star = 1 / `div3' * mu_return_norm
    gen x4_star = 1 / `div4' * mu_return_norm
    gen ln_s1_star = log(s1_star)
    forvalues i = 1/4 {
        gen ln_x`i'_star = log(x`i'_star)
    }

    forvalues i = 1/4 {
        gen ln_x`i'sq = 0.5 * ln_x`i'_star * ln_x`i'_star
        gen ln_x`i's1 = ln_x`i'_star * ln_s1_star
        forvalues j = `=`i'+1'/4 {
            gen ln_x`i'x`j' = ln_x`i'_star * ln_x`j'_star
        }
    }
    gen ln_s1sq = 0.5 * ln_s1_star * ln_s1_star
end
