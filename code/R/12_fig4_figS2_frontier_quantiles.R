#-------------------------------------------------------------------------------
# Filename:     12_fig4_figS2_frontier_quantiles.R
# Purpose:      Fig. 4 and Fig. S.2: efficient frontiers by diversification quantile.
# Inputs:       $DERIVED/R_plot.dta, $ESTIMATES/ehdf_spec3_coefficients.csv
# Outputs:      $FIGURES/fig04_frontier_by_diversification_quantile.png, figS2_frontier_div_by_div.png
# Requires:     config/paths.R (sourced below); see renv.lock for package versions
# Author:       Kim
#               Ported for the replication package 2026. Only paths, the source
#               of the coefficients, and the figure-saving calls were changed.
#-------------------------------------------------------------------------------


source(file.path(Sys.getenv("REPLICATION_ROOT", unset = here::here()), "config", "paths.R"))

# ------------------------------------------------------------
# Hyperbolic Distance Frontier plots (diversification on curves)
# - Two-panel figure (fish DIV vs sector DIV), curves trimmed at peaks
# - Three-subfigure figure (fix fish DIV; vary sector DIV), curves trimmed at peaks
# - Grid backgrounds kept; NO dashed peak guides
# Data: R_plot.dta (contains normalized vars)
# Range: sigma in [0.85, 1.20]
# ------------------------------------------------------------

suppressPackageStartupMessages({
  library(haven)
  library(dplyr)
  library(tidyr)
  library(purrr)
  library(ggplot2)
})

# ---------- Load data ----------
path <- file.path(DERIVED, "R_plot.dta")
D0 <- read_dta(path) %>% as_tibble()
stopifnot(all(c("sigma_reg_exp_norm","div_emp_diff_s_norm","div_fished_s_norm") %in% names(D0)))

# ---------- Grid and percentiles ----------
s_grid <- seq(0.85, 1.20, length.out = 200)

# Diversification percentiles (normalized)
div_emp_q  <- quantile(D0$div_emp_diff_s_norm, probs = c(.25,.50,.75), na.rm = TRUE)   # sectoral diversification
div_fish_q <- quantile(D0$div_fished_s_norm,   probs = c(.25,.50,.75), na.rm = TRUE)   # fisheries diversification

# Named for clean legends
div_emp_named  <- setNames(as.numeric(div_emp_q),  c("25th","50th","75th"))
div_fish_named <- setNames(as.numeric(div_fish_q), c("25th","50th","75th"))

# ---------- Coefficients ----------
# WHY this changed: the original carried the whole parameter vector as literals
# under the comment "(from Stata output screenshot)". Those transcribed numbers
# matched no saved .ster exactly (the x4 first-order term was -0.0050609 in R
# versus -0.0055695 in a clean run), so the figures could drift away from the
# tables without anyone noticing. They are now read from the file that
# code/stata/24_export_coefficients.do writes.
.coef_path <- file.path(ESTIMATES, "ehdf_spec3_coefficients.csv")
if (!file.exists(.coef_path)) {
  stop("Missing ", .coef_path, "\nRun the Stata stage first (code/stata/00_master.do).")
}
.cf <- utils::read.csv(.coef_path, stringsAsFactors = FALSE)
.b  <- stats::setNames(.cf$estimate, .cf$term)

alpha0 <- unname(.b["_cons"])
alpha  <- unname(.b[c("ln_x1_star", "ln_x2_star", "ln_x3_star", "ln_x4_star")])
Aalpha <- matrix(c(
  .b["ln_x1sq"],  .b["ln_x1x2"], .b["ln_x1x3"], .b["ln_x1x4"],
  .b["ln_x1x2"],  .b["ln_x2sq"], .b["ln_x2x3"], .b["ln_x2x4"],
  .b["ln_x1x3"],  .b["ln_x2x3"], .b["ln_x3sq"], .b["ln_x3x4"],
  .b["ln_x1x4"],  .b["ln_x2x4"], .b["ln_x3x4"], .b["ln_x4sq"]
), 4, 4, byrow = TRUE)
delta1  <- unname(.b["ln_s1_star"])
delta11 <- unname(.b["ln_s1sq"])
eta     <- unname(.b[c("ln_x1s1", "ln_x2s1", "ln_x3s1", "ln_x4s1")])
stopifnot(!any(is.na(c(alpha0, alpha, Aalpha, delta1, delta11, eta))))

