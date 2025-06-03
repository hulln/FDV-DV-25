# LOAD PACKAGES ----

library(tidyverse)
library(GGally)
library(reshape2)
library(giscoR)
library(sf)
library(tidygeocoder)
library(stringr)
library(ggrepel)

# LOAD DATA ----

raw <- read_csv("all_data_full.csv")

# Inspect structure
glimpse(raw)        
count(raw, Variable, Year)  # check variable coverage

# PREPARE DATA ----

# Wide format: one row = Municipality-Year
wide_yr <- raw %>%                         
  select(-Unit) %>% 
  pivot_wider(names_from = Variable, values_from = Value)

# 2023 snapshot
snap_23 <- wide_yr %>% filter(Year == 2023)

# Summary of key variables
summary(select(snap_23, Overnights, `Property Value`, `Annual Salary`,
               `Average Age`, Migration))

# SCATTER MATRIX (GGPAIRS) ----

# Prepare complete cases only
snap_23_complete <- snap_23 %>%
  select(Type, Overnights, `Property Value`, `Annual Salary`, 
         `Average Age`, Migration) %>%
  drop_na()

# Plot scatter matrix
p <- ggpairs(snap_23_complete,
             aes(colour = Type, alpha = .7))
print(p)

# CORRELATION HEATMAP ----

# Compute correlation matrix (pairwise complete)
cor_mat <- snap_23 %>%
  select(Overnights, `Property Value`, `Annual Salary`,
         `Average Age`, Migration) %>%
  cor(use = "pairwise.complete.obs")

# Melt for ggplot
cor_melt <- melt(cor_mat)

# Plot heatmap
ggplot(cor_melt, aes(Var1, Var2, fill = value)) +
  geom_tile(color = "white") +
  geom_text(aes(label = round(value, 2)), size = 5) +
  scale_fill_gradient2(low = "blue", high = "red", mid = "white",
                       midpoint = 0, limit = c(-1,1)) +
  theme_minimal(base_size = 16) +
  theme(axis.text.x = element_text(angle = 45, hjust = 1),
        panel.grid = element_blank(),
        panel.border = element_blank()) +
  labs(title = "Correlation between variables",
       x = "", y = "", fill = "Correlation")

# GET MAP SHAPE ----

# Get NUTS3 shapes (regions)
nuts3_si <- gisco_get_nuts(
  country = "SI",
  nuts_level = 3,
  resolution = 20,
  cache = TRUE,
  update_cache = TRUE
) %>% 
  st_as_sf()

# Quick check of map
plot(nuts3_si["geometry"])

# GEOCODE MUNICIPALITIES ----

# Prepare municipality list
munis <- snap_23 %>% distinct(Municipality)

# Geocode using OSM
munis_geo <- munis %>%
  tidygeocoder::geocode(Municipality, method = "osm", verbose = TRUE)

# Remove spurious entry if present
munis_geo <- munis_geo %>% filter(Municipality != "Slovenija")

# Prepare TYPES for MAP ----

# Clean Municipality names
snap_23_fixed <- snap_23 %>%
  mutate(Municipality = str_trim(Municipality)) %>%
  filter(Type %in% c("Tourist", "Capital")) %>%
  select(Municipality, Type) %>%
  distinct()

munis_geo <- munis_geo %>%
  mutate(Municipality = str_trim(Municipality)) %>%
  left_join(snap_23_fixed, by = "Municipality") %>%
  mutate(Type = case_when(
    Municipality == "Ljubljana" ~ "Ljubljana",
    TRUE ~ Type
  ))

# Check result
print(table(munis_geo$Type))

# FINAL MAP ----

# Build map
p_map <- ggplot(nuts3_si) +
  geom_sf(fill = "grey95", colour = "white", linewidth = 0.2) +
  geom_point(data = munis_geo,
             aes(x = long, y = lat, size = Type, colour = Type),
             alpha = 0.9) +
  scale_size_manual(values = c("Tourist" = 6, "Capital" = 3, "Ljubljana" = 5)) +
  scale_colour_manual(values = c("Tourist" = "#e31a1c",
                                 "Capital" = "steelblue",
                                 "Ljubljana" = "forestgreen")) +
  coord_sf(crs = st_crs(nuts3_si)) +
  theme_void(base_size = 16) +
  labs(
    title    = "Tourist and comparison municipalities",
    subtitle = "Red = tourist • Blue = regional capital • Green = Ljubljana (special status)"
  )

