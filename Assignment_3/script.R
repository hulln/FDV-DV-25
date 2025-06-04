library(tidyverse)
library(haven)
library(GGally)
library(factoextra)
library(cluster)
library(NbClust)
library(fmsb)

# STEP A: DATA PREPARATION ----

df <- read_sav("data/ESS9e03_2.sav") %>%
  filter(cntry == "BG")

main_vars <- c("ipcrtiv", "impfree", "impdiff", "ipadvnt", "ipgdtim", 
               "impfun", "impsafe", "ipstrgv", "ipfrule", "ipbhprp", 
               "ipmodst", "imptrad")

df_main <- df %>% select(all_of(main_vars))
sapply(df[main_vars], function(x) attr(x, "label"))

# Boxplot to explore outliers ----
ggplot(df_main %>% pivot_longer(everything(), names_to = "variable", values_to = "value"),
       aes(x = variable, y = value)) +
  geom_boxplot() +
  theme_minimal() +
  labs(title = "Boxplots of Schwartz Values (Outlier Check)",
       x = "Variable", y = "Value") +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

# Save boxplot
ggsave("output/stepA_boxplots_outliers.png", width = 8, height = 5)

# Missing data summary
summary_counts <- df_main %>%
  summarise(across(everything(), list(valid = ~sum(!is.na(.)), missing = ~sum(is.na(.))))) %>%
  pivot_longer(everything(), names_to = c("variable", ".value"), names_sep = "_")

df_main_clean <- df_main %>% drop_na()

# STEP B: CORRELATION PATTERNS ----

cor_matrix <- cor(df_main_clean, use = "pairwise.complete.obs")
round(cor_matrix, 2)

ggcorr(df_main_clean, label = TRUE, label_alpha = TRUE, hjust = 0.8)
ggsave("output/stepB_correlation_matrix.png", width = 6, height = 6)


# STEP C: PCA PROJECTION ----

df_scaled <- scale(df_main_clean)
pca_result <- prcomp(df_scaled)
summary(pca_result)

fviz_pca_biplot(pca_result, geom.ind = "point", repel = TRUE, col.var = "black",
                title = "PCA Biplot - Schwartz Values (Bulgaria)")

ggsave("output/stepC_pca_biplot.png", width = 7, height = 6)

# Prepare PCA plot dataframe with demographics

df_bg <- df %>% filter(cntry == "BG") %>% mutate(row_id = row_number())

df_main_clean <- df_main_clean %>% mutate(row_id = df_bg$row_id[complete.cases(df_main)])

pca_coords <- as.data.frame(pca_result$x) %>% select(PC1, PC2)

df_pca_plot <- df_main_clean %>%
  bind_cols(pca_coords) %>%
  left_join(df_bg %>% select(row_id, gndr, agea, eduyrs), by = "row_id") %>%
  mutate(agea_num = as.numeric(agea))

# PCA plots colored by demographics

df_pca_plot <- df_pca_plot %>%
  mutate(gndr_label = factor(gndr, levels = c(1, 2), labels = c("Male", "Female")))

ggplot(df_pca_plot, aes(PC1, PC2, color = gndr_label)) +
  geom_point(alpha = 0.7) +
  theme_minimal() +
  labs(title = "PCA Projection Colored by Gender", color = "Gender")

ggsave("output/stepC_pca_gender.png", width = 7, height = 6)

ggplot(df_pca_plot, aes(PC1, PC2, color = agea_num)) +
  geom_point(alpha = 0.7) +
  scale_color_viridis_c() +
  theme_minimal() +
  labs(title = "PCA Projection Colored by Age", color = "Age")

ggsave("output/stepC_pca_age.png", width = 7, height = 6)

cor(df_pca_plot$agea_num, df_pca_plot$PC1, use = "complete.obs")
cor(df_pca_plot$agea_num, df_pca_plot$PC2, use = "complete.obs")

# STEP D: CLUSTERING ----

df_cluster <- df_scaled

fviz_nbclust(df_cluster, kmeans, method = "wss") +
  labs(title = "Elbow Method - Optimal Number of Clusters")

ggsave("output/stepD_elbow_method.png", width = 6, height = 5)

set.seed(123)
kmeans_result <- kmeans(df_cluster, centers = 3, nstart = 25)

df_pca_plot <- df_pca_plot %>%
  mutate(cluster = as.factor(kmeans_result$cluster))

ggplot(df_pca_plot, aes(PC1, PC2, color = cluster)) +
  geom_point(alpha = 0.7) +
  theme_minimal() +
  labs(title = "PCA Projection Colored by Cluster", color = "Cluster")

