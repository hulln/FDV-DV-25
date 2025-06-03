import pandas as pd
import matplotlib.pyplot as plt
from joypy import joyplot
import seaborn as sns
from scipy.stats import gaussian_kde
import numpy as np

class DataProcessor:
    """
    Handles data loading, cleaning, and value construction.
    """
    def __init__(self, file_path):
        self.file_path = file_path
        self.df = None
        self.df_clean = None

    def load_data(self):
        """Loads data from the specified file path."""
        self.df = pd.read_csv(self.file_path)
        return self

    def clean_data(self, valid_range):
        """Cleans the data based on the specified valid range."""
        self.df_clean = self.df[
            self.df[['imprich', 'iprspot', 'ipgdtim', 'impfun']].apply(lambda x: x.isin(valid_range).all(), axis=1)
        ]
        self.df_clean = self.df_clean[self.df_clean['eisced'].isin(range(1, 8))]
        return self

    def construct_values(self):
        """Constructs 'power_avg' and 'hedonism_avg'."""
        self.df_clean['power_avg'] = self.df_clean[['imprich', 'iprspot']].mean(axis=1)
        self.df_clean['hedonism_avg'] = self.df_clean[['ipgdtim', 'impfun']].mean(axis=1)
        return self

    def apply_education_labels(self, edu_labels, edu_order):
        """Applies education level labels to the dataframe."""
        self.df_clean['edu_label'] = self.df_clean['eisced'].map(edu_labels)
        self.df_clean['edu_label'] = pd.Categorical(self.df_clean['edu_label'], categories=edu_order, ordered=True)
        return self

    def get_cleaned_data(self):
        """Returns the cleaned dataframe."""
        return self.df_clean

class RidgePlotter:
    """
    Handles the creation of enhanced ridge plots.
    """
    def __init__(self, data, column, title, filename, footnote_text, palette_name, subtitle=None, legend=False, legend_label=None):
        self.data = data
        self.column = column
        self.title = title
        self.filename = filename
        self.footnote_text = footnote_text
        self.palette_name = palette_name
        self.subtitle = subtitle
        self.legend = legend
        self.legend_label = legend_label
        self.edu_order = [
            "Primary education",
            "Lower secondary",
            "Upper secondary",
            "Post-secondary vocational",
            "Short-cycle tertiary",
            "Bachelor's or higher"
        ]
        sns.set(style="white", rc={
            "axes.facecolor": "#F5F5F5",
            "axes.edgecolor": "#333333"
        })

    def create_plot(self):
        """Generates and saves the enhanced ridge plot."""
        group_counts = self.data.groupby('edu_label').size()
        labels = [f"{label}\n(n={count:,})" for label, count in zip(group_counts.index, group_counts.values)]

        plt.figure(figsize=(12, 8))
        raw_colors = sns.color_palette(self.palette_name, len(self.edu_order))

        # Create the ridgeplot
        joyplot(
            data=self.data,
            by='edu_label',
            column=self.column,
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
        avg_values = self.data.groupby('edu_label')[self.column].mean().reindex(self.edu_order)
        for ax, (edu_label, avg_val) in zip(axes, avg_values.items()):
            # Extract values for current education level
            subset = self.data[self.data['edu_label'] == edu_label][self.column].dropna()

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
            self.title,
            fontsize=18,
            weight='bold',
            y=0.97,
            x=0.5
        )

        if self.subtitle:
            fig.text(
                0.5, 0.905,
                self.subtitle,
                ha='center',
                fontsize=14,
                style='italic'
            )

        plt.xlabel("Average Score", fontsize=12, labelpad=10, color="#333333")

        if self.legend and self.legend_label:
            handles = [
                plt.Line2D([0], [0], color=self.legend_label['hedonism'], lw=8, label='Hedonism'),
                plt.Line2D([0], [0], color=self.legend_label['power'], lw=8, label='Power')
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
            self.footnote_text.format(len(self.data)),
            wrap=True,
            horizontalalignment='center',
            fontsize=10,
            style='italic'
        )

        plt.subplots_adjust(top=0.88, bottom=0.32)

        plt.savefig(f"assignment_1/output/{self.filename}", bbox_inches='tight', dpi=300, facecolor="#F5F5F5")
        plt.savefig(f"assignment_1/output/{self.filename.replace('.png', '.svg')}", bbox_inches='tight', format='svg', facecolor="#F5F5F5")
        plt.close()