# Save map
ggsave("map_municipalities_dots_types.svg", p_map,
       width = 18, height = 14, units = "cm")

# Show map
print(p_map)

# SCATTERPLOT — TOURIST PRESSURE VS HOUSING PRICES — WITH LABELS ----

p_scatter <- ggplot(snap_23, aes(x = Overnights, y = `Property Value`, colour = Type)) +
  geom_point(size = 6, alpha = 0.9) +
  geom_text_repel(aes(label = Municipality), size = 4, max.overlaps = Inf) +
  scale_colour_manual(values = c("Tourist" = "#e31a1c", 
                                 "Capital" = "steelblue",
                                 "Ljubljana" = "forestgreen")) +
  scale_x_continuous(labels = scales::label_comma()) +
  scale_y_continuous(labels = scales::label_comma()) +
  labs(
    title = "Does tourism drive up housing prices?",
    subtitle = "Each dot represents a municipality (2023)",
    x = "Number of tourist overnight stays",
    y = "Average property value (EUR/m2)",
    colour = "Municipality type"
  ) +
  theme_minimal(base_size = 16) +
  theme(legend.position = "bottom")

# Save scatterplot
ggsave("scatter_tourism_vs_housing_labels.svg", p_scatter,
       width = 18, height = 14, units = "cm")

# Show scatterplot
print(p_scatter)

# Prepare dumbbell data ----

# Create a clean dataframe for dumbbell plot
df_dumbbell <- snap_23 %>%
  mutate(Monthly_Salary = `Annual Salary` / 12) %>%
  select(Municipality, Type, `Property Value`, Monthly_Salary)

# Check
print(df_dumbbell)

# Plot dumbbell ----

# Load ggrepel again for consistent labels (optional)
library(ggrepel)

p_dumbbell <- ggplot(df_dumbbell) +
  geom_segment(aes(x = Monthly_Salary, xend = `Property Value`,
                   y = reorder(Municipality, `Property Value`), yend = Municipality,
                   colour = Type),
               size = 2, alpha = 0.8) +
  geom_point(aes(x = Monthly_Salary, y = Municipality, colour = Type), size = 5) +
  geom_point(aes(x = `Property Value`, y = Municipality, colour = Type), size = 5) +
  scale_colour_manual(values = c("Tourist" = "#e31a1c", 
                                 "Capital" = "steelblue",
                                 "Ljubljana" = "forestgreen")) +
  scale_x_continuous(labels = scales::label_comma()) +
  labs(
    title = "Housing prices vs local salaries",
    subtitle = "Left dot = average monthly salary • Right dot = average property price (EUR/m2)",
    x = "EUR (monthly salary / housing price per m2)",
    y = "",
    colour = "Municipality type"
  ) +
  theme_minimal(base_size = 16) +
  theme(legend.position = "bottom")

# Save dumbbell plot
ggsave("dumbbell_housing_vs_salary.svg", p_dumbbell,
       width = 18, height = 14, units = "cm")

# Show dumbbell plot
print(p_dumbbell)


# MIGRATION TREND — LINE PLOT ----

# Prepare data: Migration over time
df_migration_trend <- raw %>%
  filter(Variable == "Migration") %>%
  mutate(Municipality = str_trim(Municipality),
         Type = if_else(Municipality == "Ljubljana", "Ljubljana", Type))

# Plot
p_migration_trend <- ggplot(df_migration_trend, aes(x = Year, y = Value, group = Municipality, colour = Type)) +
  geom_line(size = 1.2, alpha = 0.9) +
  geom_point(size = 2) +
  scale_colour_manual(values = c("Tourist" = "#e31a1c", 
                                 "Capital" = "steelblue",
                                 "Ljubljana" = "forestgreen")) +
  scale_x_continuous(breaks = seq(min(df_migration_trend$Year), max(df_migration_trend$Year), 1)) +
  labs(
    title = "Net migration over time",
    subtitle = "Per municipality (per 1000 inhabitants)",
    x = "Year",
    y = "Net migration (per 1000 inhabitants)",
    colour = "Municipality type"
  ) +
  theme_minimal(base_size = 16) +
  theme(legend.position = "bottom")

