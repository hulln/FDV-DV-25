# === ass2.R (updated) ===

library(haven)
library(dplyr)
library(ggplot2)
library(sf)
library(giscoR)
library(tidyr)
library(knitr)
library(tools)

# === 1. LOAD DATA ===
ess <- read_sav("data/ESS9e03_2.sav")
ess_si <- ess %>% filter(cntry == "SI")

# === 2. MAP REGION CODES TO REGION NAMES ===
region_map <- data.frame(
  region_code = c("SI011","SI012","SI013","SI014","SI015","SI016",
                  "SI017","SI018","SI021","SI022","SI023","SI024"),
  region_name = c("Pomurska","Podravska","Koroška","Savinjska",
                  "Zasavska","Posavska","Jugovzhodna Slovenija",
                  "Primorsko-notranjska","Osrednjeslovenska","Gorenjska", 
                  "Goriška","Obalno-kraška")
)
ess_si <- ess_si %>%
  mutate(region = trimws(as.character(region))) %>%
  left_join(region_map, by = c("region" = "region_code"))

# === 3. LOAD SLOVENIAN MAP (NUTS3) ===
si_map <- gisco_get_nuts(
  year = 2016,
  epsg = 4326,
  nuts_level = 3,
  country = "SI"
) %>%
  mutate(NAME_LATN = trimws(as.character(NAME_LATN)))

# === 4. QUICK VARIABLE RANGE CHECK ===
ess_si %>%
  summarise(
    happy_min    = min(happy,    na.rm = TRUE), happy_max    = max(happy,    na.rm = TRUE),
    stflife_min  = min(stflife,  na.rm = TRUE), stflife_max  = max(stflife,  na.rm = TRUE),
    trstplt_min  = min(trstplt,  na.rm = TRUE), trstplt_max  = max(trstplt,  na.rm = TRUE),
    trstprl_min  = min(trstprl,  na.rm = TRUE), trstprl_max  = max(trstprl,  na.rm = TRUE),
    trstlgl_min  = min(trstlgl,  na.rm = TRUE), trstlgl_max  = max(trstlgl,  na.rm = TRUE),
    frlgrsp_min  = min(frlgrsp,  na.rm = TRUE), frlgrsp_max  = max(frlgrsp,  na.rm = TRUE),
    edulvlb_min  = min(edulvlb,  na.rm = TRUE), edulvlb_max  = max(edulvlb,  na.rm = TRUE),
    prtclfsi_min = min(prtclfsi, na.rm = TRUE), prtclfsi_max = max(prtclfsi, na.rm = TRUE),
    eduyrs_min   = min(eduyrs,   na.rm = TRUE), eduyrs_max   = max(eduyrs,   na.rm = TRUE),
    stfeco_min   = min(stfeco,   na.rm = TRUE), stfeco_max   = max(stfeco,   na.rm = TRUE)
  ) %>%
  print()

# === 5. CHOROPLETH-FRIENDLY VARIABLES – Slovenia only ===

# 5a) Identify all numeric variables
num_vars <- ess_si %>% select(where(is.numeric)) %>% names()

# 5b) Extract human-readable labels (from SAV metadata where available)
human_labels <- sapply(num_vars, function(v) {
  lbl <- attr(ess_si[[v]], "label")
  if (is.null(lbl) || lbl == "") v else lbl
}, USE.NAMES = TRUE)

# 5b.1) Override/define labels for the five new vars
override_labels <- c(
  frlgrsp  = "Fair level of [weekly/monthly/annual] gross pay for you",
  edulvlb  = "Highest level of education",
  prtclfsi = "Which party feel closer to, Slovenia",
  eduyrs   = "Years of full-time education completed",
  stfeco   = "How satisfied with present state of economy in country"
)
human_labels[names(override_labels)] <- override_labels

# 5c) Compute each variable’s mean in each region
region_means <- ess_si %>%
  group_by(region_name) %>%
  summarise(across(all_of(num_vars), ~ mean(.x, na.rm = TRUE)), .groups = "drop")

# 5d) Calculate between-region mean, SD, and range
var_stats <- region_means %>%
  pivot_longer(-region_name, names_to = "variable", values_to = "reg_mean") %>%
  group_by(variable) %>%
  summarise(
    mean_reg  = mean(reg_mean, na.rm = TRUE),
    sd_reg    = sd(reg_mean,   na.rm = TRUE),
    range_reg = diff(range(reg_mean, na.rm = TRUE)),
    .groups = "drop"
  )

# 5e) Threshold = median SD across all variables
threshold <- median(var_stats$sd_reg, na.rm = TRUE)

# 5f) Build and render the final table
final_var_table <- var_stats %>%
  mutate(
    human_name  = human_labels[variable],
    cv_reg      = sd_reg / mean_reg,
    appropriate = sd_reg >= threshold,
    reason      = ifelse(
      appropriate,
      paste0("SD=", round(sd_reg,2), " ≥ median(", round(threshold,2), ")"),
      paste0("SD=", round(sd_reg,2), " < median(", round(threshold,2), ")")
    )
  ) %>%
  arrange(desc(sd_reg))

kable(
  final_var_table,
  digits  = c(0, 2, 2, 2, 2, 2, NA, NA),
  caption = "Between-region variation of numeric ESS variables (Slovenia only)"
)
