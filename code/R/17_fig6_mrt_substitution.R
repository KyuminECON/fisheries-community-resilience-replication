# 17_fig6_mrt_substitution.R: Fig. 6, iso-MRT contours (a) and MRT estimates with 95% CIs at the 3x3 quantile grid (b).
# Inputs:  $ESTIMATES/MRT_emp_fish_5-95.dta, $ESTIMATES/MRT_emp_fish.dta
# Outputs: $FIGURES/fig06_mrt_substitution.png

source(here::here("code", "R", "setup.R"))
library(patchwork)
library(isoband)

# ---- Load data ----
DT <- read_dta(file.path(ESTIMATES, "MRT_emp_fish_5-95.dta"))
DT$q1 <- as.integer(sub("NMRT_([0-9]+)_([0-9]+)", "\\1", DT$parm))  # sectoral pctl
DT$q2 <- as.integer(sub("NMRT_([0-9]+)_([0-9]+)", "\\2", DT$parm))  # fisheries pctl

# Parameter names look like "NMRT_X3Q1_X4Q2": X3 = sectoral quantile, X4 = fisheries
# quantile, each Q1/Q2/Q3 = 25th/50th/75th percentile.
MRT <- read_dta(file.path(ESTIMATES, "MRT_emp_fish.dta")) %>%
  mutate(
    sect_pctl = case_when(
      grepl("X3Q1", parm) ~ 25, grepl("X3Q2", parm) ~ 50, grepl("X3Q3", parm) ~ 75
    ),
    fish_pctl = case_when(
      grepl("X4Q1", parm) ~ 25, grepl("X4Q2", parm) ~ 50, grepl("X4Q3", parm) ~ 75
    ),
    fish_lab = factor(fish_pctl, levels = c(25, 50, 75), labels = c("25th", "50th", "75th")),
    sect_lab = factor(sect_pctl, levels = c(25, 50, 75), labels = c("25th", "50th", "75th"))
  )
MRT <- MRT |> filter(!is.na(sect_pctl))  # Drop differences estimate

# Shared color palette (fisheries diversification) and shape palette (sectoral
# diversification), reused identically in both panels so the same 9 points are
# visually traceable across the figure without reading either axis.
pal <- c("25th" = "#2E5A87", "50th" = "#D98E04", "75th" = "#3B7D4F")
shp <- c("25th" = 21, "50th" = 22, "75th" = 24)  # circle, square, triangle

theme_pub <- theme_minimal(base_family = "serif", base_size = 12.5) +
  theme(panel.grid = element_blank(), axis.line = element_line(colour = "grey40"))

# ---- Panel (a): labeled iso-MRT contour ----

levels <- seq(0.2, 1.4, by = 0.2)
x_vals <- sort(unique(DT$q1))   # sectoral percentiles, 5..95
y_vals <- sort(unique(DT$q2))   # fisheries percentiles, 5..95

# Build the z-matrix for isoband::isolines() 
z_mat <- matrix(NA, nrow = length(y_vals), ncol = length(x_vals))
for (i in seq_along(x_vals)) {
  for (j in seq_along(y_vals)) {
    z_mat[j, i] <- DT$estimate[DT$q1 == x_vals[i] & DT$q2 == y_vals[j]]
  }
}

lines <- isolines(x_vals, y_vals, z_mat, levels = levels)

# Label placement: put each level's label at the point on its path with the
# largest x-coordinate (i.e., where the line exits toward the right/bottom
# edge of the plot), which keeps labels from overlapping the marker points.
label_df <- do.call(rbind, lapply(names(lines), function(lv) {
  ln <- lines[[lv]]
  idx <- which.max(ln$x)
  data.frame(level = as.numeric(lv), x = ln$x[idx], y = ln$y[idx])
}))

iso_df <- do.call(rbind, lapply(names(lines), function(lv) {
  ln <- lines[[lv]]
  data.frame(level = as.numeric(lv), x = ln$x, y = ln$y, id = ln$id)
}))

# Plot
p_contour <- ggplot() +
  geom_path(
    data = iso_df, aes(x = x, y = y, group = interaction(level, id)),
    color = "grey55", linewidth = 0.55
  ) +
  geom_text(
    data = label_df, aes(x = x, y = y, label = level),
    size = 3, color = "grey35", hjust = -0.2, family = "serif"
  ) +
  # Overlay the same 9 quantile-grid points shown in panel (b)
  geom_point(
    data = MRT, aes(x = sect_pctl, y = fish_pctl, fill = fish_lab, shape = sect_lab),
    color = "white", size = 2.6, stroke = 0.3, alpha = 0.95
  ) +
  scale_fill_manual(
    values = pal, name = "Fisheries Div.\n(Percentile)",
    guide = guide_legend(override.aes = list(shape = 21), order = 2)
  ) +
  scale_shape_manual(values = shp, name = "Sectoral Div.\n(Percentile)",
                     guide = guide_legend(order = 1)) +
  coord_equal(xlim = c(5, 108), ylim = c(5, 95), clip = "off") +
  scale_x_continuous(breaks = c(25, 50, 75)) +
  scale_y_continuous(breaks = c(25, 50, 75)) +
  labs(x = "Sectoral Diversification (Percentile)", y = "Fisheries Diversification (Percentile)") +
  theme_pub +
  theme(legend.position = "none")  # legend is shown once, from panel (b), below

# ---- Panel (b): quantile point-range plot ----

pd <- position_dodge(width = 0.6)

p_points <- MRT %>%
  ggplot(aes(x = factor(sect_pctl, labels = c("25th", "50th", "75th")),
             fill = fish_lab, shape = sect_lab)) +
  geom_errorbar(aes(ymin = min95, ymax = max95), width = 0.15, position = pd) +
  geom_point(aes(y = estimate), color = "black", size = 3, position = pd, stroke = 0.4) +
  scale_fill_manual(
    values = pal, name = "Fisheries Div.\n(Percentile)",
    guide = guide_legend(override.aes = list(shape = 21), order = 2)
  ) +
  scale_shape_manual(values = shp, name = "Sectoral Div.\n(Percentile)",
                     guide = guide_legend(order = 1)) +
  labs(x = "Sectoral Diversification (Percentile)", y = "MRT (estimate)") +
  theme_pub +
  theme(legend.position = "right")


# ---- Combine and export ----

fig_combined <- p_contour + p_points +
  plot_annotation(
    tag_levels = "a",
    theme = theme(plot.tag = element_text(family = "serif", face = "bold", size = 13))
  )

print(fig_combined)

ggsave(
  file.path(FIGURES, "fig06_mrt_substitution.png"),
  fig_combined,
  width = 11.2, height = 4.6, dpi = 300
)
