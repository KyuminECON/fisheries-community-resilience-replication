# 10_figS1_diversification_trend.R: Fig. S1, average fisheries and sectoral diversification, 2000-2016.
# Inputs:  $DERIVED/diversity_fish_time_trend.dta, diversity_emp_shannon_time_trend.dta
# Outputs: $FIGURES/figS1a_sectoral_diversification_trend.png, figS1b_fisheries_diversification_trend.png

source(here::here("code", "R", "setup.R"))

## Data ---------------------------------------------------------------------
fish  <- read_dta(file.path(DERIVED, "diversity_fish_time_trend.dta")) %>% zap_labels()
local <- read_dta(file.path(DERIVED, "diversity_emp_shannon_time_trend.dta")) %>% zap_labels()

stopifnot(
  all(c("year", "div_fished_s")   %in% names(fish)),
  all(c("year", "div_emp_diff_s") %in% names(local))
)

yearly_mean <- function(df, var) {
  df %>%
    group_by(year) %>%
    summarize(avg = mean({{ var }}, na.rm = TRUE)) %>%
    filter(!is.nan(avg))
}

## Plot ---------------------------------------------------------------------
trend_plot <- function(avg, ylab, line, shade, text, grid, year_range) {
  ggplot(avg, aes(year, avg)) +
    geom_smooth(method = "loess", span = 0.5, se = TRUE, color = line, fill = shade,
                size = 0.8, linetype = "dashed") +
    geom_point(size = 2.5, color = text, alpha = 0.8) +
    labs(x = "Year", y = ylab) +
    scale_x_continuous(limits = year_range, breaks = seq(year_range[1], year_range[2], by = 2)) +
    theme_minimal() +
    theme(
      axis.title = element_text(face = "bold", size = 14, color = text),
      axis.text = element_text(face = "bold", size = 12, color = text),
      panel.grid.major = element_line(color = grid),
      panel.grid.minor = element_blank(),
      panel.background = element_rect(fill = "white", color = NA),
      panel.border = element_rect(color = text, fill = NA, size = 0),
      axis.line = element_line(color = text, size = 0.3)
    )
}

fish_avg  <- yearly_mean(fish, div_fished_s)
local_avg <- yearly_mean(local, div_emp_diff_s)
end_year  <- max(fish_avg$year, local_avg$year)

fish_plot <- trend_plot(fish_avg, "Fisheries Diversification",
                        "#6A93C0", "#BFD7ED", "#4C566A", "#E5E9F0",
                        range(c(fish_avg$year, local_avg$year)))
local_plot <- trend_plot(local_avg, "Sectoral Diversification",
                         "#D17B88", "#F4C6C9", "#7A4F57", "#F0D8DA",
                         c(2001, end_year))

ggsave(file.path(FIGURES, "figS1b_fisheries_diversification_trend.png"), fish_plot, width = 7, height = 5, dpi = 300)
ggsave(file.path(FIGURES, "figS1a_sectoral_diversification_trend.png"), local_plot, width = 7, height = 5, dpi = 300)