# Save migration trend plot
ggsave("migration_trend_line.svg", p_migration_trend,
       width = 18, height = 14, units = "cm")

# Show plot
print(p_migration_trend)


# AVERAGE AGE TREND — LINE PLOT ----

# Prepare data: Average Age over time
df_age_trend <- raw %>%
  filter(Variable == "Average Age") %>%
  mutate(Municipality = str_trim(Municipality),
         Type = if_else(Municipality == "Ljubljana", "Ljubljana", Type))

# Plot
p_age_trend <- ggplot(df_age_trend, aes(x = Year, y = Value, group = Municipality, colour = Type)) +
  geom_line(size = 1.2, alpha = 0.9) +
  geom_point(size = 2) +
  scale_colour_manual(values = c("Tourist" = "#e31a1c", 
                                 "Capital" = "steelblue",
                                 "Ljubljana" = "forestgreen")) +
  scale_x_continuous(breaks = seq(min(df_age_trend$Year), max(df_age_trend$Year), 1)) +
  labs(
    title = "Average age of residents over time",
    subtitle = "Per municipality",
    x = "Year",
    y = "Average age (years)",
    colour = "Municipality type"
  ) +
  theme_minimal(base_size = 16) +
  theme(legend.position = "bottom")

# Save age trend plot
ggsave("age_trend_line.svg", p_age_trend,
       width = 18, height = 14, units = "cm")

# Show plot
print(p_age_trend)


# OVERNIGHTS BAR CHART ----

# Prepare data
df_overnights <- snap_23 %>%
  select(Municipality, Type, Overnights) %>%
  arrange(desc(Overnights))

# Plot
p_overnights <- ggplot(df_overnights, aes(x = reorder(Municipality, Overnights), y = Overnights, fill = Type)) +
  geom_col(alpha = 0.9) +
  scale_fill_manual(values = c("Tourist" = "#e31a1c", 
                               "Capital" = "steelblue",
                               "Ljubljana" = "forestgreen")) +
  scale_y_continuous(labels = scales::label_comma()) +
  labs(
    title = "Number of tourist overnight stays (2023)",
    subtitle = "Per municipality",
    x = "",
    y = "Number of overnight stays",
    fill = "Municipality type"
  ) +
  theme_minimal(base_size = 16) +
  theme(axis.text.x = element_text(angle = 45, hjust = 1),
        legend.position = "bottom")

# Save bar chart
ggsave("overnights_bar.svg", p_overnights,
       width = 18, height = 14, units = "cm")

# Show plot
print(p_overnights)


# MODIFIED MAP ----
# ASSUME already loaded / computed:
#   nuts3_si   (the NUTS3 shapes)
#   munis_geo  (lat/long + Municipality + Type)
#   snap_23    (2023 snapshot with Average Age & Annual Salary)

library(dplyr)
library(ggplot2)
library(scales)  # for rescale()
library(stringr) # for str_trim()

# 1) EXTEND munis_geo WITH AGE & MONTHLY_SALARY, THEN COMPUTE RADII ----

munis_geo_ext <- munis_geo %>%
  # Join in Average Age and Annual Salary (then compute Monthly Salary)
  left_join(
    snap_23 %>%
      select(Municipality, `Average Age`, `Annual Salary`) %>%
      mutate(Monthly_Salary = `Annual Salary` / 12) %>%
      select(-`Annual Salary`),
    by = "Municipality"
  ) %>%
  # Drop any rows that failed to join (just in case)
  drop_na(`Average Age`, Monthly_Salary) %>%
  # Now compute two size columns (in mm) for ggplot:
  mutate(
    # Inner dot radius ∝ Average Age, scaled between 3 and 8
    size_age    = rescale(`Average Age`, to = c(3, 8)),
    # Outer circle radius ∝ Monthly Salary, scaled between 5 and 12
    # (must be larger than size_age so it forms an outline around inner)
    size_salary = rescale(Monthly_Salary, to = c(5, 12)),
    # Clean Municipality string
    Municipality = str_trim(Municipality)
  )

