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
grouped = df_chart.groupby(['sclmeet', 'religious'])['stflife'].mean().reset_index()
means = df_chart.groupby('religious')['stflife'].mean().to_dict()

# X-axis labels
x_labels = [
    'Never',
    'Less than\nonce a month',
    'Once\na month',
    'Several\ntimes\na month',
    'Once\na week',
    'Several\ntimes\na week',
    'Every\nday'
]

# --- Plotting ---
sns.set(style="white", font_scale=1.1)
plt.figure(figsize=(12, 8), dpi=150)

palette = sns.color_palette("Set2", 2)
ax = sns.barplot(
    data=grouped,
    x='sclmeet',
    y='stflife',
    hue='religious',
    palette=palette,
    width=0.7
)

# Remove chart borders (spines)
sns.despine(top=True, right=True, left=True, bottom=True)

# Remove grid lines
plt.grid(False)

# Add mean lines
for rel, avg in means.items():
    color = palette[0] if rel == "Religious" else palette[1]
    ax.axhline(
        y=avg,
        linestyle='--',
        color=color,
        linewidth=1.2,
        alpha=0.9,
        zorder=5
    )

# Titles and labels
fig = plt.gcf()
fig.suptitle(
    'How Religious Belief and Socializing Affect Life Satisfaction',
    fontsize=18,
    weight='bold',
    y=0.95,
    x=0.5
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

plt.xticks(
    ticks=range(0, 7),
    labels=x_labels,
    rotation=0,
    ha='center'
)
plt.yticks(range(0, 11))
plt.ylim(0, 10)

# Clean legend
handles, labels = ax.get_legend_handles_labels()
bar_handles = handles[:2]
bar_labels = labels[:2]

plt.legend(
    handles=bar_handles,
    labels=bar_labels,
    title=False,
    title_fontsize='13',
    fontsize='11',
    loc='upper left',
    frameon=False,
    fancybox=True,
    borderpad=1
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
plt.savefig('assignment_1/1_bar_chart.png', bbox_inches='tight')
plt.show()
plt.close()

print('✅ Final clean bar chart saved with dynamic N!')

# --- END ---