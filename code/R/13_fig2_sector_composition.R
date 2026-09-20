#-------------------------------------------------------------------------------
# Filename:     13_fig2_sector_composition.R
# Purpose:      Fig. 2: sectoral composition of high- versus low-fisheries-diversification communities.
# Inputs:       $RAW/employment-by-industry-community-and-year.csv and $DERIVED pieces
# Outputs:      $FIGURES/fig02_sector_composition.png
# Requires:     config/paths.R (sourced below); see renv.lock for package versions
# Author:       Kim
#               Ported for the replication package 2026. Only paths, the source
#               of the coefficients, and the figure-saving calls were changed.
#-------------------------------------------------------------------------------


# --- library calls gathered from the whole original file, because the
# --- Fig. 2 block below was preceded by them in an earlier section.
library(ggplot2)
library(dplyr)
library(tidyverse)
library(tibble)
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

rm(list=ls())
source(file.path(Sys.getenv("REPLICATION_ROOT", unset = here::here()), "config", "paths.R"))
# setwd() removed: paths come from config/paths.R
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

# Read the datasets
df1 <- read_dta(file.path(DERIVED, "marginal_effect_HDF.dta"))
df2 <- read_dta(file.path(DERIVED, "marginal_effect_EHDF.dta"))

# Merge the datasets by "city"
merged_df <- df1 %>%
  inner_join(df2, by = "city")

# Creating quantile variables for each input, and (bad) output variable.
df <- merged_df %>%
  mutate(
    x1 = avg_pop,
    x2 = avg_wage_pc,
    x3 =  div_emp_diff_s,
    x4 =  div_fished_s,
    s1 = sigma_reg_exp,
    x1_quant = ntile(x1, 4),
    x2_quant = ntile(x2, 4),
    x3_quant = ntile(x3, 4),
    x4_quant = ntile(x4, 4),
    s1_quant = ntile(s1, 4)
  )

# Calculate y-axis limits for each metric
y_limits_mp_x3_y1_3_e <- boxplot.stats(df$mp_x3_y1_3_e)$stats[c(1, 5)]
y_limits_mp_x4_y1_3_e <- boxplot.stats(df$mp_x4_y1_3_e)$stats[c(1, 5)]
y_limits_mp_x3_s1_3_e <- boxplot.stats(df$mp_x3_s1_3_e)$stats[c(1, 5)]
y_limits_mp_x4_s1_3_e <- boxplot.stats(df$mp_x4_s1_3_e)$stats[c(1, 5)]

# First row with titles and no x-axis labels, using pastel tones with transparency
plot1_sect_growth <- ggplot(df, aes(x = as.factor(x1_quant), y = mp_x3_y1_3_e)) +
  geom_boxplot(outlier.shape = NA, fill = alpha("skyblue", 0.5)) +
  scale_y_continuous(limits = y_limits_mp_x3_y1_3_e) +
  labs(y = NULL, x = NULL) +
  theme_minimal() +
  theme(
    axis.text.x = element_blank(),
    axis.text.y = element_text(face = "bold", size = 11),
    plot.title = element_text(hjust = 0.5, size = 14, face = "bold")
  ) +
  ggtitle("Population")

plot2_sect_growth <- ggplot(df, aes(x = as.factor(x2_quant), y = mp_x3_y1_3_e)) +
  geom_boxplot(outlier.shape = NA, fill = alpha("lightcoral", 0.5)) +
  scale_y_continuous(limits = y_limits_mp_x3_y1_3_e) +
  labs(y = NULL, x = NULL) + 
  theme_minimal() +
  theme(
    axis.text.x = element_blank(),
    axis.text.y = element_text(face = "bold", size = 11),
    plot.title = element_text(hjust = 0.5, size = 14, face = "bold")
  ) +
  ggtitle("Wage Income per Capita")

plot3_sect_growth <- ggplot(df, aes(x = as.factor(x3_quant), y = mp_x3_y1_3_e)) +
  geom_boxplot(outlier.shape = NA, fill = alpha("lightgreen", 0.5)) +
  scale_y_continuous(limits = y_limits_mp_x3_y1_3_e) +
  labs(y = NULL, x = NULL) + 
  theme_minimal() +
  theme(
    axis.text.x = element_blank(),
    axis.text.y = element_text(face = "bold", size = 11),
    plot.title = element_text(hjust = 0.5, size = 14, face = "bold")
  ) +
  ggtitle("Ind. Diversification")