# Confirm columns:
print(colnames(munis_geo_ext))
# Should include: Municipality, lat, long, Type, Average Age, Monthly_Salary, size_age, size_salary
head(munis_geo_ext)



# 5) REGISTER & LOAD CUSTOM FONTS VIA showtext ----

# Add Google fonts (download & register)
font_add_google(name = "Montserrat", family = "Montserrat")
font_add_google(name = "Poppins",    family = "Poppins")
font_add_google(name = "Space Mono", family = "SpaceMono")

# Register Helvetica (system font) or fallback if available on your machine
# If Helvetica is not installed, replace "Helvetica" with "Arial" or other sans-serif
font_add(family = "Helvetica", regular = "Helvetica")

# Enable showtext for future plots (renders text via these fonts)
showtext_auto()


# 6) DEFINE COLOR PALETTE & BACKGROUND ----

bg_color          <- "#F0F0F0"   # light grey background for map
type_colors       <- c(
  "Tourist"   = "#A80000",  # dark red
  "Capital"   = "#008080",  # teal
  "Ljubljana" = "#D78B00"   # gold
)
outer_circle_color <- "#000000"  # black for salary outlines


# 7) PLOT MAP WITH TWO-LAYER POINTS & CUSTOM FONTS ----

p_map_age_income <- ggplot(nuts3_si) +
  # Background: NUTS3 regions filled light grey
  geom_sf(fill = NA, colour = "grey30", linewidth = 0.3) +
  
  # Outer rings: hollow circle (size = size_salary, color black)
  geom_point(
    data   = munis_geo_ext,
    aes(x = long, y = lat),
    shape  = 1,                # hollow circle
    colour = outer_circle_color,
    size   = munis_geo_ext$size_salary, # radius in mm
    stroke = 1.5,              # outline thickness
    alpha  = 0.9
  ) +
  
  # Inner circles: filled circle (size = size_age, fill by Type, white border)
  geom_point(
    data   = munis_geo_ext,
    aes(x = long, y = lat, fill = Type),
    shape  = 21,               # filled circle with border
    colour = "white",          # white border around inner circle
    size   = munis_geo_ext$size_age,   # radius in mm (smaller than outer)
    stroke = 0.5,              # thin white border
    alpha  = 0.95
  ) +
  
  # Municipality labels slightly above each point
  geom_text(
    data = munis_geo_ext %>%
      distinct(Municipality, .keep_all = TRUE) %>%
      mutate(
        Display_Name = case_when(
          Municipality == "Novo mesto" ~ "Novo mesto",
          TRUE ~ str_to_title(Municipality)
        )
      ),
    aes(x = long, y = lat + 0.08, label = Display_Name),
    size   = 3,                 # text size
    vjust  = 0,                 # place label just above
    family = "Poppins"          # Poppins font for small labels
  ) +
  
  # Fill scale for inner circles (municipality type colors)
  scale_fill_manual(values = type_colors, name = "Municipality Type") +
  
  # Coordinate system: restrict map to Slovenia extents
  coord_sf(
    xlim = c(13.5, 16.5),
    ylim = c(45.4, 46.9),
    crs  = st_crs(nuts3_si)
  ) +
  
  # Titles, subtitle, and caption using custom fonts
  labs(
    title    = "Economic & Demographic Patterns in Slovenian Municipalities",
    subtitle = "Black ring: monthly salary • Colored circle: average age (2023)",
    caption  = "Data source: Statistical Office of Slovenia"
  ) +
  
  # Theme adjustments
  theme_void(base_size = 12) +
  theme(
    plot.title = element_text(
      family = "SpaceMono",    # Space Mono for title
      face   = "bold",
      size   = rel(1.3),
      hjust  = 0.5,
      margin = margin(b = 10)
    ),
    plot.subtitle = element_text(
      family = "Montserrat",   # Montserrat for subtitle
      size   = rel(1.0),
      hjust  = 0.5,
      color  = "grey30",
      margin = margin(b = 15)
    ),
    plot.caption = element_text(
      family = "Helvetica",    # Helvetica for caption
      size   = rel(0.8),
      hjust  = 1,
      color  = "grey50"
    ),
    plot.margin = margin(20, 20, 20, 20),
    panel.background = element_rect(fill = NA, color = "grey30"),
    plot.background  = element_rect(fill = NA, color = "grey30"),
    
    legend.position = "bottom",
    legend.title = element_text(
      family = "Poppins",     # Poppins for legend title
      size   = rel(1.0),
      face   = "bold"
    ),
    legend.text = element_text(
      family = "Poppins",     # Poppins for legend text
      size   = rel(0.9)
    )
  )

