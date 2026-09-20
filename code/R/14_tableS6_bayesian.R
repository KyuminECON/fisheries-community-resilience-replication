# 14_tableS6_bayesian.R: Table S6, Bayesian Mundlak-Chamberlain endogeneity check (JAGS).
# Inputs:  $DERIVED/processed_dataset.csv
# Outputs: $TABLES/tableS6_bayesian.tex; posterior summary printed to the log

source(here::here("code", "R", "setup.R"))
library(rjags)
library(coda)

set.seed(123)

## Data ---------------------------------------------------------------------
processed_data <- read.csv(file.path(DERIVED, "processed_dataset.csv"))
processed_data$city <- as.numeric(as.factor(processed_data$city))

# Community means of the inefficiency covariates (Mundlak-Chamberlain device)
time_averages <- processed_data %>%
  group_by(city) %>%
  summarize(
    avg_ln_x2 = mean(ln_x2, na.rm = TRUE),
    avg_ln_x3 = mean(ln_x3, na.rm = TRUE),
    avg_ln_x4 = mean(ln_x4, na.rm = TRUE)
  )

processed_data <- processed_data %>%
  left_join(time_averages, by = "city") %>%
  filter(!is.na(y1), !is.na(ln_x1), !is.na(ln_x2), !is.na(ln_x3), !is.na(ln_x4), !is.na(ln_s1),
         !is.na(avg_ln_x2), !is.na(avg_ln_x3), !is.na(avg_ln_x4))

stopifnot(nrow(time_averages) == length(unique(processed_data$city)))

processed_data$y1_std <- as.numeric(scale(processed_data$y1))

data_list <- list(
  N_obs = nrow(processed_data),
  I = length(unique(processed_data$city)),
  y1 = processed_data$y1_std,
  ln_x1 = processed_data$ln_x1,
  ln_x2 = processed_data$ln_x2,
  ln_x3 = processed_data$ln_x3,
  ln_x4 = processed_data$ln_x4,
  ln_s1 = processed_data$ln_s1,
  city = processed_data$city,
  avg_ln_x2 = time_averages$avg_ln_x2,
  avg_ln_x3 = time_averages$avg_ln_x3,
  avg_ln_x4 = time_averages$avg_ln_x4
)

## Model --------------------------------------------------------------------
model_string <- "
model {
  # Frontier parameters
  alpha ~ dnorm(0, 0.5)
  for (j in 1:5) {
    beta[j] ~ dnorm(0, 0.001)
  }

  # Variance parameters
  tau_v ~ dgamma(0.01, 0.01)
  tau_lambda ~ dgamma(0.01, 0.01)
  sigma_v <- 1 / sqrt(tau_v)
  sigma_lambda <- 1 / sqrt(tau_lambda)

  # Inefficiency term
  for (k in 1:4) {
    delta[k] ~ dnorm(0, 0.5)
  }
  for (i in 1:I) {
    ln_u[i] ~ dnorm(mu_u[i], tau_lambda)
    mu_u[i] <- delta[1] + delta[2] * avg_ln_x3[i] + delta[3] * avg_ln_x4[i] + delta[4] * avg_ln_x2[i]
    u[i] <- exp(ln_u[i])
  }

  # Cost frontier
  for (it in 1:N_obs) {
    mu_y[it] <- alpha + beta[1] * ln_x1[it] + beta[2] * ln_x2[it] +
                beta[3] * ln_x3[it] + beta[4] * ln_x4[it] +
                beta[5] * ln_s1[it] - u[city[it]]
    y1[it] ~ dnorm(mu_y[it], tau_v)
  }
}
"

inits <- function() {
  list(
    alpha = rnorm(1, 0, 1),
    beta = rnorm(5, 0, 10),
    delta = c(rnorm(1, 0, 1), rnorm(3, 0, 10)),
    tau_v = rgamma(1, 0.01, 0.01),
    tau_lambda = rgamma(1, 0.01, 0.01),
    ln_u = rnorm(data_list$I, 0, 1)
  )
}

## Estimation ---------------------------------------------------------------
jags_model <- jags.model(
  file = textConnection(model_string),
  data = data_list,
  inits = inits,
  n.chains = 3,
  n.adapt = 30000
)
update(jags_model, n.iter = 30000)

samples <- coda.samples(
  model = jags_model,
  variable.names = c("alpha", "beta", "delta", "sigma_v", "sigma_lambda"),
  n.iter = 800000,
  thin = 100
)

## Diagnostics and summary --------------------------------------------------
print(gelman.diag(samples, multivariate = FALSE))
print(effectiveSize(samples))
print(autocorr.diag(samples))

summary_stats <- summary(samples)
results_df <- data.frame(
  Parameter = rownames(summary_stats$statistics),
  Mean  = summary_stats$statistics[, "Mean"],
  SD    = summary_stats$statistics[, "SD"],
  Lower = summary_stats$quantiles[, "2.5%"],
  Upper = summary_stats$quantiles[, "97.5%"]
)
results_df$Significant <- ifelse(results_df$Lower > 0 | results_df$Upper < 0, "Yes", "No")

options(scipen = 999)
print(results_df)

## Table S6 ------------------------------------------------------------------
row <- function(label, par) {
  r <- results_df[results_df$Parameter == par, ]
  sprintf("%s & %.3f%s & %.3f \\\\", label, r$Mean,
          if (r$Significant == "Yes") "\\textsuperscript{**}" else "", r$SD)
}

table_s6 <- c(
  row("Const.", "alpha"),
  row("$\\ln x_1$ (Population)", "beta[1]"),
  row("$\\ln x_2$ (Wage Income per Capita)", "beta[2]"),
  row("$\\ln x_3$ (Ind. Specialization)", "beta[3]"),
  row("$\\ln x_4$ (Fish. Specialization)", "beta[4]"),
  row("$\\ln s_1$ (Instability)", "beta[5]"),
  "\\midrule",
  "\\multicolumn{3}{l}{\\textbf{Inefficiency}} \\\\",
  row("Const.", "delta[1]"),
  row("$\\overline{\\ln x_3}$", "delta[2]"),
  row("$\\overline{\\ln x_4}$", "delta[3]"),
  "\\midrule",
  sprintf("Sample Observations & %d &", nrow(processed_data))
)
writeLines(table_s6, file.path(TABLES, "tableS6_bayesian.tex"))
