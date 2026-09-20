# 15_fig1_ak_overview.R: Fig. 1, data overview. Maps and scatters of diversification, employment growth and instability.
#   a: map, colored by sectoral diversification, sized by fisheries diversification
#   b: scatter of sectoral vs. fisheries diversification, colored by growth, sized by instability
#   c: map, colored by employment growth, sized by instability
#   d: scatter of instability vs. growth, colored by sectoral diversification, sized by fisheries diversification
# Inputs:  $DERIVED/estimation_sample.dta
# Outputs: $FIGURES/fig01_ak_overview.png

source(here::here("code", "R", "setup.R"))
library(sf)
library(patchwork)
library(viridis)

# ---- Load data and geometry ----

dta <- read_dta(file.path(DERIVED, "estimation_sample.dta"))

data("states50", package = "rnaturalearthdata")
usa <- st_as_sf(states50)
usa <- usa[usa$admin == "United States of America", ]

dta_sf <- st_as_sf(dta, coords = c("longitude", "latitude"), crs = st_crs(usa))

label_sf <- data.frame(
  name = c("Bering Sea", "Gulf of Alaska"),
  x = c(-172, -145),
  y = c(58.5, 56)
) %>% st_as_sf(coords = c("x", "y"), crs = st_crs(usa))

# Quintile breakpoints for each variable used in fill/size legends below.
vars <- c("div_emp_diff_s", "div_fished_s", "mu_return", "sigma_reg_exp")
quintiles <- lapply(vars, function(v) {
  quantile(dta[[v]], probs = seq(0, 1, 0.2), na.rm = TRUE)
}) %>% setNames(vars)

# Theme
theme_pub <- theme_minimal(base_family = "serif", base_size = 12.5) +
  theme(
    panel.grid.major = element_blank(),
    panel.grid.minor = element_blank(),
    legend.title = element_text(size = 9.5),
    legend.text  = element_text(size = 8.5)
  )

# ---- Panel builders ----

make_map <- function(fill_var, size_var, fill_name, size_name,
                      fill_breaks, size_breaks, fill_round, size_round, palette) {
  ggplot() +
    geom_sf(data = usa, fill = NA, color = "black", linewidth = 0.3) +
    geom_sf(
      data = dta_sf, aes(fill = .data[[fill_var]], size = .data[[size_var]]),
      shape = 21, alpha = 0.85, color = "grey40"
    ) +
    geom_sf_text(
      data = label_sf, aes(label = name),
      size = 2.6, fontface = "italic", family = "serif"
    ) +
    coord_sf(xlim = c(-177.5, -131), ylim = c(52, 71)) +
    scale_fill_stepsn(
      name = fill_name, colours = palette, breaks = fill_breaks,
      limits = range(fill_breaks), labels = round(fill_breaks, fill_round),
      guide = guide_colorsteps(order = 1, ticks = TRUE, frame.colour = "black",
                                frame.linewidth = 0.5, barheight = unit(45, "pt"))
    ) +
    scale_size_continuous(name = size_name, breaks = size_breaks,
                           labels = round(size_breaks, size_round)) +
    labs(x = "Longitude", y = "Latitude") +
    theme_pub +
    theme(legend.position = "right", legend.direction = "vertical", legend.key.size = unit(0.3, "cm"))
}

make_scatter <- function(x_var, y_var, fill_var, size_var, x_name, y_name, fill_name, size_name,
                          fill_breaks, size_breaks, fill_round, size_round, palette) {
  ggplot(dta, aes(x = .data[[x_var]], y = .data[[y_var]],
                   fill = .data[[fill_var]], size = .data[[size_var]])) +
    geom_point(shape = 21, alpha = 0.85, color = "grey40") +
    labs(x = x_name, y = y_name) +
    scale_fill_stepsn(
      name = fill_name, colours = palette, breaks = fill_breaks,
      limits = range(fill_breaks), labels = round(fill_breaks, fill_round),
      guide = guide_colorsteps(order = 1, ticks = TRUE, frame.colour = "black",
                                frame.linewidth = 0.5, barheight = unit(45, "pt"))
    ) +
    scale_size_continuous(name = size_name, breaks = size_breaks,
                           labels = round(size_breaks, size_round)) +
    theme_pub +
    theme(legend.position = "right", legend.direction = "vertical", legend.key.size = unit(0.3, "cm"))
}

# ---- Build the four panels ----

p_map_div <- make_map(
  "div_emp_diff_s", "div_fished_s", "Sectoral\nDiversification", "Fisheries\nDiversification",
  quintiles$div_emp_diff_s, quintiles$div_fished_s, 1, 1, viridis::mako(5)
)

p_scatter_div <- make_scatter(
  "div_emp_diff_s", "div_fished_s", "mu_return", "sigma_reg_exp",
  "Sectoral Diversification", "Fisheries Diversification", "Employment\nGrowth", "Employment\nInstability",
  quintiles$mu_return, quintiles$sigma_reg_exp, 3, 2, viridis::inferno(5)
)

p_map_gi <- make_map(
  "mu_return", "sigma_reg_exp", "Employment\nGrowth", "Employment\nInstability",
  quintiles$mu_return, quintiles$sigma_reg_exp, 3, 2, viridis::inferno(5)
)

p_scatter_gi <- make_scatter(
  "sigma_reg_exp", "mu_return", "div_emp_diff_s", "div_fished_s",
  "Employment Instability", "Employment Growth", "Sectoral\nDiversification", "Fisheries\nDiversification",
  quintiles$div_emp_diff_s, quintiles$div_fished_s, 1, 1, viridis::mako(5)
)

# ---- Combine and export ----

# Row 1: diversification (map, scatter); row 2: growth and instability (map, scatter)

combined <- (p_map_div + p_scatter_div) / (p_map_gi + p_scatter_gi) +
  plot_annotation(
    tag_levels = "a",
    theme = theme(plot.tag = element_text(family = "serif", face = "bold", size = 14))
  )

ggsave(
  file.path(FIGURES, "fig01_ak_overview.png"),
  combined,
  width = 11, height = 8, dpi = 300
)