ggsave("output/stepD_pca_clusters.png", width = 7, height = 6)

# STEP E: PROFILE PLOT WITH CLUSTERS ----

# Consistent cluster name mapping (based on profile analysis!)
cluster_name_map <- c("1" = "Open Explorers", "2" = "Low Engagers", "3" = "Thrill Seekers")

# Consistent cluster colors — we now match names correctly to desired colors
cluster_colors <- c("Low Engagers" = "blue", 
                    "Open Explorers" = "green", 
                    "Thrill Seekers" = "red")

ordered_vars <- c("ipcrtiv", "impfree", "impdiff", "ipadvnt", "ipgdtim", "impfun",
                  "impsafe", "ipstrgv", "ipfrule", "ipbhprp", "ipmodst", "imptrad")

df_profile <- df_main_clean %>%
  mutate(cluster = as.factor(kmeans_result$cluster),
         cluster_name = cluster_name_map[cluster]) %>%
  pivot_longer(cols = all_of(main_vars), names_to = "variable", values_to = "value")

var_labels <- c(
  ipcrtiv = "Creativity",
  impfree = "Freedom",
  impdiff = "Curiosity",
  ipadvnt = "Adventure",
  ipgdtim = "Enjoying Life",
  impfun  = "Fun",
  impsafe = "Safety",
  ipstrgv = "Strong Government",
  ipfrule = "Obeying Rules",
  ipbhprp = "Behaving Properly",
  ipmodst = "Modesty",
  imptrad = "Tradition"
)

ggplot(df_profile, aes(factor(variable, levels = ordered_vars), value, color = cluster_name, group = cluster_name)) +
  stat_summary(fun = mean, geom = "line", size = 1.2) +
  stat_summary(fun = mean, geom = "point", size = 2) +
  scale_color_manual(values = cluster_colors) +
  theme_minimal() +
  labs(title = "Average Schwartz Values per Cluster (Ordered)",
       y = "Mean Value", x = "Value", color = "Cluster") +
  scale_x_discrete(labels = var_labels) +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

ggsave("output/stepE_profile_plot_clusters.png", width = 8, height = 5)

# STEP F: PCA SCATTERPLOT WITH CLUSTERS ----

df_pca_plot <- df_pca_plot %>%
  mutate(cluster_name = cluster_name_map[cluster])

ggplot(df_pca_plot, aes(PC1, PC2, color = cluster_name)) +
  geom_point(alpha = 0.7) +
  scale_color_manual(values = cluster_colors) +
  theme_minimal() +
  labs(title = "PCA Projection Colored by Cluster", color = "Cluster")

ggsave("output/stepF_pca_scatter_clusters.png", width = 7, height = 6)

# STEP G: RADAR CHART ----

# Update correct cluster_name_map after your analysis
cluster_name_map <- c(
  "1" = "Open Explorers",
  "2" = "Low Engagers",
  "3" = "Thrill Seekers"
)

# Cluster colors (keep same as before)
cluster_colors <- c("Low Engagers" = "blue", 
                    "Open Explorers" = "green", 
                    "Thrill Seekers" = "red")

# Calculate means
cluster_means <- df_main_clean %>%
  mutate(cluster = kmeans_result$cluster,
         cluster_name = cluster_name_map[as.character(cluster)]) %>%
  group_by(cluster_name) %>%
  summarise(across(all_of(main_vars), mean)) %>%
  arrange(factor(cluster_name, levels = c("Low Engagers", "Open Explorers", "Thrill Seekers")))

# Prepare radar data
max_values <- rep(5, length(main_vars))  
min_values <- rep(1, length(main_vars))  

radar_data <- rbind(max_values, min_values, cluster_means[,-1])
colnames(radar_data) <- var_labels[colnames(radar_data)]
rownames(radar_data) <- c("Max", "Min", cluster_means$cluster_name)

# Plot to screen
radarchart(radar_data, axistype = 1,
           pcol = cluster_colors[rownames(radar_data)[3:5]],
           plwd = 3, plty = 1,
           title = "Average Schwartz Values per Cluster")

legend("topright", legend = rownames(radar_data)[3:5], 
       col = cluster_colors[rownames(radar_data)[3:5]], lwd = 3)

# Save as PNG
png("output/stepG_radar_chart.png", width = 800, height = 600)
radarchart(radar_data, axistype = 1,
           pcol = cluster_colors[rownames(radar_data)[3:5]],
           plwd = 3, plty = 1,
           title = "Average Schwartz Values per Cluster")
legend("topright", legend = rownames(radar_data)[3:5], 
       col = cluster_colors[rownames(radar_data)[3:5]], lwd = 3)
dev.off()