# Display the map in RStudio’s Plots pane
print(p_map_age_income)


# 8) SAVE OUTPUT ----

# High-resolution PNG (300 dpi)
ggsave(
  filename = "slovenia_tourism_map.png",
  plot     = p_map_age_income,
  width    = 10,
  height   = 8,
  dpi      = 300,
  bg       = "transparent"
)

# SVG (Canva-compatible)
ggsave(
  filename = "slovenia_tourism_map.svg",
  plot     = p_map_age_income,
  width    = 10,
  height   = 8,
  dpi      = 300,
  bg       = "transparent"
)




# BARBELL (DUMBBELL) CHART WITH CUSTOM COLOR SCHEME & FONTS ----

# Assumes you have already run the “MODIFIED MAP” code and have:
#   • df_dumbbell  (Municipality, Type, Property Value, Monthly_Salary)
#   • showtext is loaded and fonts are registered
#   • type_colors  defined as in your map code:
#
#       type_colors <- c(
#         "Tourist"   = "#A80000",   # dark red
#         "Capital"   = "#008080",   # teal
#         "Ljubljana" = "#D78B00"    # gold
#       )

library(ggplot2)
library(dplyr)
library(showtext)
library(scales)
library(stringr)

# Ensure showtext is active (renders Google fonts)
showtext_auto()

# If you haven’t registered these Google fonts already in this session, do so:
font_add_google(name = "Montserrat", family = "Montserrat")
font_add_google(name = "Poppins",    family = "Poppins")
font_add_google(name = "Space Mono", family = "SpaceMono")
#font_add(family = "Helvetica", regular = "Helvetica")  
# (If Helvetica isn’t installed, substitute "Arial" or another sans‐serif)

# Re‐define the color palette (must match your map):
type_colors <- c(
  "Tourist"   = "#A80000",
  "Capital"   = "#008080",
  "Ljubljana" = "#D78B00"
)

# PREPARE DATA FOR BARBELL ----
df_dumbbell <- snap_23 %>%
  mutate(
    Monthly_Salary = `Annual Salary` / 12,
    Type = if_else(Municipality == "Ljubljana", "Ljubljana", Type)  # <--- THIS FIXES IT
  ) %>%
  select(Municipality, Type, `Property Value`, Monthly_Salary) %>%
  mutate(Municipality = case_when(
    Municipality == "Novo mesto" ~ "Novo mesto",
    TRUE ~ str_to_title(Municipality)
  ))

# Note: Above re‐ordering is optional. You can also order by Property Value or Salary.
# For example, to order by descending property value:
df_dumbbell <- df_dumbbell %>%
  arrange(desc(`Property Value`)) %>%
  mutate(Municipality = factor(Municipality, levels = unique(Municipality)))

