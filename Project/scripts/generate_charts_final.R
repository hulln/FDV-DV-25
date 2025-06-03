# ==================================
# Tourism & Demography Visualization
# ==================================

# PACKAGES ----
library(tidyverse)
library(GGally)
library(reshape2)
library(giscoR)
library(sf)
library(tidygeocoder)
library(ggrepel)
library(showtext)
library(stringr)
library(scales)
library(here)

# GLOBAL SETTINGS ----

# Output folder
output_dir <- here("output")
dir.create(output_dir, showWarnings = FALSE)

# Colors
type_colors <- c(
  "Tourist"   = "#A80000",
  "Capital"   = "#008080",
  "Ljubljana" = "#D78B00"
)

# Fonts
font_add_google("Montserrat", "Montserrat")
font_add_google("Poppins",    "Poppins")
font_add_google("Space Mono", "SpaceMono")
showtext_auto()

# Global theme
theme_custom <- theme_minimal(base_size = 12) +
  theme(
    plot.title = element_text(family = "SpaceMono", face = "bold", size = rel(1.3), hjust = 0.5),
    plot.subtitle = element_text(family = "Montserrat", size = rel(1.0), hjust = 0.5, color = "grey30"),
    axis.title = element_text(family = "Poppins", size = rel(1.0)),
    axis.text = element_text(family = "Poppins", size = rel(0.9)),
    plot.caption = element_text(family = "Helvetica", size = rel(0.8), hjust = 1, color = "grey50"),
    legend.position = "bottom",
    legend.title = element_text(family = "Poppins", face = "bold"),
    legend.text = element_text(family = "Poppins")
  )

# Helper to save plots
save_plot <- function(plot, name, width = 18, height = 14, units = "cm", dpi = 300) {
  ggsave(file.path(output_dir, paste0(name, ".png")), plot = plot, width = width, height = height, units = units, dpi = dpi, bg = "transparent")
  ggsave(file.path(output_dir, paste0(name, ".svg")), plot = plot, width = width, height = height, units = units, dpi = dpi, bg = "transparent")
}

# DATA ----

raw <- read_csv(here("data", "all_data_full.csv"))

wide_yr <- raw %>%
  select(-Unit) %>%
  pivot_wider(names_from = Variable, values_from = Value)

snap_23 <- wide_yr %>% filter(Year == 2023)

# MAP SHAPE ----

nuts3_si <- gisco_get_nuts(
  country = "SI", nuts_level = 3, resolution = 20,
  cache = TRUE, update_cache = TRUE
) %>% st_as_sf()

# GEOCODING ----

munis_geo <- snap_23 %>%
  distinct(Municipality) %>%
  geocode(Municipality, method = "osm", verbose = TRUE) %>%
  filter(Municipality != "Slovenija")

munis_geo <- munis_geo %>%
  left_join(
    snap_23 %>%
      select(Municipality, Type) %>%
      mutate(Type = if_else(Municipality == "Ljubljana", "Ljubljana", Type)),
    by = "Municipality"
  )

# SCATTER MATRIX ----

snap_23_complete <- snap_23 %>%
  select(Type, Overnights, `Property Value`, `Annual Salary`, `Average Age`, Migration) %>%
  drop_na()

p_matrix <- ggpairs(snap_23_complete, aes(colour = Type, alpha = .7))
print(p_matrix)
save_plot(p_matrix, "matrix_variables")

# CORRELATION HEATMAP ----

cor_mat <- snap_23 %>%
  select(Overnights, `Property Value`, `Annual Salary`, `Average Age`, Migration) %>%
  cor(use = "pairwise.complete.obs") %>%
  melt()

p_heatmap <- ggplot(cor_mat, aes(Var1, Var2, fill = value)) +
  geom_tile(color = "white") +
  geom_text(aes(label = round(value, 2)), size = 5) +
  scale_fill_gradient2(low = "blue", high = "red", mid = "white", midpoint = 0, limit = c(-1, 1)) +
  theme_custom +
  labs(title = "Correlation between variables", x = "", y = "", fill = "Correlation")

