#-------------------------------------------------------------------------------
# Filename:     11_fig3_frontier_concept.R
# Purpose:      Fig. 3a conceptual EHDF surface and Fig. 3b growth-instability frontier.
# Inputs:       none (synthetic illustration) plus $DERIVED/R_plot.dta for the ggplot variant
# Outputs:      $FIGURES/fig03a_concept_surface.png, fig03b_growth_instability_frontier.png
# Requires:     config/paths.R (sourced below); see renv.lock for package versions
# Author:       Kim
#               Ported for the replication package 2026. Only paths, the source
#               of the coefficients, and the figure-saving calls were changed.
#-------------------------------------------------------------------------------


source(file.path(Sys.getenv("REPLICATION_ROOT", unset = here::here()), "config", "paths.R"))

# ========== Growth-Instability HDF surface + Frontier Proof of Concept Figure generation ========= #
# ========== Author: Kyumin Kim =================================================================== #



# 저장할 파일 경로 설정 (파일명도 포함)
output_file <- file.path(tempdir(), "PPF_draft.png")

# PNG 장치를 열기 (장치를 열기 전에 모든 그래픽 명령어가 출력됩니다)
png(filename = output_file, width = 1000, height = 800, res = 150, bg = "white")
par(mar = c(2, 2, 2, 2))  # 여백 조정 (필요에 따라 값을 수정하세요)

############################################################
# 패키지 로드 및 필요한 함수 정의
############################################################
library(plot3D)

parula.colors <- function(n) {
  colorRampPalette(c("#352A87", "#0F5CDD", "#00A9E7", "#00D9C0", "#A7F70A"))(n)
}

cd_utility <- function(x, y, alpha = 0.5) {
  x^alpha * y^(1 - alpha)
}

############################################################
# 데이터 생성 및 도표 그리기
############################################################
x_seq <- seq(0.1, 6, length.out = 50)
y_seq <- seq(0.1, 6, length.out = 50)
grid  <- expand.grid(x = x_seq, y = y_seq)
z_vals <- with(grid, cd_utility(x, y, alpha = 0.5))
Z <- matrix(z_vals, nrow = length(x_seq), ncol = length(y_seq))

persp3D_obj <- persp3D(
  x = x_seq, 
  y = y_seq, 
  z = Z,
  colvar = Z,
  col = parula.colors(100),
  alpha = 0.5,
  theta = 40, 
  phi = 30,
  expand = 0.6,
  xlab = "Fisheries Specialization",
  ylab = "Sectoral Specialization",
  zlab = "Growth (and Instability)",
  ticktype = "simple",
  contour = list(nlevels = 5, col = "gray", lwd = 1),
  colkey = FALSE
)

persp3D_obj

############################################################
# 빨간 점 (표면 위)
############################################################
x_red <- c(2, 4, 5)
y_red <- c(3, 2, 5)
z_red <- cd_utility(x_red, y_red, alpha = 0.5)
points3D(x_red, y_red, z_red, add = TRUE, pch = 19, col = "red", cex = 1)

# 빨간 점 중 첫 번째 점에 대해, 높은 z 좌표 (예: 7)로 라벨 연결
label_x_A <- x_red[1] + 0.5
label_y_A <- y_red[1] + 0.5
label_z_A <- 7
lines3D(
  x = c(x_red[1], label_x_A),
  y = c(y_red[1], label_y_A),
  z = c(z_red[1], label_z_A),
  add = TRUE, col = "red", lwd = 1, lty = 2
)
text3D(
  x = label_x_A, y = label_y_A, z = label_z_A,
  labels = "Community A", add = TRUE, col = "red", cex = 1
)

############################################################
# 검은 점 (표면 아래, 내부)
############################################################
set.seed(123)
n_black <- 15
x_black <- runif(n_black, min = 0.1, max = 6)
y_black <- runif(n_black, min = 0.1, max = 6)
z_surface_black <- cd_utility(x_black, y_black, alpha = 0.5)
factors <- runif(n_black, min = 0.6, max = 0.9)
z_black <- factors * z_surface_black
points3D(x_black, y_black, z_black, add = TRUE, pch = 19, col = "black", cex = 1)

# 검은 점 중 첫 번째 점에 대해, 높은 z 좌표 (예: 7)로 라벨 연결
label_x_B <- x_black[1] - 0.5
label_y_B <- y_black[1] - 0.5
label_z_B <- 7
lines3D(
  x = c(x_black[1], label_x_B),
  y = c(y_black[1], label_y_B),
  z = c(z_black[1], label_z_B),
  add = TRUE, col = "black", lwd = 1, lty = 2
)
text3D(
  x = label_x_B, y = label_y_B, z = label_z_B,
  labels = "Community B", add = TRUE, col = "black", cex = 1
)