# ---------- Frontier evaluator ----------
# Solves A*L^2 + B*L + C = 0 for L = ln(y1)
# Inputs: levels for x = c(level1, level2, level3, level4)
# Model constructs x_i = ln(level_i) + ln(y1), s1 = ln(sigma) + ln(y1)
frontier_y <- function(s, x, alpha0, alpha, Aalpha, delta1, delta11, eta) {
  one <- rep(1, 4)
  Lx  <- log(x)
  Ls  <- log(s)
  
  A <- 0.5 * as.numeric(t(one) %*% Aalpha %*% one) + 0.5 * delta11 + sum(eta)
  B <- (1 + sum(alpha) + delta1 +
          as.numeric(t(one) %*% Aalpha %*% Lx) +
          sum(eta * Lx)) +
    (sum(eta) + delta11) * Ls
  C <- alpha0 +
    sum(alpha * Lx) +
    0.5 * as.numeric(t(Lx) %*% Aalpha %*% Lx) +
    delta1 * Ls +
    0.5 * delta11 * Ls^2 +
    Ls * sum(eta * Lx)
  
  D <- B^2 - 4 * A * C
  D[D < 0] <- NA_real_
  
  L1 <- (-B + sqrt(D)) / (2 * A)
  L2 <- (-B - sqrt(D)) / (2 * A)
  L  <- ifelse(abs(L1) <= abs(L2), L1, L2)
  exp(L)
}

# ---------- Build panels (DIV on curves) ----------
# Left: vary fisheries diversification (x4 level = 1/div_fish)
# Right: vary sectoral diversification (x3 level = 1/div_sector)
make_panel_div <- function(which_var = c("fish","sector")) {
  which_var <- match.arg(which_var)
  if (which_var == "fish") {
    purrr::map2_dfr(names(div_fish_named), as.numeric(div_fish_named), ~{
      x4_level <- 1/.y  # model needs specialization level = 1/diversification
      tibble(
        s      = s_grid,
        growth = frontier_y(s_grid, x = c(1, 1, 1, x4_level),
                            alpha0, alpha, Aalpha, delta1, delta11, eta),
        percentile = .x,
        facet      = "Fisheries diversification"
      )
    })
  } else {
    purrr::map2_dfr(names(div_emp_named), as.numeric(div_emp_named), ~{
      x3_level <- 1/.y  # model needs specialization level = 1/diversification
      tibble(
        s      = s_grid,
        growth = frontier_y(s_grid, x = c(1, 1, x3_level, 1),
                            alpha0, alpha, Aalpha, delta1, delta11, eta),
        percentile = .x,
        facet      = "Sectoral diversification"
      )
    })
  }
}

D_fish_div <- make_panel_div("fish")
D_sect_div <- make_panel_div("sector")

Dplot <- bind_rows(D_fish_div, D_sect_div) %>%
  mutate(
    percentile = factor(percentile, levels = c("25th","50th","75th")),
    facet      = factor(facet, levels = c("Fisheries diversification","Sectoral diversification"))
  ) %>%
  tidyr::drop_na(growth)

# ---------- Peaks per curve (for trimming only) ----------
peaks_two <- Dplot %>%
  group_by(facet, percentile) %>%
  slice_max(growth, n = 1, with_ties = FALSE) %>%
  ungroup() %>%
  rename(s_peak = s, y_peak = growth)

# Trim each curve: keep only s <= s_peak for that facet×percentile
Dplot_trim <- Dplot %>%
  left_join(peaks_two %>% select(facet, percentile, s_peak, y_peak),
            by = c("facet", "percentile")) %>%
  filter(!is.na(s_peak), s <= s_peak)

# ---------- Two-panel plot (trimmed; grid kept; NO dashed guides) ----------
palette3    <- c("25th"="#E69F00", "50th"="#009E73", "75th"="#CC79A7")
font_family <- ifelse(Sys.info()[["sysname"]] == "Windows", "Times New Roman", "Times")
facet_labels <- c(
  "Fisheries diversification" = "(a) Fisheries diversification",
  "Sectoral diversification"  = "(b) Sectoral diversification"
)

p_two <- ggplot(Dplot_trim, aes(x = s, y = growth, color = percentile, group = percentile)) +
  geom_line(linewidth = 1.6) +
  facet_wrap(
    ~ facet, nrow = 1,
    labeller = labeller(facet = as_labeller(facet_labels))
  ) +
  scale_color_manual(values = palette3, name = "Diversification percentile") +
  labs(x = "Instability", y = "Growth") +
  theme_bw(base_size = 13, base_family = font_family) +
  theme(
    panel.grid.major = element_line(linewidth = 0.35, colour = "grey80"),
    panel.grid.minor = element_line(linewidth = 0.25, colour = "grey90"),
    strip.text       = element_text(face = "bold"),
    legend.position  = "bottom"
  ) +
  coord_cartesian(clip = "off")

