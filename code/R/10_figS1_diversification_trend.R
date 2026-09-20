#-------------------------------------------------------------------------------
# Filename:     10_figS1_diversification_trend.R
# Purpose:      Fig. S.1: average fisheries and sectoral diversification over 2000-2016.
# Inputs:       $DERIVED/diversity_fish_time_trend.dta, diversity_emp_shannon_time_trend.dta
# Outputs:      $FIGURES/figS1a_sectoral_diversification_trend.png, figS1b_fisheries_diversification_trend.png
# Requires:     config/paths.R (sourced below); see renv.lock for package versions
# Author:       Kim
#               Ported for the replication package 2026. Only paths, the source
#               of the coefficients, and the figure-saving calls were changed.
#-------------------------------------------------------------------------------


#### Diversification Trend for fisheries and Sectoral Diversification 

# Clear workspace
rm(list=ls())

source(file.path(Sys.getenv("REPLICATION_ROOT", unset = here::here()), "config", "paths.R"))
# Set working directory
# setwd() removed: paths come from config/paths.R
# Load necessary libraries
library(ggplot2)
library(dplyr)
library(tidyverse)
library(tibble)
library(dplyr)
library(haven)
library(raster)
library(ggmap)
library(sf)
library(usmap)
library(pacman)
library(GGally)
library(hrbrthemes)
library(gridExtra)
library(RColorBrewer)
library(viridis)
library(scales)
library(grid)
library(patchwork)

# ---- Load data ----
# Fisheries diversification panel (contains div_fished_s)
fish <- read_dta(file.path(DERIVED, "diversity_fish_time_trend.dta")) %>%
  zap_labels()   # haven::zap_labels() drops Stata value labels -> plain numeric columns

# Industrial (employment Shannon) diversification panel (contains div_emp_diff_s)
local <- read_dta(file.path(DERIVED, "diversity_emp_shannon_time_trend.dta")) %>%
  zap_labels()

# Stop early if a required variable is missing or misnamed in either file
stopifnot(
  all(c("year", "div_fished_s")   %in% names(fish)),
  all(c("year", "div_emp_diff_s") %in% names(local))
)

# ---- Yearly averages across communities ----
# Years where a variable is entirely NA give NaN from mean(); drop those years
fish_avg <- fish %>%
  group_by(year) %>%
  summarize(avg_div_fished_s = mean(div_fished_s, na.rm = TRUE)) %>%
  filter(!is.nan(avg_div_fished_s))

local_avg <- local %>%
  group_by(year) %>%
  summarize(avg_div_emp_diff_s = mean(div_emp_diff_s, na.rm = TRUE)) %>%
  filter(!is.nan(avg_div_emp_diff_s))
# Define pastel colors
pastel_line <- "#6A93C0"  # Soft blue
pastel_shade <- "#BFD7ED" # Light pastel blue
text_color <- "#4C566A"   # Muted gray-blue for text

# Get the common range of years from both datasets
year_range <- range(c(fish_avg$year, local_avg$year))

# Define breaks for consistent x-axis ticks (adjust as needed)
year_breaks <- seq(year_range[1], year_range[2], by = 2)  # Show every 2 years (adjust as needed)

# Create Fisheries Diversification Plot
fish_plot <- ggplot(fish_avg, aes(x = year, y = avg_div_fished_s)) +
  geom_smooth(method = "loess", span = 0.5, se = TRUE, color = pastel_line, fill = pastel_shade, size = 0.8, linetype = "dashed") +
  geom_point(size = 2.5, color = text_color, alpha = 0.8) +
  labs(x = "Year", y = "Fisheries Diversification") +
  scale_x_continuous(limits = year_range, breaks = year_breaks) +  # Set uniform x-axis
  theme_minimal() +
  theme(
    axis.title = element_text(face = "bold", size = 14, color = text_color),
    axis.text = element_text(face = "bold", size = 12, color = text_color),
    panel.grid.major = element_line(color = "#E5E9F0"),
    panel.grid.minor = element_blank(),
    panel.background = element_rect(fill = "white", color = NA),
    panel.border = element_rect(color = text_color, fill = NA, size = 0),
    axis.line = element_line(color = text_color, size = 0.3)
  )
fish_plot

# Save Fisheries Diversification Plot
ggsave(file.path(FIGURES, "figS1b_fisheries_diversification_trend.png"), plot = fish_plot, width = 7, height = 5, dpi = 300)

# Compute the average diversification across all cities per year
local_avg <- local %>%
  group_by(year) %>%
  summarize(avg_div_emp_diff_s = mean(div_emp_diff_s, na.rm = TRUE))

# Define pastel pink colors
pastel_line <- "#D17B88"  # Soft pastel pink
pastel_shade <- "#F4C6C9" # Light pastel pink
text_color <- "#7A4F57"   # Muted brownish-pink for text

# Adjust x-axis limits to start from 2001 for local data
local_year_range <- c(2001, year_range[2])  # Start from 2001 instead of 2000
local_year_breaks <- seq(local_year_range[1], local_year_range[2], by = 2)  # Adjust breaks accordingly

# Create Economic Diversification Plot with adjusted x-axis
local_plot <- ggplot(local_avg, aes(x = year, y = avg_div_emp_diff_s)) +
  geom_smooth(method = "loess", span = 0.5, se = TRUE, color = pastel_line, fill = pastel_shade, size = 0.8, linetype = "dashed") +
  geom_point(size = 2.5, color = text_color, alpha = 0.8) +
  labs(x = "Year", y = "Sectoral Diversification") +
  scale_x_continuous(limits = local_year_range, breaks = local_year_breaks) +  # Adjust x-axis to start from 2001
  theme_minimal() +
  theme(
    axis.title = element_text(face = "bold", size = 14, color = text_color),
    axis.text = element_text(face = "bold", size = 12, color = text_color),
    panel.grid.major = element_line(color = "#F0D8DA"),
    panel.grid.minor = element_blank(),
    panel.background = element_rect(fill = "white", color = NA),
    panel.border = element_rect(color = text_color, fill = NA, size = 0),
    axis.line = element_line(color = text_color, size = 0.3)
  )

local_plot


# Save Economic Diversification Plot
ggsave(file.path(FIGURES, "figS1a_sectoral_diversification_trend.png"), plot = local_plot, width = 7, height = 5, dpi = 300)