# 그래픽 장치를 닫아 파일 저장 완료
dev.off()





#####

############################################################
# EXTRA FIGURE: Cobb–Douglas with inverse inputs (1/x, 1/y)
# (Plotting range: 0.1 to 1.25)
############################################################

# 저장할 파일 경로 (역입력 버전)
output_file_inv <- file.path(FIGURES, "fig03a_concept_surface.png")

# 역입력 유틸리티 함수 정의
cd_utility_inverse <- function(x, y, alpha = 0.5) {
  (1 / x)^alpha * (1 / y)^(1 - alpha)
  # 또는: cd_utility(1/x, 1/y, alpha)
}

# PNG 장치 열기
png(filename = output_file_inv, width = 1000, height = 800, res = 150, bg = "white")
par(mar = c(2, 2, 2, 2))

# 그리드: 0으로 나눗셈 회피 위해 0.1부터 시작, 상한 1.25
x_seq <- seq(0.1, 1.25, length.out = 50)
y_seq <- seq(0.1, 1.25, length.out = 50)
grid_inv  <- expand.grid(x = x_seq, y = y_seq)
z_vals_inv <- with(grid_inv, cd_utility_inverse(x, y, alpha = 0.5))
Z_inv <- matrix(z_vals_inv, nrow = length(x_seq), ncol = length(y_seq))

# 표면 그리기
persp3D(
  x = x_seq, 
  y = y_seq, 
  z = Z_inv,
  colvar = Z_inv,
  col = parula.colors(100),
  alpha = 0.5,
  theta = 40, 
  phi = 30,
  expand = 0.6,
  xlab = "Fisheries Diversification",
  ylab = "Sectoral Diversification",
  zlab = "Economic Growth (Instability)",
  ticktype = "simple",
  contour = list(nlevels = 5, col = "gray", lwd = 1),
  colkey = FALSE
)

# 빨간 점 (표면 위; 범위 [0.1, 1.25] 내)
x_red <- c(0.6, 0.9, 1.2)
y_red <- c(1.0, 0.7, 1.2)
z_red_inv <- cd_utility_inverse(x_red, y_red, alpha = 0.5)
points3D(x_red, y_red, z_red_inv, add = TRUE, pch = 19, col = "red", cex = 1)

# 빨간 점 라벨 (z축 상단 표시용)
label_x_A <- min(x_red[1] + 0.08, 1.25)
label_y_A <- min(y_red[1] + 0.08, 1.25)
label_z_A <- max(Z_inv) * 1.15
lines3D(
  x = c(x_red[1], label_x_A),
  y = c(y_red[1], label_y_A),
  z = c(z_red_inv[1], label_z_A),
  add = TRUE, col = "red", lwd = 1, lty = 2
)
text3D(
  x = label_x_A, y = label_y_A, z = label_z_A,
  labels = "Community A", add = TRUE, col = "red", cex = 1
)

# 검은 점 (표면 아래; 무작위 샘플도 [0.1, 1.25]에서)
set.seed(123)
n_black <- 15
x_black <- runif(n_black, min = 0.1, max = 1.25)
y_black <- runif(n_black, min = 0.1, max = 1.25)
z_surface_black_inv <- cd_utility_inverse(x_black, y_black, alpha = 0.5)
factors <- runif(n_black, min = 0.6, max = 0.9)
z_black_inv <- factors * z_surface_black_inv
points3D(x_black, y_black, z_black_inv, add = TRUE, pch = 19, col = "black", cex = 1)

# 검은 점 라벨
label_x_B <- max(x_black[1] - 0.08, 0.1)
label_y_B <- max(y_black[1] - 0.08, 0.1)
label_z_B <- max(Z_inv) * 1.15
lines3D(
  x = c(x_black[1], label_x_B),
  y = c(y_black[1], label_y_B),
  z = c(z_black_inv[1], label_z_B),
  add = TRUE, col = "black", lwd = 1, lty = 2
)
text3D(
  x = label_x_B, y = label_y_B, z = label_z_B,
  labels = "Community B", add = TRUE, col = "black", cex = 1
)

# 저장 완료
dev.off()




##############



############################################################
# PPF-like 3D Frontier: Growth vs. Instability by Diversification
# y = kappa * Diversification^alpha * Instability^(-beta)
############################################################
############################################################
# 3D Frontier with Linked Outputs:
# Diversification (x) → Growth z = kappa * x^(-alpha)
# Instability y = c_ratio * z
# We plot a thin ribbon surface around y = c_ratio * z and the exact frontier curve.
############################################################

# ---- File path ----
output_file <- file.path(tempdir(), "PPF_linked_draft.png")
dir.create(dirname(output_file), recursive = TRUE, showWarnings = FALSE)