print(p_two)

# ============================================================
# Three-subfigure plot (DIV × DIV): fix fisheries DIV; vary sector DIV
# (Each curve trimmed at its own peak; grid kept; NO dashed guides)
# ============================================================

# Build the underlying (untrimmed) panel
D_fix_x4_div <- purrr::map_dfr(
  names(div_fish_named),                           # facets: fisheries DIV percentiles
  function(x4_div_lab) {
    x4_div_val <- unname(div_fish_named[x4_div_lab])  # fish diversification value
    x4_level   <- 1 / x4_div_val                      # model needs specialization
    purrr::map2_dfr(
      names(div_emp_named), as.numeric(div_emp_named),  # lines: sector diversification
      ~{
        x3_div_lab <- .x
        x3_div_val <- .y
        x3_level   <- 1 / x3_div_val                   # model needs specialization
        tibble(
          s            = s_grid,
          growth       = frontier_y(s_grid, x = c(1, 1, x3_level, x4_level),
                                    alpha0, alpha, Aalpha, delta1, delta11, eta),
          x4_fixed_div = x4_div_lab,   # facet label (fish DIV percentile)
          x3_div       = x3_div_lab    # legend label (sector DIV percentile)
        )
      }
    )
  }
) %>%
  tidyr::drop_na(growth) %>%
  mutate(
    x4_fixed_div = factor(x4_fixed_div, levels = c("25th","50th","75th")),
    x3_div       = factor(x3_div,       levels = c("25th","50th","75th"))
  )

# Peaks for trimming (per facet×line)
peaks_divdiv <- D_fix_x4_div %>%
  group_by(x4_fixed_div, x3_div) %>%
  slice_max(growth, n = 1, with_ties = FALSE) %>%
  ungroup() %>%
  rename(s_peak = s, y_peak = growth)

# Trim each curve at its own peak
D_fix_x4_div_trim <- D_fix_x4_div %>%
  left_join(peaks_divdiv %>% select(x4_fixed_div, x3_div, s_peak, y_peak),
            by = c("x4_fixed_div", "x3_div")) %>%
  filter(!is.na(s_peak), s <= s_peak)

# Plot (Times, grid visible, NO dashed guides)
pal3 <- c("25th"="#E69F00", "50th"="#009E73", "75th"="#CC79A7")
p_fix_x4_div <- ggplot(D_fix_x4_div_trim, aes(x = s, y = growth, color = x3_div, group = x3_div)) +
  geom_line(linewidth = 1.6) +
  facet_wrap(
    ~ x4_fixed_div, nrow = 1,
    labeller = labeller(x4_fixed_div = function(v) paste("Fisheries diversification fixed at", v))
  ) +
  scale_color_manual(values = pal3, name = "Sectoral diversification percentile") +
  labs(x = "Instability", y = "Growth") +
  theme_bw(base_size = 13, base_family = font_family) +
  theme(
    panel.grid.major = element_line(linewidth = 0.35, colour = "grey80"),
    panel.grid.minor = element_line(linewidth = 0.25, colour = "grey90"),
    strip.text       = element_text(face = "bold"),
    legend.position  = "bottom"
  ) +
  coord_cartesian(clip = "off")

print(p_fix_x4_div)

# ---------- (Optional) save figures ----------
# out_dir <- dirname(path)
fig_dir <- FIGURES

ggsave(file.path(FIGURES, "fig04_frontier_by_diversification_quantile.png"), p_two, width = 8.6, height = 4.6, dpi = 320)
ggsave(file.path(FIGURES, "figS2_frontier_div_by_div.png"),                 p_fix_x4_div, width = 9.6, height = 4.6, dpi = 320)



######




# ===== Three subfigures (DIV x DIV): FIX fisheries diversification; VARY sectoral diversification =====

# Named diversification percentiles (labels)
div_fish_named <- setNames(as.numeric(div_fish_q), c("25th","50th","75th"))  # fisheries diversification (for facets)
div_x3_named   <- setNames(as.numeric(div_emp_q),  c("25th","50th","75th"))  # sectoral diversification (for lines)