# BUILD THE BARBELL CHART ----
p_dumbbell_custom <- ggplot(df_dumbbell) +
  # The connecting segment between Salary and Property Value
  geom_segment(
    aes(
      x    = Monthly_Salary, 
      xend = `Property Value`,
      y    = Municipality, 
      yend = Municipality,
      colour = Type
    ),
    size  = 1.5,
    alpha = 0.8
  ) +
  # Left dot = Monthly Salary
  geom_point(
    aes(x = Monthly_Salary, y = Municipality, colour = Type),
    size   = 5,
    shape  = 21,
    fill   = "white",
    stroke = 1
  ) +
  # Right dot = Property Value
  geom_point(
    aes(x = `Property Value`, y = Municipality, colour = Type),
    size   = 5,
    shape  = 21,
    fill   = "white",
    stroke = 1
  ) +
  
  # Color scale exactly matching map
  scale_colour_manual(
    values = type_colors,
    guide  = guide_legend(override.aes = list(shape = 21, size = 6)),
    name   = "Municipality Type"
  ) +
  
  # X‐axis uses comma separators
  scale_x_continuous(labels = label_comma()) +
  
  # Labels with custom fonts
  labs(
    title    = "Housing Prices vs Local Salaries (2023)",
    subtitle = "Left dot = average monthly salary • Right dot = average property price (EUR/m²)",
    x        = "EUR (monthly salary / housing price per m²)",
    y        = "",
    caption  = "Data source: Statistical Office of Slovenia"
  ) +
  
  # Minimal theme with custom fonts
  theme_minimal(base_size = 12) +
  theme(
    # Title uses Space Mono
    plot.title = element_text(
      family = "SpaceMono",
      face   = "bold",
      size   = rel(1.3),
      hjust  = 0.5,
      margin = margin(b = 8)
    ),
    # Subtitle uses Montserrat
    plot.subtitle = element_text(
      family = "Montserrat",
      size   = rel(1.0),
      hjust  = 0.5,
      color  = "grey30",
      margin = margin(b = 12)
    ),
    # Axis text (municipality names) uses Poppins
    axis.text.y = element_text(
      family = "Poppins",
      size   = rel(0.9),
      colour = "black"
    ),
    axis.text.x = element_text(
      family = "Poppins",
      size   = rel(0.9),
      colour = "black"
    ),
    axis.title.x = element_text(
      family = "Poppins",
      size   = rel(1.0),
      margin = margin(t = 8)
    ),
    axis.title.y = element_blank(),
    panel.grid.major.y = element_blank(),   # no horizontal gridlines
    panel.grid.minor = element_blank(),
    panel.grid.major.x = element_line(colour = "white", size = 0.4),
    
    # Caption uses Helvetica
    plot.caption = element_text(
      family = "Helvetica",
      size   = rel(0.8),
      hjust  = 1,
      colour = "grey50",
      margin = margin(t = 10)
    ),
    
    # Legend uses Poppins
    legend.position = "bottom",
    legend.title = element_text(
      family = "Poppins",
      face   = "bold",
      size   = rel(1.0)
    ),
    legend.text = element_text(
      family = "Poppins",
      size   = rel(0.9)
    ),
    legend.key = element_blank(),   # remove boxes behind legend points
    plot.margin = margin(20, 20, 20, 20)
  )

# Preview the chart
print(p_dumbbell_custom)

# SAVE HIGH-RES PNG & SVG WITH TRANSPARENT BACKGROUND ----

ggsave(
  filename = "dumbbell_housing_vs_salary_custom.png",
  plot     = p_dumbbell_custom,
  width    = 10,
  height   = 8,
  dpi      = 300,
  bg       = "transparent"
)

ggsave(
  filename = "dumbbell_housing_vs_salary_custom.svg",
  plot     = p_dumbbell_custom,
  width    = 10,
  height   = 8,
  dpi      = 300,
  bg       = "transparent"
)

# =====================================================================
# R SCRIPT: Migration & Average Age Trends with Thinner Lines
# =====================================================================

# 1) INSTALL & LOAD REQUIRED PACKAGES ----
# (Uncomment install.packages(...) if you need to install the packages.)
# install.packages(c("tidyverse", "showtext", "scales", "ggrepel", "giscoR", "tidygeocoder"))

library(tidyverse)   # for data manipulation and ggplot2
library(ggrepel)     # for better text labels (if needed)
library(showtext)    # for custom font support
library(scales)      # for label_comma() and rescale()
library(stringr)     # for string trimming and title case

# 2) REGISTER & LOAD CUSTOM FONTS ----