plot4_sect_growth <- ggplot(df, aes(x = as.factor(x4_quant), y = mp_x3_y1_3_e)) +
  geom_boxplot(outlier.shape = NA, fill = alpha("plum", 0.5)) +
  scale_y_continuous(limits = y_limits_mp_x3_y1_3_e) +
  labs(y = NULL, x = NULL) + 
  theme_minimal() +
  theme(
    axis.text.x = element_blank(),
    axis.text.y = element_text(face = "bold", size = 11),
    plot.title = element_text(hjust = 0.5, size = 14, face = "bold")
  ) +
  ggtitle("Fish. Diversification")

plot5_sect_growth <- ggplot(df, aes(x = as.factor(s1_quant), y = mp_x3_y1_3_e)) +
  geom_boxplot(outlier.shape = NA, fill = alpha("lightblue", 0.5)) +
  scale_y_continuous(limits = y_limits_mp_x3_y1_3_e) +
  labs(y = NULL, x = NULL) + 
  theme_minimal() +
  theme(
    axis.text.x = element_blank(),
    axis.text.y = element_text(face = "bold", size = 11),
    plot.title = element_text(hjust = 0.5, size = 14, face = "bold")
  ) +
  ggtitle("Instability")

# Arrange first row with column titles
plot_sect_growth <- grid.arrange(
  plot1_sect_growth, plot2_sect_growth, plot3_sect_growth, plot4_sect_growth, plot5_sect_growth,
  ncol = 5,
  left = textGrob(expression(MP[y * "," * x[3]]), rot = 90, gp = gpar(fontsize = 14, fontface = "bold"))
)

# Second row with no titles and no x-axis labels
plot1_fish_growth <- ggplot(df, aes(x = as.factor(x1_quant), y = mp_x4_y1_3_e)) +
  geom_boxplot(outlier.shape = NA, fill = alpha("skyblue", 0.5)) +
  scale_y_continuous(limits = y_limits_mp_x4_y1_3_e) +
  labs(y = NULL, x = NULL) +
  theme_minimal() +
  theme(axis.text.x = element_blank(), axis.text.y = element_text(face = "bold", size = 11))

plot2_fish_growth <- ggplot(df, aes(x = as.factor(x2_quant), y = mp_x4_y1_3_e)) +
  geom_boxplot(outlier.shape = NA, fill = alpha("lightcoral", 0.5)) +
  scale_y_continuous(limits = y_limits_mp_x4_y1_3_e) +
  labs(y = NULL, x = NULL) + 
  theme_minimal() +
  theme(axis.text.x = element_blank(), axis.text.y = element_text(face = "bold", size = 11))

plot3_fish_growth <- ggplot(df, aes(x = as.factor(x3_quant), y = mp_x4_y1_3_e)) +
  geom_boxplot(outlier.shape = NA, fill = alpha("lightgreen", 0.5)) +
  scale_y_continuous(limits = y_limits_mp_x4_y1_3_e) +
  labs(y = NULL, x = NULL) + 
  theme_minimal() +
  theme(axis.text.x = element_blank(), axis.text.y = element_text(face = "bold", size = 11))

plot4_fish_growth <- ggplot(df, aes(x = as.factor(x4_quant), y = mp_x4_y1_3_e)) +
  geom_boxplot(outlier.shape = NA, fill = alpha("plum", 0.5)) +
  scale_y_continuous(limits = y_limits_mp_x4_y1_3_e) +
  labs(y = NULL, x = NULL) + 
  theme_minimal() +
  theme(axis.text.x = element_blank(), axis.text.y = element_text(face = "bold", size = 11))

plot5_fish_growth <- ggplot(df, aes(x = as.factor(s1_quant), y = mp_x4_y1_3_e)) +
  geom_boxplot(outlier.shape = NA, fill = alpha("lightblue", 0.5)) +
  scale_y_continuous(limits = y_limits_mp_x4_y1_3_e) +
  labs(y = NULL, x = NULL) + 
  theme_minimal() +
  theme(axis.text.x = element_blank(), axis.text.y = element_text(face = "bold", size = 11))

plot_fish_growth <- grid.arrange(
  plot1_fish_growth, plot2_fish_growth, plot3_fish_growth, plot4_fish_growth, plot5_fish_growth,
  ncol = 5,
  left = textGrob(expression(MP[y * "," * x[4]]), rot = 90, gp = gpar(fontsize = 14, fontface = "bold"))
)