D_fix_x4_div <- purrr::map_dfr(
  names(div_fish_named),                           # facets: fisheries DIV percentiles
  function(x4_div_lab) {
    x4_div_val <- unname(div_fish_named[x4_div_lab])  # fisheries diversification value
    x4_level   <- 1 / x4_div_val                      # model input needs specialization
    
    # sweep sectoral DIV percentiles (lines)
    purrr::map2_dfr(
      names(div_x3_named), as.numeric(div_x3_named),
      ~{
        x3_div_lab <- .x
        x3_div_val <- .y
        x3_level   <- 1 / x3_div_val                  # model input needs specialization
        
        tibble(
          s        = s_grid,
          growth   = frontier_y(s_grid, x = c(1, 1, x3_level, x4_level),
                                alpha0, alpha, Aalpha, delta1, delta11, eta),
          x4_fixed_div = x4_div_lab,   # facet label: fisheries diversification percentile
          x3_div       = x3_div_lab    # legend label: sectoral diversification percentile
        )
      }
    )
  }
) %>%
  tidyr::drop_na(growth) %>%
  mutate(
    x4_fixed_div = factor(x4_fixed_div, levels = c("25th","50th","75th")),
    x3_div       = factor(x3_div,       levels = c("25th","50th","75th"))
  )

# ---------- Peak guides per curve (facet x line) ----------
# Find argmax_y for each (x4_fixed_div facet, x3_div line)
peaks <- D_fix_x4_div %>%
  group_by(x4_fixed_div, x3_div) %>%
  slice_max(growth, n = 1, with_ties = FALSE) %>%
  ungroup()

# Horizontal guide start at left edge of each facet
s_min_by_facet <- D_fix_x4_div %>%
  group_by(x4_fixed_div) %>%
  summarize(s_min = min(s, na.rm = TRUE), .groups = "drop")

peaks <- peaks %>% left_join(s_min_by_facet, by = "x4_fixed_div")

# ---------- Plot ----------
font_family <- ifelse(Sys.info()[["sysname"]] == "Windows", "Times New Roman", "Times")

p_fix_x4_div <- ggplot(D_fix_x4_div, aes(x = s, y = growth, color = x3_div, group = x3_div)) +
  geom_line(linewidth = 1.6) +
  facet_wrap(
    ~ x4_fixed_div, nrow = 1,
    labeller = labeller(x4_fixed_div = function(v) paste("Fisheries diversification fixed at", v))
  ) +
  scale_color_manual(values = pal3, name = "Sectoral diversification percentile") +
  labs(x = "Instability", y = "Growth") +
  theme_bw(base_size = 13, base_family = font_family) +
  theme(
    panel.grid.major = element_line(linewidth = 0.35, colour = "grey80"),
    panel.grid.minor = element_line(linewidth = 0.25, colour = "grey90"),
    strip.text       = element_text(face = "bold"),
    legend.position  = "bottom"
  ) +
  # vertical dashed line at s* per curve (peak instability location for each line)
  geom_vline(
    data = peaks,
    aes(xintercept = s, color = x3_div),
    linetype = "dashed", linewidth = 0.8, show.legend = FALSE
  ) +
  # horizontal dotted line at y* per curve (from facet's left edge to s*)
  geom_segment(
    data = peaks,
    aes(x = s_min, xend = s, y = growth, yend = growth, color = x3_div),
    linetype = "dotted", linewidth = 0.7, show.legend = FALSE
  ) +
  coord_cartesian(clip = "off")

print(p_fix_x4_div)
# ggsave(file.path(FIGURES, "figure-HDF_frontier_DIVxDIV_peaks.png"), p_fix_x4_div, width = 9.6, height = 4.6, dpi = 320)



######




# ============================================================
# Figure: FIX fisheries SPECIALIZATION; VARY sectoral DIVERSIFICATION
# - Curves are trimmed at their own peaks
# - Grid background kept; no dashed guides
# ============================================================

# Palette + font (redefine here for safety)
pal3 <- c("25th"="#E69F00", "50th"="#009E73", "75th"="#CC79A7")
font_family <- ifelse(Sys.info()[["sysname"]] == "Windows", "Times New Roman", "Times")

# Percentiles from the SPECIALIZATION distribution (compute directly!)
fish_spec_vec <- 1 / D0$div_fished_s_norm
fish_spec_named <- setNames(
  as.numeric(quantile(fish_spec_vec, probs = c(.25,.5,.75), na.rm = TRUE)),
  c("25th","50th","75th")
)

