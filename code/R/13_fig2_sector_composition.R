# 13_fig2_sector_composition.R: Fig. 2, sectoral composition of high- vs. low-fisheries-diversification communities.
# Inputs:  $RAW/employment-by-industry-community-and-year.csv, $DERIVED/estimation_sample.dta
# Outputs: $FIGURES/fig02_sector_composition.png

source(here::here("code", "R", "setup.R"))
library(patchwork)

## Fisheries-diversification quartiles ---------------------------------------
communities <- read_dta(file.path(DERIVED, "estimation_sample.dta")) %>%
  mutate(fish_quartile = ntile(div_fished_s, 4))

high_fish_city <- filter(communities, fish_quartile == 4)$city
low_fish_city  <- filter(communities, fish_quartile == 1)$city

## Employment shares by industry ---------------------------------------------
avg_employment <- read_csv(file.path(RAW, "employment-by-industry-community-and-year.csv"),
                           show_col_types = FALSE) %>%
  group_by(community__name, industry__name) %>%
  summarise(avg_employment = mean(emp, na.rm = TRUE), .groups = "drop")

top5_shares <- function(cities) {
  avg_employment %>%
    filter(community__name %in% cities) %>%
    group_by(industry__name) %>%
    summarise(total = sum(avg_employment, na.rm = TRUE), .groups = "drop") %>%
    mutate(employment_ratio = total / sum(total)) %>%
    arrange(desc(employment_ratio)) %>%
    slice_head(n = 5)
}

top5_high <- top5_shares(high_fish_city)
top5_low  <- top5_shares(low_fish_city)

## Plot ------------------------------------------------------------------------
industry_colors <- setNames(
  c("#66c2a5", "#fc8d62", "#8da0cb", "#e78ac3", "#a6d854", "#ffd92f", "#e5c494", "#b3b3b3"),
  unique(c(top5_high$industry__name, top5_low$industry__name))
)
max_y <- max(top5_high$employment_ratio, top5_low$employment_ratio)

share_plot <- function(df, title) {
  ggplot(df, aes(reorder(industry__name, -employment_ratio), employment_ratio, fill = industry__name)) +
    geom_bar(stat = "identity", color = "black") +
    scale_y_continuous(labels = scales::percent, limits = c(0, max_y)) +
    scale_fill_manual(values = industry_colors, name = NULL) +
    labs(title = title, x = NULL, y = expression(bold("Employment Share (%)"))) +
    theme_classic() +
    theme(
      panel.grid = element_blank(),
      panel.background = element_rect(fill = "white", color = NA),
      plot.title = element_text(hjust = 0.5, size = 16, face = "bold"),
      axis.text.x = element_blank(),
      axis.ticks.x = element_blank(),
      axis.text.y = element_text(size = 12, face = "bold"),
      legend.position = c(0.7, 0.85),
      legend.box.background = element_rect(color = "black", size = 0.5)
    )
}

combined_plot <- share_plot(top5_high, "High fisheries-diversified communities") +
  share_plot(top5_low, "Low fisheries-diversified communities") +
  plot_layout(ncol = 2)

ggsave(file.path(FIGURES, "fig02_sector_composition.png"), combined_plot, width = 10, height = 6, dpi = 300)