print(p_heatmap)
save_plot(p_heatmap, "heatmap_correlation")

# TOURISM VS HOUSING SCATTER ----

p_scatter <- ggplot(snap_23, aes(x = Overnights, y = `Property Value`, colour = Type)) +
  geom_point(size = 6, alpha = 0.9) +
  geom_text_repel(aes(label = Municipality), size = 4, max.overlaps = Inf) +
  scale_colour_manual(values = type_colors) +
  scale_x_continuous(labels = label_comma()) +
  scale_y_continuous(labels = label_comma()) +
  labs(
    title = "Does tourism drive up housing prices?",
    subtitle = "Each dot represents a municipality (2023)",
    x = "Number of tourist overnight stays",
    y = "Average property value (EUR/m2)",
    colour = "Municipality type"
  ) +
  theme_custom

print(p_scatter)
save_plot(p_scatter, "scatter_tourism_housing")

# DUMBBELL HOUSING VS SALARY ----

df_dumbbell <- snap_23 %>%
  mutate(Monthly_Salary = `Annual Salary` / 12) %>%
  select(Municipality, Type, `Property Value`, Monthly_Salary) %>%
  arrange(desc(`Property Value`)) %>%
  mutate(Municipality = factor(Municipality, levels = unique(Municipality)))

p_dumbbell <- ggplot(df_dumbbell) +
  geom_segment(aes(x = Monthly_Salary, xend = `Property Value`, y = Municipality, yend = Municipality, colour = Type), size = 1.5, alpha = 0.8) +
  geom_point(aes(x = Monthly_Salary, y = Municipality, colour = Type), size = 5, shape = 21, fill = "white", stroke = 1) +
  geom_point(aes(x = `Property Value`, y = Municipality, colour = Type), size = 5, shape = 21, fill = "white", stroke = 1) +
  scale_colour_manual(values = type_colors) +
  scale_x_continuous(labels = label_comma()) +
  labs(
    title = "Housing Prices vs Local Salaries (2023)",
    subtitle = "Left dot = average monthly salary • Right dot = average property price (EUR/m²)",
    x = "EUR (monthly salary / housing price per m²)",
    y = "",
    caption = "Data source: Statistical Office of Slovenia"
  ) +
  theme_custom

print(p_dumbbell)
save_plot(p_dumbbell, "dumbbell_housing_salary")

# MIGRATION TREND ----

df_migration_trend <- raw %>%
  filter(Variable == "Migration") %>%
  mutate(Municipality = str_trim(Municipality), Type = if_else(Municipality == "Ljubljana", "Ljubljana", Type))

p_migration <- ggplot(df_migration_trend, aes(x = Year, y = Value, group = Municipality, colour = Type)) +
  geom_line(size = 0.8, alpha = 0.9) +
  geom_point(size = 1.5) +
  scale_colour_manual(values = type_colors) +
  scale_x_continuous(breaks = seq(min(df_migration_trend$Year), max(df_migration_trend$Year), 1)) +
  labs(
    title = "Net Migration Over Time",
    subtitle = "Per municipality (per 1 000 inhabitants)",
    x = "Year",
    y = "Net migration (per 1 000 inhabitants)",
    caption = "Data source: Statistical Office of Slovenia"
  ) +
  theme_custom

print(p_migration)
save_plot(p_migration, "trend_migration")

# AVERAGE AGE TREND ----

df_age_trend <- raw %>%
  filter(Variable == "Average Age") %>%
  mutate(Municipality = str_trim(Municipality), Type = if_else(Municipality == "Ljubljana", "Ljubljana", Type))

