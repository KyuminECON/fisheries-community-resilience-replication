#-------------------------------------------------------------------------------
# Filename:     14_tableS6_bayesian.R
# Purpose:      Table S6: Bayesian Mundlak-Chamberlain endogeneity check (JAGS).
# Inputs:       $DERIVED/processed_dataset.csv
# Outputs:      posterior summary printed to the log
# Requires:     config/paths.R (sourced below); see renv.lock for package versions
# Author:       Kim
#               Ported for the replication package 2026. Only paths, the source
#               of the coefficients, and the figure-saving calls were changed.
#-------------------------------------------------------------------------------


###### Bayesian Diagnostic for SFA Analysis: Including ln_x2 in the Inefficiency Term ######

rm(list=ls())

source(file.path(Sys.getenv("REPLICATION_ROOT", unset = here::here()), "config", "paths.R"))
# Load necessary libraries
library(dplyr)
library(rjags)
library(coda)

# Set seed for reproducibility
set.seed(123)

# Set working directory (adjust the path as needed)
# setwd() removed: paths come from config/paths.R
# Load the data
processed_data <- read.csv(file.path(DERIVED, "processed_dataset.csv"))

# Convert 'city' to a factor and then to numeric for JAGS indexing
processed_data$city <- as.numeric(as.factor(processed_data$city))

# Calculate time-averaged covariates for each firm, now including avg_ln_x2
time_averages <- processed_data %>%
  group_by(city) %>%
  summarize(
    avg_ln_x2 = mean(ln_x2, na.rm = TRUE),
    avg_ln_x3 = mean(ln_x3, na.rm = TRUE),
    avg_ln_x4 = mean(ln_x4, na.rm = TRUE)
  )

# Merge time averages back to the main dataset
processed_data <- processed_data %>%
  left_join(time_averages, by = "city")

# Remove any observations with missing values in any relevant variables
processed_data <- processed_data %>%
  filter(!is.na(y1) & !is.na(ln_x1) & !is.na(ln_x2) & !is.na(ln_x3) &
           !is.na(ln_x4) & !is.na(ln_s1) & 
           !is.na(avg_ln_x2) & !is.na(avg_ln_x3) & !is.na(avg_ln_x4))

# Verify data integrity
required_lengths <- c(
  length(processed_data$y1),
  length(processed_data$ln_x1),
  length(processed_data$ln_x2),
  length(processed_data$ln_x3),
  length(processed_data$ln_x4),
  length(processed_data$ln_s1),
  length(processed_data$city)
)

if (any(required_lengths != nrow(processed_data))) {
  stop("Mismatch in the length of one or more variables")
}

if (!(length(time_averages$avg_ln_x2) == length(unique(processed_data$city)))) {
  stop("Mismatch in the length of avg_ln_x2")
}
if (!(length(time_averages$avg_ln_x3) == length(unique(processed_data$city)))) {
  stop("Mismatch in the length of avg_ln_x3")
}
if (!(length(time_averages$avg_ln_x4) == length(unique(processed_data$city)))) {
  stop("Mismatch in the length of avg_ln_x4")
}

# Check for any remaining missing values
any_missing <- any(is.na(processed_data$y1) | is.na(processed_data$ln_x1) |
                     is.na(processed_data$ln_x2) | is.na(processed_data$ln_x3) |
                     is.na(processed_data$ln_x4) | is.na(processed_data$ln_s1) |
                     is.na(processed_data$avg_ln_x2) | is.na(processed_data$avg_ln_x3) |
                     is.na(processed_data$avg_ln_x4))
if (any_missing) {
  stop("There are still missing values in the data")
}

# (Optional) Check for multicollinearity
if(!require(car)) install.packages("car")
library(car)

# Standardize y1
processed_data$y1_std <- as.numeric(scale(processed_data$y1))

