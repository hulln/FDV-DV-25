import pandas as pd

# Load datasets
df_bg = pd.read_csv("ESS_stflife_bulgaria.csv")
df_eu = pd.read_csv("ESS_stflife_europe.csv")

# ESS round to year mapping
ess_round_to_year = {
    1: 2002, 2: 2004, 3: 2006, 4: 2008, 5: 2010,
    6: 2012, 7: 2014, 8: 2016, 9: 2018, 10: 2020, 11: 2022
}

# Map ESS round to year
df_bg['year'] = df_bg['essround'].map(ess_round_to_year)
df_eu['year'] = df_eu['essround'].map(ess_round_to_year)

# Filter valid life satisfaction values (0-10)
df_bg_clean = df_bg[df_bg['stflife'].between(0, 10)]
df_eu_clean = df_eu[df_eu['stflife'].between(0, 10)]

# Calculate averages
avg_bg = df_bg_clean.groupby('year')['stflife'].mean()
avg_eu = df_eu_clean.groupby('year')['stflife'].mean()

# Combine into one DataFrame for easy comparison
comparison = pd.DataFrame({
    'Bulgaria': avg_bg,
    'Europe Average': avg_eu
}).round(2)

# Display results
print("Average Life Satisfaction by Year:")
print(comparison)
