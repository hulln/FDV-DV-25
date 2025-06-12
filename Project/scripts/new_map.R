# ==================================
# ECONOMIC & DEMOGRAPHIC SEMICIRCLE MAP (Final Tweaked)
# ==================================

# LOAD PACKAGES ----
library(tidyverse)
library(giscoR)
library(sf)
library(tidygeocoder)
library(scales)
library(showtext)
library(here)
library(ggforce)

# GLOBAL SETTINGS ----

# Colors
type_colors <- c(
  "Tourist"        = "#A80000",
  "Region Capital" = "#008080",
  "Ljubljana"      = "#D78B00"
)

# Fonts
font_add_google("Montserrat", "Montserrat")
font_add_google("Space Mono", "SpaceMono")
showtext_auto()

# Theme
theme_map <- theme_void(base_size = 12) +
  theme(
    plot.title = element_text(family = "SpaceMono", face = "bold", size = rel(1.3), hjust = 0.5),
    plot.subtitle = element_text(family = "Montserrat", size = rel(1.0), hjust = 0.5, color = "grey30"),
    plot.caption = element_text(family = "Montserrat", size = rel(0.8), hjust = 1, color = "grey50"),
    legend.position = "bottom",
    legend.title = element_text(family = "Montserrat", face = "bold"),
    legend.text = element_text(family = "Montserrat")
  )

# Save Helper
save_plot <- function(plot, name, width = 18, height = 14, units = "cm", dpi = 300) {
  ggsave(file.path(here("output"), paste0(name, ".png")), plot = plot, width = width, height = height, units = units, dpi = dpi, bg = "transparent")
  ggsave(file.path(here("output"), paste0(name, ".svg")), plot = plot, width = width, height = height, units = units, dpi = dpi, bg = "transparent")
}

# LOAD DATA ----

raw <- read_csv(here("data", "all_data_full.csv"))

wide_yr <- raw %>%
  select(-Unit) %>%
  pivot_wider(names_from = Variable, values_from = Value)

snap_23 <- wide_yr %>% filter(Year == 2023)

# SHAPE + GEOCODE ----

nuts3_si <- gisco_get_nuts(
  country = "SI", nuts_level = 3, resolution = 20,
  cache = TRUE, update_cache = TRUE
) %>% st_as_sf()

munis_geo <- snap_23 %>%
  distinct(Municipality) %>%
  geocode(Municipality, method = "osm", verbose = TRUE) %>%
  filter(Municipality != "Slovenija") %>%
  left_join(
    snap_23 %>%
      select(Municipality, Type) %>%
      mutate(Type = if_else(Municipality == "Ljubljana", "Ljubljana", if_else(Type == "Capital", "Region Capital", Type))),
    by = "Municipality"
  )

# EXTENDED DATA ----

munis_geo_ext <- munis_geo %>%
  left_join(
    snap_23 %>%
      select(Municipality, `Average Age`, `Annual Salary`) %>%
      mutate(Monthly_Salary = `Annual Salary` / 12) %>%
      select(-`Annual Salary`),
    by = "Municipality"
  ) %>%
  drop_na(`Average Age`, Monthly_Salary) %>%
  mutate(
    radius_age = scales::rescale(`Average Age`, to = c(0.035, 0.10)),
    radius_salary = scales::rescale(Monthly_Salary, to = c(0.035, 0.10)),
    Municipality = str_trim(Municipality),
    
    # Shift circle positions
    lat = case_when(
      Municipality == "Ljubljana" ~ lat - 0.06,
      Municipality == "Novo mesto" ~ lat - 0.05,
      Municipality %in% c("Kranjska Gora", "Bohinj", "Bled", "Bovec", "Piran") ~ lat + 0.04,
      TRUE ~ lat
    ),
    
    # Shift label positions
    lat_label = case_when(
      Municipality == "Kranj" ~ lat + 0.08,
      Municipality == "Nova Gorica" ~ lat + 0.1,
      Municipality == "Bohinj" ~ lat + 0.10, 
      Municipality == "Koper" ~ lat + 0.10,
      Municipality == "Celje" ~ lat + 0.10,
      Municipality %in% c("Kranjska Gora", "Bled", "Bovec", "Piran",
                          "Maribor", "Murska Sobota") ~ lat + 0.12,
      TRUE ~ lat + 0.08
    )
  )

# SEMICIRCLE MAP ----

p_map_semi <- ggplot(nuts3_si) +
  geom_sf(fill = NA, colour = "grey30", linewidth = 0.3) +
  
  # Top semicircle (monthly salary)
  geom_arc_bar(
    data = munis_geo_ext,
    aes(
      x0 = long,
      y0 = lat,
      r0 = 0,
      r = radius_salary,
      start = pi / 2,
      end = 3 * pi / 2,
      fill = Type
    ),
    color = "black", alpha = 0.9
  ) +
  
  # Bottom semicircle (average age)
  geom_arc_bar(
    data = munis_geo_ext,
    aes(
      x0 = long,
      y0 = lat,
      r0 = 0,
      r = radius_age,
      start = 3 * pi / 2,
      end = pi / 2 + 2 * pi,
      fill = Type
    ),
    color = "black", alpha = 0.9
  ) +
  
  # City labels
  geom_text(
    data = munis_geo_ext %>%
      distinct(Municipality, .keep_all = TRUE) %>%
      mutate(Display_Name = str_to_title(Municipality)),
    aes(x = long, y = lat_label, label = Display_Name),
    size = 3,
    family = "Montserrat"
  ) +
  
  scale_fill_manual(values = type_colors, name = "Municipality Type") +
  
  coord_sf(
    xlim = c(13.5, 16.5),
    ylim = c(45.4, 46.9),
    crs = st_crs(nuts3_si)
  ) +
  
  labs(
    title = "Salary & Age by Municipality",
    subtitle = "Top semicircle: Monthly salary · Bottom semicircle: Average age",
    caption = "Data source: Statistical Office of Slovenia"
  ) +
  
  theme_map


# DISPLAY + EXPORT ----
print(p_map_semi)
save_plot(p_map_semi, "map_economic_demographic_semicircles")

# ==================================
# END OF SCRIPT
# ==================================
