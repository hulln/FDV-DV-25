import pandas as pd
import seaborn as sns
import matplotlib.pyplot as plt
from matplotlib.lines import Line2D

# Load the dataset
df = pd.read_csv("ESS10-subset.csv")

# Define the 6 openness-related variables
openness_items = ['ipcrtiv', 'ipgdtim', 'impdiff', 'ipadvnt', 'impfun', 'impfree']

# Filter valid data
valid_df = df[
    (df['agea'] != 999) &
    (df['rlgblg'].isin([1, 2])) &
    df[openness_items].applymap(lambda x: x in range(1, 7)).all(axis=1)
].copy()

# Reverse scale (1 = high openness)
for col in openness_items:
    valid_df[col] = 7 - valid_df[col]

# Compute average openness score
valid_df['openness'] = valid_df[openness_items].mean(axis=1)

# Add readable group
valid_df['religion'] = valid_df['rlgblg'].map({1: 'Religious', 2: 'Non-religious'})

# Get total N
total_n = len(valid_df)

# === COMMON SETTINGS ===
title = "Relationship Between Age and Openness to Change"
subtitle = (
    "Openness to change tends to decrease with age in Bulgaria,\n"
    "with non-religious individuals showing slightly lower openness overall."
)
xlabel = "Age"
ylabel = "Average Openness to Change"
footnote = (
    "Source: European Social Survey Round 10 (country: Bulgaria)\n"
    "Openness score = average agreement with six personal values: creativity, fun,\n"
    "freedom, adventure, trying new things, independence. Higher = more open. (N = {:,})"
)
x_limits = (16, 90)

def plot_version(style_name, palette, linestyle_map, suffix):
    sns.set(style="white", font_scale=1.1)
    fig, ax = plt.subplots(figsize=(12, 8), dpi=150)

    # Regression lines
    for group, color in zip(['Non-religious', 'Religious'], palette):
        linestyle = linestyle_map[group]
        sns.regplot(
            data=valid_df[valid_df['religion'] == group],
            x='agea', y='openness',
            scatter=False, ci=95, ax=ax,
            color=color,
            line_kws={'linewidth': 2, 'linestyle': linestyle, 'label': group}
        )

    # Title and subtitle
    fig.suptitle(title, fontsize=18, weight='bold', y=0.94)
    ax.set_title(subtitle, fontsize=14, style='italic', pad=10)

    # Axis labels
    ax.set_xlabel(xlabel, fontsize=13, labelpad=15)
    ax.set_ylabel(ylabel, fontsize=13, labelpad=15)
    ax.set_xlim(*x_limits)

    # Aesthetic tweaks
    ax.set_axisbelow(True)
    ax.grid(True, linestyle='--', linewidth=0.5, alpha=0.5)
    for spine in ax.spines.values():
        spine.set_visible(False)

    # Legend inside the chart, top right
    legend_handles = [
        Line2D([0], [0], color=palette[0], linewidth=2, linestyle=linestyle_map['Non-religious'], label='Non-religious'),
        Line2D([0], [0], color=palette[1], linewidth=2, linestyle=linestyle_map['Religious'], label='Religious')
    ]
    ax.legend(
        handles=legend_handles,
        fontsize='10',
        loc='upper right',
        bbox_to_anchor=(0.98, 1),
        frameon=False
    )

    # Footnote with total N
    plt.figtext(
        0.5, 0.015,
        footnote.format(total_n),
        wrap=True,
        horizontalalignment='center',
        fontsize=10,
        style='italic'
    )

    # Adjust layout
    plt.subplots_adjust(left=0.12, right=0.92, top=0.84, bottom=0.22)

    # Save
    plt.savefig(f"assignment_1/4_openness_vs_age_by_religion_{suffix}.png", bbox_inches='tight')
    plt.savefig(f"assignment_1/4_openness_vs_age_by_religion_{suffix}.pdf", bbox_inches='tight')
    plt.close()
    print(f"✅ Saved: openness_vs_age_by_religion_{suffix}.png/pdf")

# --- COLOR VERSION ---
plot_version(
    style_name="color",
    palette=["#66c2a5", "#d95f0e"],  # Balanced: greenish + darker orange
    linestyle_map={'Non-religious': (0, (4, 2)), 'Religious': 'solid'},
    suffix="color"
)

# --- BLACK-AND-WHITE VERSION ---
plot_version(
    style_name="bw",
    palette=["#BBBBBB", "black"],
    linestyle_map={'Non-religious': (0, (4, 2)), 'Religious': 'solid'},
    suffix="bw"
)

print('✅ Done!')

# === END OF FILE ===