# Third row with no titles and no x-axis labels
plot1_sect_instab <- ggplot(df, aes(x = as.factor(x1_quant), y = mp_x3_s1_3_e)) +
  geom_boxplot(outlier.shape = NA, fill = alpha("skyblue", 0.5)) +
  scale_y_continuous(limits = y_limits_mp_x3_s1_3_e) +
  labs(y = NULL, x = NULL) +
  theme_minimal() +
  theme(axis.text.x = element_blank(), axis.text.y = element_text(face = "bold", size = 11))

plot2_sect_instab <- ggplot(df, aes(x = as.factor(x2_quant), y = mp_x3_s1_3_e)) +
  geom_boxplot(outlier.shape = NA, fill = alpha("lightcoral", 0.5)) +
  scale_y_continuous(limits = y_limits_mp_x3_s1_3_e) +
  labs(y = NULL, x = NULL) + 
  theme_minimal() +
  theme(axis.text.x = element_blank(), axis.text.y = element_text(face = "bold", size = 11))

plot3_sect_instab <- ggplot(df, aes(x = as.factor(x3_quant), y = mp_x3_s1_3_e)) +
  geom_boxplot(outlier.shape = NA, fill = alpha("lightgreen", 0.5)) +
  scale_y_continuous(limits = y_limits_mp_x3_s1_3_e) +
  labs(y = NULL, x = NULL) + 
  theme_minimal() +
  theme(axis.text.x = element_blank(), axis.text.y = element_text(face = "bold", size = 11))

plot4_sect_instab <- ggplot(df, aes(x = as.factor(x4_quant), y = mp_x3_s1_3_e)) +
  geom_boxplot(outlier.shape = NA, fill = alpha("plum", 0.5)) +
  scale_y_continuous(limits = y_limits_mp_x3_s1_3_e) +
  labs(y = NULL, x = NULL) + 
  theme_minimal() +
  theme(axis.text.x = element_blank(), axis.text.y = element_text(face = "bold", size = 11))

plot5_sect_instab <- ggplot(df, aes(x = as.factor(s1_quant), y = mp_x3_s1_3_e)) +
  geom_boxplot(outlier.shape = NA, fill = alpha("lightblue", 0.5)) +
  scale_y_continuous(limits = y_limits_mp_x3_s1_3_e) +
  labs(y = NULL, x = NULL) + 
  theme_minimal() +
  theme(axis.text.x = element_blank(), axis.text.y = element_text(face = "bold", size = 11))

plot_sect_instab <- grid.arrange(
  plot1_sect_instab, plot2_sect_instab, plot3_sect_instab, plot4_sect_instab, plot5_sect_instab,
  ncol = 5,
  left = textGrob(expression(MP[s * "," * x[3]]), rot = 90, gp = gpar(fontsize = 14, fontface = "bold"))
)

# Fourth row with x-axis labels (last row)
plot1_fish_instab <- ggplot(df, aes(x = as.factor(x1_quant), y = mp_x4_s1_3_e)) +
  geom_boxplot(outlier.shape = NA, fill = alpha("skyblue", 0.5)) +
  scale_y_continuous(limits = y_limits_mp_x4_s1_3_e) +
  scale_x_discrete(labels = c("0-25%", "25-50%", "50-75%", "75-100%")) +
  labs(y = NULL, x = NULL) +
  theme_minimal() +
  theme(axis.text = element_text(face = "bold", size = 11))

plot2_fish_instab <- ggplot(df, aes(x = as.factor(x2_quant), y = mp_x4_s1_3_e)) +
  geom_boxplot(outlier.shape = NA, fill = alpha("lightcoral", 0.5)) +
  scale_y_continuous(limits = y_limits_mp_x4_s1_3_e) +
  scale_x_discrete(labels = c("0-25%", "25-50%", "50-75%", "75-100%")) +
  labs(y = NULL, x = NULL) + 
  theme_minimal() +
  theme(axis.text = element_text(face = "bold", size = 11))

plot3_fish_instab <- ggplot(df, aes(x = as.factor(x3_quant), y = mp_x4_s1_3_e)) +
  geom_boxplot(outlier.shape = NA, fill = alpha("lightgreen", 0.5)) +
  scale_y_continuous(limits = y_limits_mp_x4_s1_3_e) +
  scale_x_discrete(labels = c("0-25%", "25-50%", "50-75%", "75-100%")) +
  labs(y = NULL, x = NULL) + 
  theme_minimal() +
  theme(axis.text = element_text(face = "bold", size = 11))

