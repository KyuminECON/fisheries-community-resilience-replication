#-------------------------------------------------------------------------------
# Filename:     16_fig5_mrt_marginal_panels.R
# Purpose:      Fig. 5: marginal effect of each diversification margin on the MRT, the other margin held at its median, across the 5th-95th percentile grid.
# Inputs:       $ESTIMATES/MRT_emp_fish_5-95.dta
# Outputs:      $FIGURES/fig05_mrt_marginal_panels.png
# Requires:     config/paths.R; see renv.lock. Needs the Stata stage to have run.
# Author:       Matthew N. Reimer, supplied 2026-09-18.
#               Ported for the replication package: ONLY the here() path calls and
#               the output filename were changed. The figure code is Matt's.
#-------------------------------------------------------------------------------
# Filename: figure-MRT-marginal-panels.R
# Purpose:  Marginal effect of each form of diversification on the MRT, holding the other margin fixed at its median.
# Input:    MRT_emp_fish_5-95.dta
#           A 19x19 grid of MRT estimates as sectoral diversification (q1) and fisheries diversification (q2) both vary.
# Output:   fig-MRT-marginal-panels.png
# Notes:    Column `parm` encodes the grid coordinates as "NMRT_<q1>_<q2>".

# PRELIMINARIES ----
rm(list=ls())

source(file.path(Sys.getenv("REPLICATION_ROOT", unset = here::here()), "config", "paths.R"))
## Set Path
# here::i_am() removed: the package root comes from config/paths.R
## Packages
pacman::p_load(here,data.table,tidyverse,patchwork,haven,isoband)

# ---- Load and reshape ----
DT <- read_dta(file.path(ESTIMATES, "MRT_emp_fish_5-95.dta"))

# `parm` looks like "NMRT_50_75" -> q1 = 50 (sectoral pctl), q2 = 75 (fisheries pctl).
# Regex captures the two numbers on either side of the middle underscore.
DT$q1 <- as.integer(sub("NMRT_([0-9]+)_([0-9]+)", "\\1", DT$parm))
DT$q2 <- as.integer(sub("NMRT_([0-9]+)_([0-9]+)", "\\2", DT$parm))

# ---- Shared y-axis range ----
# Both panels must share the same y-axis. 
yrange <- range(c(
  DT$min95[DT$q1 == 50 | DT$q2 == 50],
  DT$max95[DT$q1 == 50 | DT$q2 == 50]
))

# House theme: serif font 
theme_pub <- theme_minimal(base_family = "serif", base_size = 12.5) +
  theme(
    panel.grid  = element_blank(),
    axis.line   = element_line(colour = "grey40"),
    plot.title  = element_text(size = 11, face = "italic")
  )

# ---- Panel (a): own-effect of sectoral diversification ----
# Slice where fisheries diversification (q2) is held at its median (50th pctl);
# sectoral diversification (q1) varies across the full 5-95 range.
p_sect <- DT %>%
  filter(q2 == 50) %>%
  ggplot(aes(x = q1, y = estimate)) +
  geom_ribbon(aes(ymin = min95, ymax = max95), fill = "grey70", alpha = 0.35) +
  geom_line(linewidth = 1, color = "black") +
  labs(
    x = "Sectoral Diversification (Percentile)",
    y = "MRT",
    title = "Own-effect: sectoral diversification"
  ) +
  scale_x_continuous(limits = c(5, 95), n.breaks = 8, expand = expansion(mult = c(0, 0))) +
  scale_y_continuous(limits = yrange) +
  theme_pub

# ---- Panel (b): own-effect of fisheries diversification ----
# Mirror of panel (a): sectoral diversification (q1) held at its median,
# fisheries diversification (q2) varies.
p_fish <- DT %>%
  filter(q1 == 50) %>%
  ggplot(aes(x = q2, y = estimate)) +
  geom_ribbon(aes(ymin = min95, ymax = max95), fill = "grey70", alpha = 0.35) +
  geom_line(linewidth = 1, color = "black") +
  labs(
    x = "Fisheries Diversification (Percentile)",
    y = "MRT",
    title = "Own-effect: fisheries diversification"
  ) +
  scale_x_continuous(limits = c(5, 95), n.breaks = 8, expand = expansion(mult = c(0, 0))) +
  scale_y_continuous(limits = yrange) +
  theme_pub

# ---- Combine and export ----
fig_marginal <- p_sect + p_fish +
  plot_annotation(
    tag_levels = "a",
    theme = theme(plot.tag = element_text(family = "serif", face = "bold", size = 13))
  )

ggsave(
  file.path(FIGURES, "fig05_mrt_marginal_panels.png"),
  fig_marginal,
  width = 7, height = 4, dpi = 300
)
