# 12_fig4_figS2_frontier_quantiles.R: Fig. 4 and Fig. S2, efficient frontiers by diversification quantile.
# Inputs:  $DERIVED/estimation_sample.dta, $ESTIMATES/ehdf_spec3_coefficients.csv
# Outputs: $FIGURES/fig04_frontier_by_diversification_quantile.png, figS2_frontier_div_by_div.png

source(here::here("code", "R", "setup.R"))

## Data and coefficients ------------------------------------------------------
D0 <- read_dta(file.path(DERIVED, "estimation_sample.dta")) %>% as_tibble()
stopifnot(all(c("sigma_reg_exp_norm", "div_emp_diff_s_norm", "div_fished_s_norm") %in% names(D0)))

pct_labels <- c("25th", "50th", "75th")
s_grid <- seq(0.85, 1.20, length.out = 200)

div_emp_named  <- setNames(as.numeric(quantile(D0$div_emp_diff_s_norm, c(.25, .50, .75), na.rm = TRUE)), pct_labels)
div_fish_named <- setNames(as.numeric(quantile(D0$div_fished_s_norm,   c(.25, .50, .75), na.rm = TRUE)), pct_labels)

cf <- read.csv(file.path(ESTIMATES, "ehdf_spec3_coefficients.csv"), stringsAsFactors = FALSE)
b  <- setNames(cf$estimate, cf$term)

alpha0 <- unname(b["_cons"])
alpha  <- unname(b[c("ln_x1_star", "ln_x2_star", "ln_x3_star", "ln_x4_star")])
Aalpha <- matrix(c(
  b["ln_x1sq"], b["ln_x1x2"], b["ln_x1x3"], b["ln_x1x4"],
  b["ln_x1x2"], b["ln_x2sq"], b["ln_x2x3"], b["ln_x2x4"],
  b["ln_x1x3"], b["ln_x2x3"], b["ln_x3sq"], b["ln_x3x4"],
  b["ln_x1x4"], b["ln_x2x4"], b["ln_x3x4"], b["ln_x4sq"]
), 4, 4, byrow = TRUE)
delta1  <- unname(b["ln_s1_star"])
delta11 <- unname(b["ln_s1sq"])
eta     <- unname(b[c("ln_x1s1", "ln_x2s1", "ln_x3s1", "ln_x4s1")])
stopifnot(!anyNA(c(alpha0, alpha, Aalpha, delta1, delta11, eta)))

## Frontier ---------------------------------------------------------------------
# Solves A L^2 + B L + C = 0 for L = ln(y1), given instability s and input levels x.
frontier_y <- function(s, x) {
  one <- rep(1, 4)
  Lx  <- log(x)
  Ls  <- log(s)

  A <- 0.5 * as.numeric(t(one) %*% Aalpha %*% one) + 0.5 * delta11 + sum(eta)
  B <- (1 + sum(alpha) + delta1 + as.numeric(t(one) %*% Aalpha %*% Lx) + sum(eta * Lx)) +
    (sum(eta) + delta11) * Ls
  C <- alpha0 + sum(alpha * Lx) + 0.5 * as.numeric(t(Lx) %*% Aalpha %*% Lx) +
    delta1 * Ls + 0.5 * delta11 * Ls^2 + Ls * sum(eta * Lx)

  D <- B^2 - 4 * A * C
  D[D < 0] <- NA_real_
  L1 <- (-B + sqrt(D)) / (2 * A)
  L2 <- (-B - sqrt(D)) / (2 * A)
  exp(ifelse(abs(L1) <= abs(L2), L1, L2))
}

# Model inputs are specialization levels, i.e. 1 / diversification.
frontier_curve <- function(x3_div, x4_div) {
  tibble(s = s_grid, growth = frontier_y(s_grid, c(1, 1, 1 / x3_div, 1 / x4_div)))
}

# Keep each curve up to its peak growth.
trim_at_peak <- function(df, ...) {
  peaks <- df %>%
    group_by(...) %>%
    slice_max(growth, n = 1, with_ties = FALSE) %>%
    ungroup() %>%
    select(..., s_peak = s)
  df %>%
    left_join(peaks, by = names(select(df, ...))) %>%
    filter(s <= s_peak)
}

palette3    <- c("25th" = "#E69F00", "50th" = "#009E73", "75th" = "#CC79A7")
font_family <- ifelse(Sys.info()[["sysname"]] == "Windows", "Times New Roman", "Times")

frontier_theme <- list(
  theme_bw(base_size = 13, base_family = font_family),
  theme(
    panel.grid.major = element_line(linewidth = 0.35, colour = "grey80"),
    panel.grid.minor = element_line(linewidth = 0.25, colour = "grey90"),
    strip.text       = element_text(face = "bold"),
    legend.position  = "bottom"
  ),
  coord_cartesian(clip = "off")
)

## Fig. 4: two panels, one margin varied with the other at its sample geometric mean (normalized level 1) ---------
fig4_data <- bind_rows(
  map_dfr(pct_labels, ~ frontier_curve(1, div_fish_named[.x]) %>%
            mutate(percentile = .x, facet = "(a) Fisheries diversification")),
  map_dfr(pct_labels, ~ frontier_curve(div_emp_named[.x], 1) %>%
            mutate(percentile = .x, facet = "(b) Sectoral diversification"))
) %>%
  drop_na(growth) %>%
  mutate(percentile = factor(percentile, levels = pct_labels)) %>%
  trim_at_peak(facet, percentile)

p_fig4 <- ggplot(fig4_data, aes(s, growth, color = percentile, group = percentile)) +
  geom_line(linewidth = 1.6) +
  facet_wrap(~ facet, nrow = 1) +
  scale_color_manual(values = palette3, name = "Diversification percentile") +
  labs(x = "Instability", y = "Growth") +
  frontier_theme

## Fig. S2: sectoral diversification varied within each fisheries percentile ---
figS2_data <- map_dfr(pct_labels, function(fish_lab) {
  map_dfr(pct_labels, ~ frontier_curve(div_emp_named[.x], div_fish_named[fish_lab]) %>%
            mutate(x3_div = .x, x4_fixed_div = fish_lab))
}) %>%
  drop_na(growth) %>%
  mutate(across(c(x3_div, x4_fixed_div), ~ factor(.x, levels = pct_labels))) %>%
  trim_at_peak(x4_fixed_div, x3_div)

p_figS2 <- ggplot(figS2_data, aes(s, growth, color = x3_div, group = x3_div)) +
  geom_line(linewidth = 1.6) +
  facet_wrap(~ x4_fixed_div, nrow = 1,
             labeller = labeller(x4_fixed_div = function(v) paste("Fisheries diversification fixed at", v))) +
  scale_color_manual(values = palette3, name = "Sectoral diversification percentile") +
  labs(x = "Instability", y = "Growth") +
  frontier_theme

ggsave(file.path(FIGURES, "fig04_frontier_by_diversification_quantile.png"), p_fig4, width = 8.6, height = 4.6, dpi = 320)
ggsave(file.path(FIGURES, "figS2_frontier_div_by_div.png"), p_figS2, width = 9.6, height = 4.6, dpi = 320)
