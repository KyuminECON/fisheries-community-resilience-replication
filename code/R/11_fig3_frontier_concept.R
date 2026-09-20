# 11_fig3_frontier_concept.R: Fig. 3, conceptual illustrations (synthetic; no estimated data).
# Inputs:  none
# Outputs: $FIGURES/fig03a_concept_surface.png, fig03b_growth_instability_frontier.png/.pdf

source(here::here("code", "R", "setup.R"))
library(plot3D)

## Fig. 3a: Cobb-Douglas surface in inverse inputs -----------------------------
parula_colors <- function(n) {
  colorRampPalette(c("#352A87", "#0F5CDD", "#00A9E7", "#00D9C0", "#A7F70A"))(n)
}

cd_utility_inverse <- function(x, y, alpha = 0.5) (1 / x)^alpha * (1 / y)^(1 - alpha)

x_seq <- seq(0.1, 1.25, length.out = 50)
y_seq <- seq(0.1, 1.25, length.out = 50)
grid_inv <- expand.grid(x = x_seq, y = y_seq)
Z_inv <- matrix(with(grid_inv, cd_utility_inverse(x, y)), nrow = length(x_seq), ncol = length(y_seq))

png(file.path(FIGURES, "fig03a_concept_surface.png"), width = 1000, height = 800, res = 150, bg = "white")
par(mar = c(2, 2, 2, 2))

persp3D(
  x = x_seq, y = y_seq, z = Z_inv, colvar = Z_inv,
  col = parula_colors(100), alpha = 0.5, theta = 40, phi = 30, expand = 0.6,
  xlab = "Fisheries Diversification", ylab = "Sectoral Diversification",
  zlab = "Economic Growth (Instability)", ticktype = "simple",
  contour = list(nlevels = 5, col = "gray", lwd = 1), colkey = FALSE
)

# Community A: on the surface
x_red <- c(0.6, 0.9, 1.2)
y_red <- c(1.0, 0.7, 1.2)
z_red <- cd_utility_inverse(x_red, y_red)
points3D(x_red, y_red, z_red, add = TRUE, pch = 19, col = "red", cex = 1)

label_z <- max(Z_inv) * 1.15
lines3D(x = c(x_red[1], x_red[1] + 0.08), y = c(y_red[1], y_red[1] + 0.08),
        z = c(z_red[1], label_z), add = TRUE, col = "red", lwd = 1, lty = 2)
text3D(x_red[1] + 0.08, y_red[1] + 0.08, label_z,
       labels = "Community A", add = TRUE, col = "red", cex = 1)

# Community B: below the surface
set.seed(123)
n_black <- 15
x_black <- runif(n_black, min = 0.1, max = 1.25)
y_black <- runif(n_black, min = 0.1, max = 1.25)
z_black <- runif(n_black, min = 0.6, max = 0.9) * cd_utility_inverse(x_black, y_black)
points3D(x_black, y_black, z_black, add = TRUE, pch = 19, col = "black", cex = 1)

lines3D(x = c(x_black[1], max(x_black[1] - 0.08, 0.1)), y = c(y_black[1], max(y_black[1] - 0.08, 0.1)),
        z = c(z_black[1], label_z), add = TRUE, col = "black", lwd = 1, lty = 2)
text3D(max(x_black[1] - 0.08, 0.1), max(y_black[1] - 0.08, 0.1), label_z,
       labels = "Community B", add = TRUE, col = "black", cex = 1)

invisible(dev.off())

## Fig. 3b: growth-instability frontier ---------------------------------------
sigma_min <- 0.08
mu_min    <- 0.100
k         <- 0.4 * 0.60
s_max     <- 0.15
s_grid    <- seq(sigma_min, s_max, length.out = 400)

mu_upper <- function(s, k) mu_min + k * sqrt(pmax(s^2 - sigma_min^2, 0))
mu_lower <- function(s, k) mu_min - k * sqrt(pmax(s^2 - sigma_min^2, 0))

df_curve <- tibble(
  instability  = s_grid,
  growth_upper = mu_upper(s_grid, k),
  growth_lower = mu_lower(s_grid, k)
)

