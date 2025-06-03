library(dplyr)
library(tidyr)
library(tools)

# 1) Identify all numeric ESS columns
num_vars <- ess_si %>% select(where(is.numeric)) %>% names()

# 2) Human‐readable labels for core vars; auto‐generate for the rest
human_labels <- c(
  happy   = "Overall Happiness",
  stflife = "Life Satisfaction",
  trstplt = "Trust in Politicians",
  trstprl = "Trust in Parliament",
  trstlgl = "Trust in Legal System"
)
others <- setdiff(num_vars, names(human_labels))
human_labels[others] <- sapply(others, function(v) toTitleCase(gsub("_", " ", v)))

# 3) Compute regional means for every numeric variable
region_means <- ess_si %>%
  group_by(region_name) %>%
  summarise(across(all_of(num_vars), ~mean(.x, na.rm = TRUE)), .groups = "drop")

# 4) For each var, compute between-region SD and range of those means
var_region_stats <- region_means %>%
  summarise(across(
    -region_name,
    list(
      mean_reg  = ~mean(.x, na.rm = TRUE),
      sd_reg    = ~sd(.x, na.rm = TRUE),
      range_reg = ~diff(range(.x, na.rm = TRUE))
    )
  )) %>%
  pivot_longer(
    cols     = everything(),
    names_to = c("variable", "stat"),
    names_sep = "_"
  ) %>%
  pivot_wider(names_from = stat, values_from = value)

# 5) Decide “appropriate” vs “not” by comparing sd_reg to the median sd_reg
threshold <- median(var_region_stats$sd_reg, na.rm = TRUE)

var_region_stats <- var_region_stats %>%
  mutate(
    human_name  = human_labels[variable],
    appropriate = sd_reg >= threshold,
    reason      = ifelse(
      appropriate,
      paste0(
        "Between-region SD = ", round(sd_reg, 2),
        " ≥ median SD (", round(threshold, 2), "): good spread."
      ),
      paste0(
        "Between-region SD = ", round(sd_reg, 2),
        " < median SD (", round(threshold, 2), "): too little variation."
      )
    )
  ) %>%
  arrange(desc(sd_reg))

# 6) Inspect the result
print(var_region_stats)

## add new vars: 

frlgrsp Fair level of [weekly/monthly/annual] gross pay for you
|edulvlb  |   370.63|    28.90|     84.85|Highest level of education
|prtclfsi |     6.03|     0.65|      2.36|Which party feel closer to, Slovenia
|eduyrs   |    12.52|     0.64|      1.84|Years of full-time education completed
|stfeco   |     5.08|     0.36|      1.11|How satisfied with present state of economy in country

