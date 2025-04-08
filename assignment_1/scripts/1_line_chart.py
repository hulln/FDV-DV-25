import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns

# Load the dataset
file_path = "ESS10-subset.csv"
df = pd.read_csv(file_path)

# Extract relevant variables
df_chart = df[['stflife', 'rlgblg', 'sclmeet']].copy()

# --- Data Cleaning ---
df_chart['stflife'] = df_chart['stflife'].apply(lambda x: x if 0 <= x <= 10 else None)
df_chart['religious'] = df_chart['rlgblg'].apply(lambda x: 'Religious' if x == 1 else 'Non-religious' if x == 2 else None)
df_chart = df_chart[df_chart['sclmeet'].between(1, 7)]
df_chart = df_chart.dropna(subset=['stflife', 'religious'])

# --- Count valid observations ---
total_n = len(df_chart)

# --- Data Aggregation ---
grouped = df_chart.groupby(['religious', 'sclmeet'])['stflife'].mean().reset_index()

# --- Plotting ---
sns.set(style="white", font_scale=1.1)
fig = plt.figure(figsize=(12, 8), dpi=150)

# Lineplot with palette and style
palette = sns.color_palette("Set2", 2)
ax = sns.lineplot(
    data=grouped,
    x='sclmeet',
    y='stflife',
    hue='religious',
    style='religious',
    style_order=['Religious', 'Non-religious'],
    dashes={
        'Religious': '',            # solid
        'Non-religious': (1, 2)     # dotted: 1px line, 2px space
    },
    palette=palette,
    linewidth=2,
    clip_on=False
)

# Remove spines and add subtle grid lines
sns.despine(top=True, right=True, left=True, bottom=True)
plt.grid(True, axis='both', linestyle='--', linewidth=0.5, alpha=0.5)

# Titles and axis labels
fig.suptitle(
    'How Religious Belief and Socializing Affect Life Satisfaction',
    fontsize=18,
    weight='bold',
    y=0.95
)

plt.title(
    'Life satisfaction in Bulgaria tends to increase with more frequent socializing,\n'
    'especially among religious individuals.',
    fontsize=14,
    style='italic',
    pad=5
)

plt.xlabel('Frequency of Socializing', fontsize=13, labelpad=20)
plt.ylabel('Average Life Satisfaction', fontsize=13, labelpad=20)

# X-axis tick labels
plt.xticks(
    ticks=range(1, 8),
    labels=[
        'Never',
        'Less than\nonce a month',
        'Once\na month',
        'Several\ntimes\na month',
        'Once\na week',
        'Several\ntimes\na week',
        'Every\nday'
    ],
    rotation=0,
    ha='center'
)

plt.xlim(0.8, 7.2)

# Legend
plt.legend(
    fontsize='10',
    loc='upper left',
    bbox_to_anchor=(0.02, 0.98),
    frameon=False
)

# Footnote with dynamic N
plt.figtext(
    0.5, 0.02,
    f'Source: European Social Survey Round 10 (country: Bulgaria)\n'
    f'Life satisfaction is rated on a scale from 0 (extremely dissatisfied) to 10 (extremely satisfied). (N = {total_n:,})',
    wrap=True,
    horizontalalignment='center',
    fontsize=10,
    style='italic'
)

# Adjust layout
plt.subplots_adjust(left=0.15, right=0.90, top=0.85, bottom=0.25)

# Save and show
plt.savefig('assignment_1/1_line_chart.png', bbox_inches='tight')
plt.show()
plt.close()

print('✅ Line chart with dynamic N saved!')

# --- END ---