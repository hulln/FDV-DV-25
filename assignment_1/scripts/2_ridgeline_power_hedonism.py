import pandas as pd
import matplotlib.pyplot as plt
from joypy import joyplot
import seaborn as sns
from scipy.stats import gaussian_kde
import numpy as np

# --- Load dataset ---
df = pd.read_csv("ESS10-subset.csv")

# --- Data Cleaning ---
valid_range = [1, 2, 3, 4, 5, 6]
df_clean = df[
    df[['imprich', 'iprspot', 'ipgdtim', 'impfun']].apply(lambda x: x.isin(valid_range).all(), axis=1)
]
df_clean = df_clean[df_clean['eisced'].isin(range(1, 8))]

# --- Value Construction ---
df_clean['power_avg'] = df_clean[['imprich', 'iprspot']].mean(axis=1)
df_clean['hedonism_avg'] = df_clean[['ipgdtim', 'impfun']].mean(axis=1)

# --- Education Level Labels ---
edu_labels = {
    1: "Primary education",
    2: "Lower secondary",
    4: "Upper secondary",
    5: "Post-secondary vocational",
    6: "Short-cycle tertiary",
    7: "Bachelor's or higher"
}
df_clean['edu_label'] = df_clean['eisced'].map(edu_labels)

edu_order = [
    "Primary education",
    "Lower secondary",
    "Upper secondary",
    "Post-secondary vocational",
    "Short-cycle tertiary",
    "Bachelor's or higher"
]
df_clean['edu_label'] = pd.Categorical(df_clean['edu_label'], categories=edu_order, ordered=True)

# --- Visual Style ---
sns.set(style="white", rc={
    "axes.facecolor": "#F5F5F5",
    "axes.edgecolor": "#333333"
})

# --- General Ridgeplot Function ---
def create_enhanced_ridgeplot(data, column, title, filename, footnote_text, palette_name, subtitle=None, legend=False, legend_label=None):
    group_counts = data.groupby('edu_label').size()
    labels = [f"{label}\n(n={count:,})" for label, count in zip(group_counts.index, group_counts.values)]

    plt.figure(figsize=(12, 8))
    raw_colors = sns.color_palette(palette_name, len(edu_order))

    # Create the ridgeplot
    joyplot(
        data=data,
        by='edu_label',
        column=column,
        kind='kde',
        overlap=0.75,
        linewidth=1.2,
        linecolor="white",
        color=raw_colors,
        fade=True,
        labels=labels,
        figsize=(12, 8),
        grid=False,
        xlabelsize=12,
        ylabelsize=11,
        bw_method=0.25,
        alpha=0.85
    )

    # Get current figure and axes
    fig = plt.gcf()
    axes = fig.axes

    # Calculate and draw average lines for each education level
    avg_values = data.groupby('edu_label')[column].mean().reindex(edu_order)
    for ax, (edu_label, avg_val) in zip(axes, avg_values.items()):
        # Extract values for current education level
        subset = data[data['edu_label'] == edu_label][column].dropna()

        # Calculate KDE
        kde = gaussian_kde(subset, bw_method=0.25)
        height = kde(avg_val)[0]  # KDE value at mean

        # Draw short vertical average line
        ax.plot(
            [avg_val, avg_val],
            [0, height],
            color='black',
            linestyle='--',
            linewidth=1.3,
            alpha=0.9,
            zorder=10
        )

        # Add label in the vertical center of the line
        ax.text(
            avg_val + 0.05,
            height / 2,
            f"{avg_val:.2f}",
            color='black',
            fontsize=9,
            rotation=90,
            va='center',
            ha='left',
            zorder=11
        )

    # Titles and subtitles
    fig.suptitle(
        title,
        fontsize=18,
        weight='bold',
        y=0.97,
        x=0.5
    )

    if subtitle:
        fig.text(
            0.5, 0.905,
            subtitle,
            ha='center',
            fontsize=14,
            style='italic'
        )

    plt.xlabel("Average Score", fontsize=12, labelpad=10, color="#333333")

    if legend and legend_label:
        handles = [
            plt.Line2D([0], [0], color=legend_label['hedonism'], lw=8, label='Hedonism'),
            plt.Line2D([0], [0], color=legend_label['power'], lw=8, label='Power')
        ]
        fig.legend(
            handles=handles,
            loc='lower center',
            bbox_to_anchor=(0.5, 0.16),
            ncol=2,
            frameon=False,
            fontsize=11
        )

    plt.figtext(
        0.5, 0.06,
        footnote_text.format(len(data)),
        wrap=True,
        horizontalalignment='center',
        fontsize=10,
        style='italic'
    )

    plt.subplots_adjust(top=0.88, bottom=0.32)

    plt.savefig(f"assignment_1/{filename}", bbox_inches='tight', dpi=300, facecolor="#F5F5F5")
    plt.savefig(f"assignment_1/{filename.replace('.png', '.svg')}", bbox_inches='tight', format='svg', facecolor="#F5F5F5")
    plt.close()


# --- Footnotes ---
footnote_power = (
    "Source: European Social Survey Round 10 (country: Bulgaria)\n"
    "Power is the average of two items: being rich and getting respect (1 = very much like me, 6 = not like me at all). "
    "(N = {:,})"
)

footnote_hedonism = (
    "Source: European Social Survey Round 10 (country: Bulgaria)\n"
    "Hedonism is the average of two items: having fun and a good time (1 = very much like me, 6 = not like me at all). "
    "(N = {:,})"
)

# --- Titles and Subtitles ---
title_hedonism = "How Education Shapes Attitudes Toward Fun and Pleasure"
subtitle_hedonism = "In Bulgaria, higher education is associated with greater emphasis on pleasure." 

title_power = "How Education Shapes Views on Wealth and Respect"
subtitle_power = "In Bulgaria, higher education is slightly associated with greater importance on power."

combined_title = "How Education Shapes Attitudes Toward Fun and Pleasure and Wealth and Respect"
combined_subtitle = "In Bulgaria, higher education tends to be slightly associated with placing more importance on power and greater emphasis on pleasure." 

combined_footnote = (
    "Source: European Social Survey Round 10 (country: Bulgaria)\n"
    "Hedonism is the average of two items: having fun and a good time. "
    "Power is the average of two items: being rich and getting respect.\n"
    "They are rated on a scale from 1 (very much like me) to 6 (not like me at all). (N = {:,})"
)

legend_colors = {
    "hedonism": "#DA627D",
    "power": "#256D85"
}

# --- Create all plots ---
create_enhanced_ridgeplot(
    df_clean,
    'hedonism_avg',
    title_hedonism,
    "2_ridgeline_hedonism_bulgaria.svg",
    footnote_hedonism,
    palette_name="flare",
    subtitle=subtitle_hedonism
)

create_enhanced_ridgeplot(
    df_clean,
    'power_avg',
    title_power,
    "2_ridgeline_power_bulgaria.svg",
    footnote_power,
    palette_name="crest",
    subtitle=subtitle_power
)

create_enhanced_ridgeplot(
    df_clean,
    'hedonism_avg',
    combined_title,
    "2_overlay_ready_hedonism.svg",
    combined_footnote,
    palette_name="flare",
    subtitle=combined_subtitle,
    legend=True,
    legend_label=legend_colors
)

create_enhanced_ridgeplot(
    df_clean,
    'power_avg',
    combined_title,
    "2_overlay_ready_power.svg",
    combined_footnote,
    palette_name="crest",
    subtitle=combined_subtitle,
    legend=True,
    legend_label=legend_colors
)

print("✅ All plots (individual + overlay-ready with subtitles) created successfully!")