plot4_fish_instab <- ggplot(df, aes(x = as.factor(x4_quant), y = mp_x4_s1_3_e)) +
  geom_boxplot(outlier.shape = NA, fill = alpha("plum", 0.5)) +
  scale_y_continuous(limits = y_limits_mp_x4_s1_3_e) +
  scale_x_discrete(labels = c("0-25%", "25-50%", "50-75%", "75-100%")) +
  labs(y = NULL, x = NULL) + 
  theme_minimal() +
  theme(axis.text = element_text(face = "bold", size = 11))

plot5_fish_instab <- ggplot(df, aes(x = as.factor(s1_quant), y = mp_x4_s1_3_e)) +
  geom_boxplot(outlier.shape = NA, fill = alpha("lightblue", 0.5)) +
  scale_y_continuous(limits = y_limits_mp_x4_s1_3_e) +
  scale_x_discrete(labels = c("0-25%", "25-50%", "50-75%", "75-100%")) +
  labs(y = NULL, x = NULL) + 
  theme_minimal() +
  theme(axis.text = element_text(face = "bold", size = 11))

# Fourth row with modified subscript formatting
plot_fish_instab <- grid.arrange(
  plot1_fish_instab, plot2_fish_instab, plot3_fish_instab, plot4_fish_instab, plot5_fish_instab,
  ncol = 5,
  left = textGrob(expression(MP[s * "," * x[4]]), rot = 90, gp = gpar(fontsize = 14, fontface = "bold"))
)


# Arrange all rows into a final 4x5 grid and save as a PNG file
final_plot <- grid.arrange(
  plot_sect_growth,plot_sect_instab, plot_fish_growth,plot_fish_instab,
  ncol = 1
)

ggsave(file.path(tempdir(), "hetero_plot_pastel.png"), plot = final_plot, width = 16, height = 12, dpi = 300)




########## See highest fisheries diversification quantile 
high_fish_city<- df %>%
  dplyr::filter(x4_quant==4) %>%
  dplyr::select(city)

high_fish_city


###Let's load another data for local economy. : whole raw data
# Load the dataset
local_df <- read_csv(file.path(RAW, "employment-by-industry-community-and-year.csv"))

#Time Averaging. 
local_df_avg<- local_df %>%
  group_by(community__name, industry__name) %>%
  summarise(avg_employment = mean(emp, na.rm=TRUE))%>%
  ungroup()

local_df_avg_fisheries<- local_df_avg %>%
  filter(community__name %in% high_fish_city$city)

local_df_avg_fisheries


#Let's see the industry ratio for employment among those high-fisheries place. 

industry_totals <- local_df_avg_fisheries %>%
  group_by(industry__name) %>%
  summarise(total_avg_employment =sum(avg_employment, na.rm=TRUE))

# Calculate the overall totla employment across all industiries. 
total_employment <- sum(industry_totals$total_avg_employment)

# Calculate the ratio for each industry
industry_ratios <- industry_totals %>%
  mutate(employment_ratio = total_avg_employment/total_employment)

#Displace the result. 
industry_ratios


# Plot the industry employment ratios
ggplot(industry_ratios, aes(x = reorder(industry__name, employment_ratio), y = employment_ratio)) +
  geom_bar(stat = "identity", fill = "skyblue") +
  coord_flip() +  # Flip coordinates for easier reading of industry names
  scale_y_continuous(labels = scales::percent) +  # Format y-axis as percentages
  labs(
    title = "Industry Ratios in the Highest Fisheries-diversified Alaska Communities",
    x = "Industry",
    y = "Employment Ratio (%)"
  ) +
  theme_minimal() +
  theme(
    plot.title = element_text(hjust = 0.5, size = 16, face = "bold"),
    axis.text.y = element_text(size = 10)
  )

# 

# Filter top 5 industries by employment ratio for highest fisheries diversification
industry_ratios_top5 <- industry_ratios %>%
  arrange(desc(employment_ratio)) %>%
  slice_head(n = 5)




########## See lowest fisheries diversification quantile 
low_fish_city <- df %>%
  dplyr::filter(x4_quant == 1) %>%
  dplyr::select(city)

# Filter local_df_avg for communities in the lowest fisheries quantile
local_df_avg_low_fisheries <- local_df_avg %>%
  filter(community__name %in% low_fish_city$city)

# Calculate industry totals for the lowest fisheries-diversified communities
industry_totals_low <- local_df_avg_low_fisheries %>%
  group_by(industry__name) %>%
  summarise(total_avg_employment = sum(avg_employment, na.rm = TRUE))

# Calculate the overall total employment across all industries in lowest fisheries-diversified communities
total_employment_low <- sum(industry_totals_low$total_avg_employment)