# Download & register Google fonts
font_add_google(name = "Montserrat", family = "Montserrat")
font_add_google(name = "Poppins",    family = "Poppins")
font_add_google(name = "Space Mono", family = "SpaceMono")

# Register Helvetica (system‐installed) as fallback for captions
# If Helvetica is not available, substitute "Arial" or another sans-serif
#font_add(family = "Helvetica", regular = "Helvetica")

# Tell R/ggplot to use showtext for all future plots
showtext_auto()

# 3) DEFINE COLOR PALETTE ----

type_colors <- c(
  "Tourist"   = "#A80000",  # dark red
  "Capital"   = "#008080",  # teal
  "Ljubljana" = "#D78B00"   # gold
)

# 4) LOAD & PREPARE DATA ----

# Load the raw CSV (one row per Municipality-Year, with variables)
raw <- read_csv("all_data_full.csv")

# (If you have not yet created df_migration_trend or df_age_trend, do so here)

# 4a) MIGRATION TREND DATAFRAME
df_migration_trend <- raw %>%
  filter(Variable == "Migration") %>%
  mutate(
    Municipality = str_trim(Municipality),
    Type = if_else(Municipality == "Ljubljana", "Ljubljana", Type),
    Display_Name = case_when(
      Municipality == "Novo mesto" ~ "Novo mesto",
      TRUE ~ str_to_title(Municipality)
    )
  )

# 4b) AVERAGE AGE TREND DATAFRAME
df_age_trend <- raw %>%
  filter(Variable == "Average Age") %>%
  mutate(
    Municipality = str_trim(Municipality),
    Type = if_else(Municipality == "Ljubljana", "Ljubljana", Type),
    Display_Name = case_when(
      Municipality == "Novo mesto" ~ "Novo mesto",
      TRUE ~ str_to_title(Municipality)
    )
  )

# 5) PLOT MIGRATION TREND WITH THINNER LINES ----

p_migration_trend_custom <- ggplot(df_migration_trend, 
                                   aes(x = Year,
                                       y = Value,
                                       group = Municipality,
                                       colour = Type)) +
  # Thinner lines (size = 0.8) and smaller points (size = 1.5)
  geom_line(size = 0.8, alpha = 0.9) +
  geom_point(size = 1.5) +
  
  # Color palette matching the map/barbell
  scale_colour_manual(
    values = type_colors,
    name   = "Municipality Type"
  ) +
  
  # X-axis ticks every year
  scale_x_continuous(breaks = seq(min(df_migration_trend$Year), 
                                  max(df_migration_trend$Year), 1)) +
  
  # Labels (using custom fonts)
  labs(
    title    = "Net Migration Over Time",
    subtitle = "Per municipality (per 1 000 inhabitants)",
    x        = "Year",
    y        = "Net migration (per 1 000 inhabitants)",
    caption  = "Data source: Statistical Office of Slovenia"
  ) +
  
  # Minimal theme + custom font settings
  theme_minimal(base_size = 12) +
  theme(
    plot.title = element_text(
      family = "SpaceMono", 
      face   = "bold",
      size   = rel(1.3),
      hjust  = 0.5,
      margin = margin(b = 8)
    ),
    plot.subtitle = element_text(
      family = "Montserrat",
      size   = rel(1.0),
      hjust  = 0.5,
      color  = "grey30",
      margin = margin(b = 12)
    ),
    axis.title.x = element_text(
      family = "Poppins", 
      size   = rel(1.0),
      margin = margin(t = 8)
    ),
    axis.title.y = element_text(
      family = "Poppins", 
      size   = rel(1.0),
      margin = margin(r = 8)
    ),
    axis.text.x = element_text(
      family = "Poppins", 
      size   = rel(0.9),
      colour = "black"
    ),
    axis.text.y = element_text(
      family = "Poppins", 
      size   = rel(0.9),
      colour = "black"
    ),
    panel.grid.major.x = element_line(colour = "grey90", size = 0.4),
    panel.grid.major.y = element_line(colour = "grey90", size = 0.4),
    panel.grid.minor   = element_blank(),
    plot.caption = element_text(
      family = "Helvetica",
      size   = rel(0.8),
      hjust  = 1,
      colour = "grey50",
      margin = margin(t = 10)
    ),
    legend.position = "bottom",
    legend.title = element_text(
      family = "Poppins",
      size   = rel(1.0),
      face   = "bold"
    ),
    legend.text = element_text(
      family = "Poppins",
      size   = rel(0.9)
    ),
    plot.margin = margin(20, 20, 20, 20)
  )