# --- Main script ---
# --- Define constants ---
FILE_PATH = "ESS10-subset.csv"
VALID_RANGE = [1, 2, 3, 4, 5, 6]
EDU_LABELS = {
    1: "Primary education",
    2: "Lower secondary",
    4: "Upper secondary",
    5: "Post-secondary vocational",
    6: "Short-cycle tertiary",
    7: "Bachelor's or higher"
}
EDU_ORDER = [
    "Primary education",
    "Lower secondary",
    "Upper secondary",
    "Post-secondary vocational",
    "Short-cycle tertiary",
    "Bachelor's or higher"
]
FOOTNOTE_POWER = (
    "Source: European Social Survey Round 10 (country: Bulgaria)\n"
    "Power is the average of two items: being rich and getting respect (1 = very much like me, 6 = not like me at all). "
    "(N = {:,})"
)
FOOTNOTE_HEDONISM = (
    "Source: European Social Survey Round 10 (country: Bulgaria)\n"
    "Hedonism is the average of two items: having fun and a good time (1 = very much like me, 6 = not like me at all). "
    "(N = {:,})"
)
TITLE_HEDONISM = "How Education Shapes Attitudes Toward Fun and Pleasure"
SUBTITLE_HEDONISM = "In Bulgaria, higher education is associated with greater emphasis on pleasure."
TITLE_POWER = "How Education Shapes Views on Wealth and Respect"
SUBTITLE_POWER = "In Bulgaria, higher education is slightly associated with greater importance on power."
COMBINED_TITLE = "How Education Shapes Attitudes Toward Fun and Pleasure and Wealth and Respect"
COMBINED_SUBTITLE = "In Bulgaria, higher education tends to be slightly associated with placing more importance on power and greater emphasis on pleasure."
COMBINED_FOOTNOTE = (
    "Source: European Social Survey Round 10 (country: Bulgaria)\n"
    "Hedonism is the average of two items: having fun and a good time. "
    "Power is the average of two items: being rich and getting respect.\n"
    "They are rated on a scale from 1 (very much like me) to 6 (not like me at all). (N = {:,})"
)
LEGEND_COLORS = {
    "hedonism": "#DA627D",
    "power": "#256D85"
}

# --- Data Processing ---
data_processor = DataProcessor(FILE_PATH)
data_processor.load_data().clean_data(VALID_RANGE).construct_values().apply_education_labels(EDU_LABELS, EDU_ORDER)
df_clean = data_processor.get_cleaned_data()

# --- Plotting ---
RidgePlotter(
    df_clean,
    'hedonism_avg',
    TITLE_HEDONISM,
    "2_ridgeline_hedonism_bulgaria.svg",
    FOOTNOTE_HEDONISM,
    palette_name="flare",
    subtitle=SUBTITLE_HEDONISM
).create_plot()

RidgePlotter(
    df_clean,
    'power_avg',
    TITLE_POWER,
    "2_ridgeline_power_bulgaria.svg",
    FOOTNOTE_POWER,
    palette_name="crest",
    subtitle=SUBTITLE_POWER
).create_plot()

RidgePlotter(
    df_clean,
    'hedonism_avg',
    COMBINED_TITLE,
    "2_overlay_ready_hedonism.svg",
    COMBINED_FOOTNOTE,
    palette_name="flare",
    subtitle=COMBINED_SUBTITLE,
    legend=True,
    legend_label=LEGEND_COLORS
).create_plot()

RidgePlotter(
    df_clean,
    'power_avg',
    COMBINED_TITLE,
    "2_overlay_ready_power.svg",
    COMBINED_FOOTNOTE,
    palette_name="crest",
    subtitle=COMBINED_SUBTITLE,
    legend=True,
    legend_label=LEGEND_COLORS
).create_plot()

print("✅ All plots saved successfully!")

# --- END ---