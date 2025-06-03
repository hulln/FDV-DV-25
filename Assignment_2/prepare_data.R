# prepare_data.R
# Prepares ESS 2018 data for Slovenia and Bulgaria and saves as RDS files for use in Shiny apps

# === Load Required Packages ===
library(haven)
library(dplyr)
library(giscoR)
library(sf)

# === Load ESS Dataset ===
ess <- read_sav("data/ESS9e03_2.sav")

# === Create Output Directory ===
dir.create("data", showWarnings = FALSE)

# === Helper: Download and clean NUTS region map ===
get_nuts_map <- function(country_code) {
  gisco_get_nuts(
    year = 2016,
    epsg = 4326,
    nuts_level = 3,
    country = country_code
  ) %>%
    mutate(NAME_LATN = trimws(as.character(NAME_LATN)))
}

# === --- SLOVENIA --- ===
ess_si <- ess %>%
  filter(cntry == "SI") %>%
  mutate(region = trimws(as.character(region)))

si_map <- get_nuts_map("SI")

region_map_si <- data.frame(
  region_code = c(
    "SI011", "SI012", "SI013", "SI014", "SI015", "SI016",
    "SI017", "SI018", "SI021", "SI022", "SI023", "SI024"
  ),
  region_name = c(
    "Pomurska", "Podravska", "Koroška", "Savinjska",
    "Zasavska", "Posavska", "Jugovzhodna Slovenija",
    "Primorsko-notranjska", "Osrednjeslovenska", "Gorenjska",
    "Goriška", "Obalno-kraška"
  )
)

ess_si <- ess_si %>%
  left_join(region_map_si, by = c("region" = "region_code"))

if (any(is.na(ess_si$region_name))) stop("Some region codes didn’t match for Slovenia!")

saveRDS(ess_si, file = "data/ess_si.rds")
saveRDS(si_map, file = "data/si_map.rds")

# === --- BULGARIA --- ===
ess_bg <- ess %>%
  filter(cntry == "BG") %>%
  mutate(region = trimws(as.character(region)))

bg_map <- get_nuts_map("BG")

# Create region mapping using correct match (join by NUTS code)
region_map_bg <- bg_map %>%
  select(region_code = NUTS_ID, region_name = NAME_LATN) %>%
  filter(region_code %in% unique(ess_bg$region))

ess_bg <- ess_bg %>%
  left_join(region_map_bg, by = c("region" = "region_code"))

if (any(is.na(ess_bg$region_name))) warning("Some region codes didn’t match for Bulgaria!")

saveRDS(ess_bg, file = "data/ess_bg.rds")
saveRDS(bg_map, file = "data/bg_map.rds")

# === Done ===
cat("Data for Slovenia and Bulgaria prepared and saved to /data\n")
