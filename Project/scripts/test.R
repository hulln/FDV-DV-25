# ===========================================
# DATA PREPARATION & TEST SCRIPT
# ===========================================
# Purpose: 
# - Import raw data files (Excel, TSV, CSV)
# - Perform basic data checks
# - Correct annual salaries → monthly
# - Sanity-check cleaned data
#
# Project structure assumed:
# - data/          (input data files)
# - output/        (plots from main script)
# ===========================================

# PACKAGES ----
library(tidyverse)
library(readxl)
library(readr)

# ===========================================
# 1. Import Net Migration (Excel)
# ===========================================

net_migration <- read_excel("data/selitveni_prirast_2008_2023.xlsx", sheet = "Sheet1")

# Basic check
head(net_migration)

# ===========================================
# 2. Import Full Dataset (TSV)
# ===========================================

df <- read_tsv("data/all_data.tsv")

# Basic checks
glimpse(df)
head(df)
dim(df)

# ===========================================
# 3. Import Full Dataset (CSV) for Salary Fix
# ===========================================

df_all <- read_csv("data/all_data_full.csv") %>% 
  mutate(
    Year = as.integer(Year),       # Ensure Year is integer
    Value = as.numeric(Value)      # Ensure Value is numeric
  )

# ===========================================
# 4. Convert Annual Salary → Monthly
# ===========================================

df_all <- df_all %>%
  mutate(
    Value = if_else(
      Variable == "Annual Salary", 
      Value / 12, 
      Value
    ),
    Variable = if_else(
      Variable == "Annual Salary",
      "Monthly Salary",
      Variable
    ),
    Unit = if_else(
      Variable == "Monthly Salary",
      "EUR/month",
      Unit
    ),
    Value = round(Value, 2)  # Round to 2 decimals
  )

# ===========================================
# 5. Quick Check (Optional)
# Example: View salary for Ljubljana in 2023
# ===========================================

df_all %>%
  filter(Municipality == "Ljubljana", Year == 2023, Variable == "Monthly Salary") %>%
  arrange(desc(Value))

# ===========================================
# END OF SCRIPT
# ===========================================