p_age <- ggplot(df_age_trend, aes(x = Year, y = Value, group = Municipality, colour = Type)) +
  geom_line(size = 0.8, alpha = 0.9) +
  geom_point(size = 1.5) +
  scale_colour_manual(values = type_colors) +
  scale_x_continuous(breaks = seq(min(df_age_trend$Year), max(df_age_trend$Year), 1)) +
  labs(
    title = "Average Age of Residents Over Time",
    subtitle = "Per municipality",
    x = "Year",
    y = "Average age (years)",
    caption = "Data source: Statistical Office of Slovenia"
  ) +
  theme_custom

print(p_age)
save_plot(p_age, "trend_age")

# OVERNIGHTS BAR ----

df_overnights <- snap_23 %>%
  select(Municipality, Type, Overnights) %>%
  arrange(desc(Overnights))

p_overnights <- ggplot(df_overnights, aes(x = reorder(Municipality, Overnights), y = Overnights, fill = Type)) +
  geom_col(alpha = 0.9) +
  scale_fill_manual(values = type_colors) +
  scale_y_continuous(labels = label_comma()) +
  labs(
    title = "Number of tourist overnight stays (2023)",
    subtitle = "Per municipality",
    x = "",
    y = "Number of overnight stays",
    fill = "Municipality type"
  ) +
  theme_custom +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

print(p_overnights)
save_plot(p_overnights, "bar_overnights")

# MAP WITH RINGS ----

# Prepare extended munis_geo_ext ----

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
    size_age = rescale(`Average Age`, to = c(3, 8)),
    size_salary = rescale(Monthly_Salary, to = c(5, 12)),
    Municipality = str_trim(Municipality)
  )

# Plot ----

p_map_rings <- ggplot(nuts3_si) +
  geom_sf(fill = NA, colour = "grey30", linewidth = 0.3) +
  
  # Outer ring: salary
  geom_point(
    data = munis_geo_ext,
    aes(x = long, y = lat),
    shape = 1,
    colour = "black",
    size = munis_geo_ext$size_salary,
    stroke = 1.5,
    alpha = 0.9
  ) +
  
  # Inner circle: age
  geom_point(
    data = munis_geo_ext,
    aes(x = long, y = lat, fill = Type),
    shape = 21,
    colour = "white",
    size = munis_geo_ext$size_age,
    stroke = 0.5,
    alpha = 0.95
  ) +
  
  # Labels
  geom_text(
    data = munis_geo_ext %>%
      distinct(Municipality, .keep_all = TRUE) %>%
      mutate(Display_Name = str_to_title(Municipality)),
    aes(x = long, y = lat + 0.08, label = Display_Name),
    size = 3,
    family = "Poppins"
  ) +
  
  scale_fill_manual(values = type_colors, name = "Municipality Type") +
  
  coord_sf(
    xlim = c(13.5, 16.5),
    ylim = c(45.4, 46.9),
    crs = st_crs(nuts3_si)
  ) +
  
  labs(
    title = "Economic & Demographic Patterns in Slovenian Municipalities",
    subtitle = "Black ring: monthly salary • Colored circle: average age (2023)",
    caption = "Data source: Statistical Office of Slovenia"
  ) +
  
  theme_void(base_size = 12) +
  theme(
    plot.title = element_text(family = "SpaceMono", face = "bold", size = rel(1.3), hjust = 0.5),
    plot.subtitle = element_text(family = "Montserrat", size = rel(1.0), hjust = 0.5, color = "grey30"),
    plot.caption = element_text(family = "Helvetica", size = rel(0.8), hjust = 1, color = "grey50"),
    legend.position = "bottom",
    legend.title = element_text(family = "Poppins", face = "bold"),
    legend.text = element_text(family = "Poppins"),
    plot.margin = margin(20, 20, 20, 20)
  )

# Show + Save

print(p_map_rings)
save_plot(p_map_rings, "map_economic_demographic")


# ==========================================================
# END OF SCRIPT
# ==========================================================