# Display the migration‐trend chart
print(p_migration_trend_custom)

# Save it (transparent background)
ggsave(
  filename = "migration_trend_custom_thin.png",
  plot     = p_migration_trend_custom,
  width    = 10,
  height   = 8,
  dpi      = 300,
  bg       = "transparent"
)
ggsave(
  filename = "migration_trend_custom_thin.svg",
  plot     = p_migration_trend_custom,
  width    = 10,
  height   = 8,
  dpi      = 300,
  bg       = "transparent"
)


# 6) PLOT AVERAGE AGE TREND WITH THINNER LINES ----

p_age_trend_custom <- ggplot(df_age_trend,
                             aes(x = Year,
                                 y = Value,
                                 group = Municipality,
                                 colour = Type)) +
  # Thinner lines and smaller points
  geom_line(size = 0.8, alpha = 0.9) +
  geom_point(size = 1.5) +
  
  # Same color scale
  scale_colour_manual(
    values = type_colors,
    name   = "Municipality Type"
  ) +
  
  # X-axis ticks every year
  scale_x_continuous(breaks = seq(min(df_age_trend$Year),
                                  max(df_age_trend$Year),
                                  by = 1)) +
  
  # Labels (custom fonts)
  labs(
    title    = "Average Age of Residents Over Time",
    subtitle = "Per municipality",
    x        = "Year",
    y        = "Average age (years)",
    caption  = "Data source: Statistical Office of Slovenia"
  ) +
  
  # Minimal theme + font settings
  theme_minimal(base_size = 12) +
  theme(
    plot.title = element_text(
      family = "SpaceMono",
      face   = "bold",
      size   = rel(1.3),
      hjust  = 0.5,
      margin = margin(b = 8)
    ),
    plot.subtitle = element_text(
      family = "Montserrat",
      size   = rel(1.0),
      hjust  = 0.5,
      color  = "grey30",
      margin = margin(b = 12)
    ),
    axis.title.x = element_text(
      family = "Poppins",
      size   = rel(1.0),
      margin = margin(t = 8)
    ),
    axis.title.y = element_text(
      family = "Poppins",
      size   = rel(1.0),
      margin = margin(r = 8)
    ),
    axis.text.x = element_text(
      family = "Poppins",
      size   = rel(0.9),
      angle  = 45,
      hjust  = 1,
      colour = "black"
    ),
    axis.text.y = element_text(
      family = "Poppins",
      size   = rel(0.9),
      colour = "black"
    ),
    panel.grid.major.x = element_line(colour = "grey90", size = 0.4),
    panel.grid.major.y = element_line(colour = "grey90", size = 0.4),
    panel.grid.minor   = element_blank(),
    plot.caption = element_text(
      family = "Helvetica",
      size   = rel(0.8),
      hjust  = 1,
      colour = "grey50",
      margin = margin(t = 10)
    ),
    legend.position = "bottom",
    legend.title = element_text(
      family = "Poppins",
      size   = rel(1.0),
      face   = "bold"
    ),
    legend.text = element_text(
      family = "Poppins",
      size   = rel(0.9)
    ),
    plot.margin = margin(20, 20, 20, 20)
  )

# Display the average‐age‐trend chart
print(p_age_trend_custom)

# Save it (transparent background)
ggsave(
  filename = "age_trend_custom_thin.png",
  plot     = p_age_trend_custom,
  width    = 10,
  height   = 8,
  dpi      = 300,
  bg       = "transparent"
)
ggsave(
  filename = "age_trend_custom_thin.svg",
  plot     = p_age_trend_custom,
  width    = 10,
  height   = 8,
  dpi      = 300,
  bg       = "transparent"
)

# =====================================================================
# End of Script
# =====================================================================