# ---- Packages & palette ----
library(plot3D)
parula.colors <- function(n) {
  colorRampPalette(c("#352A87", "#0F5CDD", "#00A9E7", "#00D9C0", "#A7F70A"))(n)
}

# ---- Model settings ----
alpha    <- 0.60     # growth declines with diversification (steeper if larger)
kappa    <- 1.00     # scale for growth
c_ratio  <- 0.30     # instability = c_ratio * growth
x_min    <- 1.0; x_max <- 8.0
nx       <- 160      # resolution along diversification
nband    <- 9        # thickness band across y around the relation (visual ribbon)

growth_fun      <- function(x) kappa * x^(-alpha)
instability_fun <- function(x) c_ratio * growth_fun(x)

# ---- Build ribbon surface (X, Y, Z matrices) ----
x_seq <- seq(x_min, x_max, length.out = nx)
z_vec <- growth_fun(x_seq)          # growth along the frontier
y_vec <- instability_fun(x_seq)     # instability along the frontier

# make a thin band around y = c_ratio * z, purely for visualization
# band size is a small fraction of the median y
band_size <- 0.05 * median(y_vec)   # 5% band
s_seq <- seq(-band_size, band_size, length.out = nband)

# Matrices (nx x nband)
Xmat <- matrix(rep(x_seq, times = nband), nrow = nx, ncol = nband)
Zmat <- matrix(rep(z_vec, times = nband), nrow = nx, ncol = nband)
Ymat <- matrix(rep(y_vec, times = nband), nrow = nx, ncol = nband) +
  matrix(rep(s_seq, each = nx), nrow = nx, ncol = nband)

# ---- Draw ----
png(filename = output_file, width = 1200, height = 900, res = 150, bg = "white")
on.exit(dev.off(), add = TRUE)
par(mar = c(2.5, 2.5, 2.5, 2.5))

# Use surf3D because we have X/Y/Z matrices (a parametric surface/ribbon)
surf3D(
  x = Xmat, y = Ymat, z = Zmat,
  colvar = Zmat,
  col = parula.colors(140),
  alpha = 0.9,
  theta = 36, phi = 26, expand = 0.75,
  xlab = "Diversification (effective sectors)",
  ylab = "Instability (bad output)",
  zlab = "Growth (good output)",
  border = "grey70",
  facets = TRUE,
  colkey = FALSE
)

# Overlay the exact frontier curve (y = c_ratio * z)
lines3D(x_seq, y_vec, z_vec, add = TRUE, col = "black", lwd = 2)

# Example communities
# Low diversification -> high growth & instability (near curve)
C_x <- 1.2
C_z <- growth_fun(C_x); C_y <- c_ratio * C_z
points3D(C_x, C_y, C_z, add = TRUE, pch = 19, col = "red", cex = 1.2)
lines3D(c(C_x, C_x + 0.35), c(C_y, C_y + 0.03), c(C_z, max(Zmat) * 1.05),
        add = TRUE, col = "red", lty = 2)
text3D(C_x + 0.35, C_y + 0.03, max(Zmat) * 1.05,
       labels = "Low div → high growth & instability",
       add = TRUE, col = "red", cex = 0.9)

# High diversification -> low growth & instability (near curve)
D_x <- 7.5
D_z <- growth_fun(D_x); D_y <- c_ratio * D_z
points3D(D_x, D_y, D_z, add = TRUE, pch = 19, col = "black", cex = 1.2)
lines3D(c(D_x, D_x - 0.45), c(D_y, max(D_y - 0.03, min(Ymat))), c(D_z, max(Zmat) * 1.05),
        add = TRUE, col = "black", lty = 2)
text3D(D_x - 0.45, max(D_y - 0.03, min(Ymat)), max(Zmat) * 1.05,
       labels = "High div → low growth & instability",
       add = TRUE, col = "black", cex = 0.9)

# Done
cat("Saved:", output_file, " | Exists? ", file.exists(output_file), "\n")


####
###
###

suppressPackageStartupMessages({
  library(ggplot2)
  library(dplyr)
})

set.seed(42)

# --- Base parameters (illustrative only) ---
sigma_min <- 0.08
mu_min    <- 0.100
k_base    <- 0.60
k_mult    <- 0.4
k         <- k_mult * k_base

# ----- Cap instability at 15% -----
s_max  <- 0.15
s_grid <- seq(sigma_min, s_max, length.out = 400)

# Curve: μ(s) = μ_min ± k * sqrt(s^2 − sigma_min^2), for s >= sigma_min
mu_upper <- function(s, k) mu_min + k * sqrt(pmax(s^2 - sigma_min^2, 0))
mu_lower <- function(s, k) mu_min - k * sqrt(pmax(s^2 - sigma_min^2, 0))