# Sectoral DIVERSIFICATION percentiles (as diversification)
div_x3_named <- setNames(
  as.numeric(quantile(D0$div_emp_diff_s_norm, probs = c(.25,.5,.75), na.rm = TRUE)),
  c("25th","50th","75th")
)

# Build panel (untrimmed): facets = fisheries specialization; lines = sectoral diversification
D_fix_x4_SPEC <- purrr::map_dfr(
  names(fish_spec_named),
  function(x4_spec_lab) {
    x4_spec_val <- unname(fish_spec_named[x4_spec_lab]) # fisheries specialization level for model
    purrr::map2_dfr(
      names(div_x3_named), as.numeric(div_x3_named),
      ~{
        x3_div_val <- .y
        x3_level   <- 1 / x3_div_val                     # model needs specialization for x3
        tibble(
          s             = s_grid,
          growth        = frontier_y(s_grid, x = c(1,1,x3_level,x4_spec_val),
                                     alpha0, alpha, Aalpha, delta1, delta11, eta),
          x4_fixed_spec = x4_spec_lab,                   # facet label (SPECIALIZATION percentile)
          x3_div_lab    = .x                             # legend label (SECTORAL diversification percentile)
        )
      }
    )
  }
) %>%
  tidyr::drop_na(growth) %>%
  dplyr::mutate(
    x4_fixed_spec = factor(x4_fixed_spec, levels = c("25th","50th","75th")),
    x3_div_lab    = factor(x3_div_lab,    levels = c("25th","50th","75th"))
  )

# ---- Trim each curve at its peak (per facet × line) ----
peaks_spec <- D_fix_x4_SPEC %>%
  dplyr::group_by(x4_fixed_spec, x3_div_lab) %>%
  dplyr::slice_max(growth, n = 1, with_ties = FALSE) %>%
  dplyr::ungroup() %>%
  dplyr::rename(s_peak = s, y_peak = growth)

D_fix_x4_SPEC_trim <- D_fix_x4_SPEC %>%
  dplyr::left_join(peaks_spec %>% dplyr::select(x4_fixed_spec, x3_div_lab, s_peak),
                   by = c("x4_fixed_spec","x3_div_lab")) %>%
  dplyr::filter(!is.na(s_peak), s <= s_peak)

# ---- Plot (grid kept; NO dashed guides) ----
p_fix_x4_SPEC <- ggplot(D_fix_x4_SPEC_trim, aes(s, growth, color = x3_div_lab, group = x3_div_lab)) +
  geom_line(linewidth = 1.6) +
  facet_wrap(
    ~ x4_fixed_spec, nrow = 1,
    labeller = labeller(x4_fixed_spec = function(v) paste("Fisheries specialization fixed at", v))
  ) +
  scale_color_manual(values = pal3, name = "Sectoral diversification percentile") +
  labs(x = "Instability", y = "Growth") +
  theme_bw(base_size = 13, base_family = font_family) +
  theme(
    panel.grid.major = element_line(linewidth = 0.35, colour = "grey80"),
    panel.grid.minor = element_line(linewidth = 0.25, colour = "grey90"),
    strip.text       = element_text(face = "bold"),
    legend.position  = "bottom"
  ) +
  coord_cartesian(clip = "off")

print(p_fix_x4_SPEC)

# Optional save:
# out_dir <- dirname(path)
fig_dir <- FIGURES

# ggsave(file.path(fig_dir, "HDF_frontier_x4-SPECIALIZATION_fixed_trimmed.png"),
#        p_fix_x4_SPEC, width = 9.6, height = 4.6, dpi = 320)




# ---------- Save all figures ----------
# Save next to the data file (same path as R_plot.dta)
out_dir <- dirname(path)

# (Optional) keep plots in a subfolder
fig_dir <- tempdir()
dir.create(fig_dir, showWarnings = FALSE, recursive = TRUE)

save_plot <- function(p, fname, width = 9.6, height = 4.6, dpi = 320) {
  ggsave(filename = file.path(fig_dir, fname), plot = p, width = width, height = height, dpi = dpi)
}

# p_two: the two-panel diversification plot with peak guides
save_plot(p_two, "HDF_frontier_two-panels_diversification.png")

# p_fix_x4_div: the 3-subfigure plot (DIV × DIV) with peak guides
save_plot(p_fix_x4_div, "HDF_frontier_DIVxDIV_peaks.png")

# p_fix_x4_SPEC: the 3-subfigure plot (SPEC × DIV)
save_plot(p_fix_x4_SPEC, "HDF_frontier_SPECxDIV.png")