# Calculate the employment ratio for each industry in lowest fisheries-diversified communities
industry_ratios_low <- industry_totals_low %>%
  mutate(employment_ratio = total_avg_employment / total_employment_low)

# Display the result
industry_ratios_low

# Plot the industry employment ratios for the lowest fisheries-diversified communities
ggplot(industry_ratios_low, aes(x = reorder(industry__name, employment_ratio), y = employment_ratio)) +
  geom_bar(stat = "identity", fill = "coral") +
  coord_flip() +  # Flip coordinates for easier reading of industry names
  scale_y_continuous(labels = scales::percent) +  # Format y-axis as percentages
  labs(
    title = "Industry Ratios in the Lowest Fisheries-diversified Alaska Communities",
    x = "Industry",
    y = "Employment Ratio (%)"
  ) +
  theme_minimal() +
  theme(
    plot.title = element_text(hjust = 0.5, size = 16, face = "bold"),
    axis.text.y = element_text(size = 10)
  )


# Filter top 5 industries by employment ratio for lowest fisheries diversification
industry_ratios_low_top5 <- industry_ratios_low %>%
  arrange(desc(employment_ratio)) %>%
  slice_head(n = 5)

# Define a consistent color palette for industries
industry_colors <- setNames(
  c("#66c2a5", "#fc8d62", "#8da0cb", "#e78ac3", "#a6d854", "#ffd92f", "#e5c494", "#b3b3b3"),
  unique(c(industry_ratios_top5$industry__name, industry_ratios_low_top5$industry__name))
)

# Determine the maximum y-axis value across both datasets
max_y <- max(c(industry_ratios_top5$employment_ratio, industry_ratios_low_top5$employment_ratio))

# Plot for top 5 industries in highest fisheries-diversified communities
plot_top5_high <- ggplot(industry_ratios_top5, aes(
  y = employment_ratio,
  x = reorder(industry__name, -employment_ratio),
  fill = industry__name
)) +
  geom_bar(stat = "identity", color = "black") +  # Black outline for bars
  scale_y_continuous(labels = scales::percent, limits = c(0, max_y)) +  
  scale_fill_manual(values = industry_colors, name = NULL) +  # Remove legend title
  labs(
    title = "High fisheries-diversified communities",
    x = NULL,
    y = expression(bold("Employment Share (%)"))
  ) +
  theme_classic() +
  theme(
    # Remove grid lines
    panel.grid = element_blank(),
    panel.background = element_rect(fill = "white", color = NA),
    # Title and axis text
    plot.title = element_text(hjust = 0.5, size = 16, face = "bold"),
    axis.text.x = element_blank(),
    axis.ticks.x = element_blank(),
    axis.text.y = element_text(size = 12, face = "bold"),
    # Legend
    legend.position = c(0.7, 0.85),
    legend.box.background = element_rect(color = "black", size = 0.5)
  )

# Plot for top 5 industries in lowest fisheries-diversified communities
plot_top5_low <- ggplot(industry_ratios_low_top5, aes(
  y = employment_ratio,
  x = reorder(industry__name, -employment_ratio),
  fill = industry__name
)) +
  geom_bar(stat = "identity", color = "black") +  
  scale_y_continuous(labels = scales::percent, limits = c(0, max_y)) +  
  scale_fill_manual(values = industry_colors, name = NULL) +
  labs(
    title = "Low fisheries-diversified communities",
    x = NULL,
    y = expression(bold("Employment Share (%)"))
  ) +
  theme_classic() +
  theme(
    # Remove grid lines
    panel.grid = element_blank(),
    panel.background = element_rect(fill = "white", color = NA),
    # Title and axis text
    plot.title = element_text(hjust = 0.5, size = 16, face = "bold"),
    axis.text.x = element_blank(),
    axis.ticks.x = element_blank(),
    axis.text.y = element_text(size = 12, face = "bold"),
    # Legend
    legend.position = c(0.7, 0.85),
    legend.box.background = element_rect(color = "black", size = 0.5)
  )

# Combine the two plots side by side
combined_plot <- plot_top5_high + plot_top5_low + 
  plot_layout(ncol = 2) +
  plot_annotation(
    caption = "",  # If you want an x-axis label below both bars
    theme = theme(
      plot.caption = element_text(hjust = 0.5, size = 14, face = "bold")
    )
  )

# Display the combined plot
print(combined_plot)

# Save the plot
ggsave(filename = file.path(FIGURES, "fig02_sector_composition.png"),
  plot = combined_plot,
  width = 10, 
  height = 6, 
  dpi = 300
)