df_curve <- tibble(
  instability  = s_grid,
  growth_upper = mu_upper(s_grid, k),
  growth_lower = mu_lower(s_grid, k)
)

# ---- Label & markers ----
# Minimum-instability point (marker only; text label removed)
df_min <- tibble(instability = sigma_min, growth = mu_min)

# Two points ON the green curve (FILLED RED)
s_on <- c(0.10, 0.13)
df_on <- tibble(
  instability = s_on,
  growth      = mu_upper(s_on, k)
)

# Three points INSIDE the curve (FILLED BLACK)
s_in <- c(0.090, 0.105, 0.120)
lower_in <- mu_lower(s_in, k)
upper_in <- mu_upper(s_in, k)
frac     <- c(0.55, 0.65, 0.40)
df_in <- tibble(
  instability = s_in,
  growth      = lower_in + frac * (upper_in - lower_in)
) %>% filter(growth >= mu_min)

# Closest interior dot to the curve (target of the hyperbolic path)
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

# Hyperbolic path: mix interior portfolio P with frontier portfolio F, w in [0, 1]
#   mu(w)      = (1 - w) mu_P + w mu_F
#   sigma^2(w) = (1 - w)^2 s_P^2 + w^2 s_F^2 + 2 w (1 - w) cov_PF
# cov_PF = sigma_min^2 + (mu_P - mu_min)(mu_F - mu_min) / k^2 (Markowitz result),
# so the path stays inside the frontier and meets it tangentially at F.
s_p  <- df_in$instability[i_min];  mu_p <- df_in$growth[i_min]
s_f  <- s_fine[nearest_idx[i_min]]; mu_f <- g_fine[nearest_idx[i_min]]
w      <- seq(0, 1, length.out = 300)
cov_pf <- sigma_min^2 + (mu_p - mu_min) * (mu_f - mu_min) / k^2
df_path <- tibble(
  instability = sqrt((1 - w)^2 * s_p^2 + w^2 * s_f^2 + 2 * w * (1 - w) * cov_pf),
  growth      = (1 - w) * mu_p + w * mu_f
)

p <- ggplot() +
  # Lower branch — dotted grey
  geom_line(data = df_curve, aes(instability, growth_lower),
            linewidth = 0.9, color = "grey65", linetype = "dotted") +
  # Upper branch — green
  geom_line(data = df_curve, aes(instability, growth_upper),
            linewidth = 1.2, color = "#2ca02c") +
  # Vertex marker (no label)
  geom_point(data = df_min, aes(instability, growth),
             shape = 8, size = 3.8, color = "#2ca02c", stroke = 1.0) +
  # Frontier dots (red) & interior dots (black)
  geom_point(data = df_on, aes(instability, growth), shape = 16, size = 3.2, color = "red") +
  geom_point(data = df_in, aes(instability, growth), shape = 16, size = 3.2, color = "black") +
  # Hyperbolic dashed path; geom_path keeps row order (geom_line would re-sort by x)
  geom_path(data = df_path, aes(instability, growth),
            linewidth = 0.9, color = "black", linetype = "dashed") +
  scale_x_continuous("Instability",
                     limits = c(0.07, s_max * 0.9),
                     breaks = NULL, labels = NULL,
                     expand = expansion(mult = c(0.01, 0.02))) +
  scale_y_continuous("Average Growth",
                     limits = c(0.09, 0.125),
                     breaks = NULL, labels = NULL,
                     expand = expansion(mult = c(0.02, 0.04))) +
  coord_cartesian(clip = "off") +
  theme_bw(base_size = 13) +
  theme(
    panel.grid.major = element_line(colour = "grey85", linewidth = 0.35),
    panel.grid.minor = element_line(colour = "grey92", linewidth = 0.25),
    panel.border     = element_rect(colour = "black", fill = NA, linewidth = 0.4),  # thinner border
    axis.text  = element_blank(),
    axis.ticks = element_blank(),
    axis.title.x = element_text(face = "bold"),
    axis.title.y = element_text(face = "bold"),
    legend.position = "none"
  )

print(p)

# Save (unchanged)
out_dir <- FIGURES
png_path <- file.path(out_dir, "fig03b_growth_instability_frontier.png")
pdf_path <- file.path(out_dir, "fig03b_growth_instability_frontier.pdf")
ggsave(filename = png_path, plot = p, width = 4, height = 3, dpi = 300, bg = "white")
ggsave(filename = pdf_path, plot = p, width = 4, height = 3, device = "pdf", bg = "white")
message("Saved to:\n", png_path, "\n", pdf_path)