df_min <- tibble(instability = sigma_min, growth = mu_min)

s_on <- c(0.10, 0.13)
df_on <- tibble(instability = s_on, growth = mu_upper(s_on, k))

s_in <- c(0.090, 0.105, 0.120)
frac <- c(0.55, 0.65, 0.40)
df_in <- tibble(
  instability = s_in,
  growth      = mu_lower(s_in, k) + frac * (mu_upper(s_in, k) - mu_lower(s_in, k))
) %>% filter(growth >= mu_min)

# Interior point closest to the frontier is the start of the hyperbolic path
s_fine <- seq(sigma_min, s_max, length.out = 2000)
g_fine <- mu_upper(s_fine, k)
nearest_idx <- sapply(seq_len(nrow(df_in)), function(i) {
  which.min((s_fine - df_in$instability[i])^2 + (g_fine - df_in$growth[i])^2)
})
dist2 <- sapply(seq_len(nrow(df_in)), function(i) {
  j <- nearest_idx[i]
  (s_fine[j] - df_in$instability[i])^2 + (g_fine[j] - df_in$growth[i])^2
})
i_min <- which.min(dist2)

# Path mixing interior portfolio P with frontier portfolio F, w in [0, 1]:
#   mu(w) = (1 - w) mu_P + w mu_F
#   sigma^2(w) = (1 - w)^2 s_P^2 + w^2 s_F^2 + 2 w (1 - w) cov_PF
#   cov_PF = sigma_min^2 + (mu_P - mu_min)(mu_F - mu_min) / k^2
s_p  <- df_in$instability[i_min];   mu_p <- df_in$growth[i_min]
s_f  <- s_fine[nearest_idx[i_min]]; mu_f <- g_fine[nearest_idx[i_min]]
w      <- seq(0, 1, length.out = 300)
cov_pf <- sigma_min^2 + (mu_p - mu_min) * (mu_f - mu_min) / k^2
df_path <- tibble(
  instability = sqrt((1 - w)^2 * s_p^2 + w^2 * s_f^2 + 2 * w * (1 - w) * cov_pf),
  growth      = (1 - w) * mu_p + w * mu_f
)

p <- ggplot() +
  geom_line(data = df_curve, aes(instability, growth_lower),
            linewidth = 0.9, color = "grey65", linetype = "dotted") +
  geom_line(data = df_curve, aes(instability, growth_upper),
            linewidth = 1.2, color = "#2ca02c") +
  geom_point(data = df_min, aes(instability, growth),
             shape = 8, size = 3.8, color = "#2ca02c", stroke = 1.0) +
  geom_point(data = df_on, aes(instability, growth), shape = 16, size = 3.2, color = "red") +
  geom_point(data = df_in, aes(instability, growth), shape = 16, size = 3.2, color = "black") +
  geom_path(data = df_path, aes(instability, growth),
            linewidth = 0.9, color = "black", linetype = "dashed") +
  scale_x_continuous("Instability", limits = c(0.07, s_max * 0.9),
                     breaks = NULL, labels = NULL, expand = expansion(mult = c(0.01, 0.02))) +
  scale_y_continuous("Average Growth", limits = c(0.09, 0.125),
                     breaks = NULL, labels = NULL, expand = expansion(mult = c(0.02, 0.04))) +
  coord_cartesian(clip = "off") +
  theme_bw(base_size = 13) +
  theme(
    panel.grid.major = element_line(colour = "grey85", linewidth = 0.35),
    panel.grid.minor = element_line(colour = "grey92", linewidth = 0.25),
    panel.border     = element_rect(colour = "black", fill = NA, linewidth = 0.4),
    axis.text  = element_blank(),
    axis.ticks = element_blank(),
    axis.title = element_text(face = "bold"),
    legend.position = "none"
  )

ggsave(file.path(FIGURES, "fig03b_growth_instability_frontier.png"), p, width = 4, height = 3, dpi = 300, bg = "white")
ggsave(file.path(FIGURES, "fig03b_growth_instability_frontier.pdf"), p, width = 4, height = 3, device = "pdf", bg = "white")
