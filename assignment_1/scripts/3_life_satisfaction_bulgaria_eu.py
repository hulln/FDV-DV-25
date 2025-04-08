import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
from matplotlib.lines import Line2D

# --- Load datasets ---
df_bg = pd.read_csv("ESS_stflife_bulgaria.csv")
df_eu = pd.read_csv("ESS_stflife_europe.csv")

# --- ESS round to year and participation info for Bulgaria ---
ess_round_info = {
    1: (2002, False),
    2: (2004, False),
    3: (2006, True),
    4: (2008, True),
    5: (2010, True),
    6: (2012, True),
    7: (2014, False),
    8: (2016, False),
    9: (2018, True),
    10: (2020, True),
    11: (2022, False)
}
ess_round_to_year = {k: v[0] for k, v in ess_round_info.items()}
participation_status = {v[0]: v[1] for k, v in ess_round_info.items()}
ess_years = sorted(ess_round_to_year.values())

# --- Prepare datasets ---
df_bg['year'] = df_bg['essround'].map(ess_round_to_year)
df_eu['year'] = df_eu['essround'].map(ess_round_to_year)

df_bg_clean = df_bg[df_bg['stflife'].between(0, 10, inclusive='both')].copy()
df_eu_clean = df_eu[df_eu['stflife'].between(0, 10, inclusive='both')].copy()

# --- Count valid observations for Bulgaria ---
total_n_bg = len(df_bg_clean)

avg_life_bg = df_bg_clean.groupby('year')['stflife'].mean().reset_index()
avg_life_eu = df_eu_clean.groupby('year')['stflife'].mean().reset_index()

all_years = pd.DataFrame({'year': ess_years})
avg_life_bg_full = pd.merge(all_years, avg_life_bg, on='year', how='left')
avg_life_eu_full = pd.merge(all_years, avg_life_eu, on='year', how='left')

# --- Plot ---
sns.set_style("whitegrid")
fig, ax = plt.subplots(figsize=(12, 7))

# Colors
color_bg = '#E69F00'  # Orange
color_eu = '#0072B2'  # Blue

# Suptitle
fig.suptitle(
    ' Life Satisfaction in Bulgaria Across Time',
    fontsize=18,
    weight='bold',
    y=0.95,
    x=0.5
)

# Bulgaria as scatter
ax.scatter(avg_life_bg_full['year'], 
           avg_life_bg_full['stflife'], 
           color=color_bg, edgecolors='white', s=100, linewidth=2,
           label='Bulgaria', zorder=3)

# Europe as line
ax.plot(avg_life_eu_full['year'], 
        avg_life_eu_full['stflife'], 
        linestyle='--', color=color_eu, linewidth=1.5,
        alpha=0.8, label='European Average', zorder=3)

# Data labels
for _, row in avg_life_bg_full.iterrows():
    if not pd.isna(row['stflife']):
        ax.text(row['year'], row['stflife'] + 0.1, f"{row['stflife']:.1f}",
                ha='center', fontsize=9, color=color_bg)

for _, row in avg_life_eu_full.iterrows():
    if not pd.isna(row['stflife']):
        ax.text(row['year'], row['stflife'] - 0.25, f"{row['stflife']:.1f}",
                ha='center', fontsize=9, color=color_eu)

# Axes and ticks
ax.set_yticks(range(4, 9))
ax.set_xticks(ess_years)
ax.set_xticklabels(ess_years, rotation=0, fontsize=10)
ax.tick_params(axis='y', labelsize=10)
ax.set_ylim(4, 8)
ax.grid(True, alpha=0.3)

# Legend
legend_elements = [
    Line2D([0], [0],
           color=color_bg, marker='o', markersize=7,
           markeredgecolor=color_bg, markeredgewidth=2,
           linestyle='None', label='Bulgaria'),
    Line2D([0], [0],
           color=color_eu, linestyle='--', linewidth=1.5,
           label='European Average')
]
ax.legend(
    handles=legend_elements,
    fontsize='11',
    loc='upper center',
    bbox_to_anchor=(0.5, 1.06),
    ncol=2,
    frameon=False
)

# Adjust layout
fig.subplots_adjust(bottom=0.22)

# Footnote with dynamic N
plt.figtext(
    0.5, 0.02,
    f'Source: European Social Survey (country: Bulgaria)\n'
    f'Life satisfaction is rated on a scale from 0 (extremely dissatisfied) to 10 (extremely satisfied). '
    f'(N = {total_n_bg:,})\n'
    'Note: Not all countries participated in every survey round. '
    'The European average reflects only the countries that provided data in each respective year. '
    '\nBulgaria is included in the average only for the years it participated.',
    wrap=True,
    horizontalalignment='center',
    fontsize=10,
    style='italic'
)

# Remove spines
for spine in ax.spines.values():
    spine.set_visible(False)

# Save and show
plt.savefig('assignment_1/3_life_satisfaction_bulgaria_eu.png', dpi=300)
print('✅ Final clean life satisfaction plot saved with dynamic N!')

# --- END ---