# Prepare the data list for JAGS
data_list <- list(
  N_obs = nrow(processed_data),            # Total number of observations
  I = length(unique(processed_data$city)), # Number of firms
  y1 = processed_data$y1_std,              # Use standardized y1
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

# JAGS model string with ln_x2 included in the inefficiency term
model_string <- "
model {
  # Priors for Frontier Parameters
  alpha ~ dnorm(0, 0.5)       # Weakly informative prior for convergence assurance.
  for (j in 1:5) {  # beta1 to beta5
    beta[j] ~ dnorm(0, 0.001) # Non-informative prior as used in literature
  }

  # Priors for Variance Parameters (Gamma)
  tau_v ~ dgamma(0.01, 0.01)      # Precision for idiosyncratic error v_it
  tau_lambda ~ dgamma(0.01, 0.01) # Precision for inefficiency error zeta_i

  # Derived Standard Deviations
  sigma_v <- 1 / sqrt(tau_v)
  sigma_lambda <- 1 / sqrt(tau_lambda)

  # Priors for Inefficiency Term Parameters
  for (k in 1:4) {  # delta1 to delta4
    delta[k] ~ dnorm(0, 0.5) # Weakly informative prior
  }

  # Inefficiency Term Specification
  for (i in 1:I) {
    # Model for log(u_i)
    ln_u[i] ~ dnorm(mu_u[i], tau_lambda)
    mu_u[i] <- delta[1] + delta[2] * avg_ln_x3[i] + delta[3] * avg_ln_x4[i] + delta[4] * avg_ln_x2[i]
    u[i] <- exp(ln_u[i])
  }

  # Production Frontier Equation
  for (it in 1:N_obs) {
    mu_y[it] <- alpha + beta[1] * ln_x1[it] + beta[2] * ln_x2[it] + 
                beta[3] * ln_x3[it] + beta[4] * ln_x4[it] + 
                beta[5] * ln_s1[it] - u[city[it]] 
    y1[it] ~ dnorm(mu_y[it], tau_v)
  }
}
"
##############  u>0 and +u for cost frontier of the sign ############


# Function to generate initial values
inits <- function() {
  list(
    alpha = rnorm(1, 0, 1),
    beta = rnorm(5, 0, 10),
    delta = c(rnorm(1, 0, 1), rnorm(3, 0, 10)), # delta[1:4]
    tau_v = rgamma(1, 0.01, 0.01),
    tau_lambda = rgamma(1, 0.01, 0.01),
    ln_u = rnorm(data_list$I, 0, 1)
  )
}

# Parameters to monitor
params <- c("alpha", "beta", "delta", "sigma_v", "sigma_lambda")

# Load the model
jags_model <- jags.model(
  file = textConnection(model_string),
  data = data_list,
  inits = inits,
  n.chains = 3,        # Adjusted to 3 chains
  n.adapt = 30000      # Adaptation phase
)

# Burn-in period
update(jags_model, n.iter = 30000)  # Burn-in

# Sample from the posterior
samples <- coda.samples(
  model = jags_model,
  variable.names = params,
  n.iter = 800000,     # Increased iterations
  thin = 100           # Thinning interval
)

# Diagnostics and Summary

# Gelman-Rubin Diagnostic
gelman_diag <- gelman.diag(samples, multivariate = FALSE)
print("Gelman-Rubin Diagnostic:")
print(gelman_diag)

# Effective Sample Size
eff_size <- effectiveSize(samples)
print("Effective Sample Size:")
print(eff_size)

# Autocorrelation Diagnostics
autocorr_diag <- autocorr.diag(samples)
print("Autocorrelation Diagnostics:")
print(autocorr_diag)

# Trace Plots
plot(samples)

# Summary Statistics
summary_stats <- summary(samples)

# Extract means and credible intervals
means <- summary_stats$statistics[, "Mean"]
sds <- summary_stats$statistics[, "SD"]
quantiles <- summary_stats$quantiles

# Check column names of quantiles
print("Quantiles column names:")
print(colnames(quantiles))

# Create a data frame with results using standard column names
results_df <- data.frame(
  Parameter = rownames(summary_stats$statistics),
  Mean = means,
  SD = sds,
  Lower = quantiles[, 1],  # Assuming 2.5% quantile is the first column
  Upper = quantiles[, 5]   # Assuming 97.5% quantile is the fifth column
)

# Determine significance
results_df$Significant <- ifelse(
  results_df$Lower > 0 | results_df$Upper < 0,
  "Yes",
  "No"
)

# Display the results without scientific notation
options(scipen = 999)
print("Posterior Summary with Significance:")
print(results_df)













############# Above is the results used. Keep the code above #########


###### Bayesian Diagnostic for SFA Analysis: Excluding avg_ln_x2 from the Inefficiency Term ######


# --------------------------------------------------------------------------
# TRIMMED 2026-09-18 for the replication package.
# The original continued with a second JAGS fit (same data, weakly informative
# prior on the inefficiency coefficients) that is not reported anywhere in the
# manuscript and doubled the runtime. Table S6 is complete above this line.
# --------------------------------------------------------------------------
