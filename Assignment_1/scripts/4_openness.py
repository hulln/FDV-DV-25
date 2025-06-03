import pandas as pd
import seaborn as sns
import matplotlib.pyplot as plt
from matplotlib.lines import Line2D

class DataProcessor:
    """
    Handles data loading, cleaning, and feature engineering.
    """
    def __init__(self, file_path, openness_items):
        self.file_path = file_path
        self.openness_items = openness_items
        self.df = None
        self.valid_df = None

    def load_data(self):
        """Loads the dataset from the specified file path."""
        self.df = pd.read_csv(self.file_path)
        return self

    def filter_data(self):
        """Filters the data based on specified criteria."""
        self.valid_df = self.df[
            (self.df['agea'] != 999) &
            (self.df['rlgblg'].isin([1, 2])) &
            self.df[self.openness_items].applymap(lambda x: x in range(1, 7)).all(axis=1)
        ].copy()
        return self

    def reverse_scale(self):
        """Reverses the scale of the openness items."""
        for col in self.openness_items:
            self.valid_df[col] = 7 - self.valid_df[col]
        return self

    def compute_openness(self):
        """Computes the average openness score."""
        self.valid_df['openness'] = self.valid_df[self.openness_items].mean(axis=1)
        return self

    def add_religion_label(self):
        """Adds a readable religion label."""
        self.valid_df['religion'] = self.valid_df['rlgblg'].map({1: 'Religious', 2: 'Non-religious'})
        return self

    def get_processed_data(self):
        """Returns the processed dataframe."""
        return self.valid_df

    def get_total_observations(self):
        """Returns the total number of valid observations."""
        return len(self.valid_df)

class Plotter:
    """
    Handles the plotting of data using matplotlib and seaborn.
    """
    def __init__(self, data, title, subtitle, xlabel, ylabel, footnote, x_limits):
        self.data = data
        self.title = title
        self.subtitle = subtitle
        self.xlabel = xlabel
        self.ylabel = ylabel
        self.footnote = footnote
        self.x_limits = x_limits

    def plot_version(self, style_name, palette, linestyle_map, suffix):
        """Generates and saves the plot with specified styles."""
        sns.set(style="white", font_scale=1.1)
        fig, ax = plt.subplots(figsize=(12, 8), dpi=150)

        # Regression lines
        for group, color in zip(['Non-religious', 'Religious'], palette):
            linestyle = linestyle_map[group]
            sns.regplot(
                data=self.data[self.data['religion'] == group],
                x='agea', y='openness',
                scatter=False, ci=95, ax=ax,
                color=color,
                line_kws={'linewidth': 2, 'linestyle': linestyle, 'label': group}
            )

        # Title and subtitle
        fig.suptitle(self.title, fontsize=18, weight='bold', y=0.94)
        ax.set_title(self.subtitle, fontsize=14, style='italic', pad=10)

        # Axis labels
        ax.set_xlabel(self.xlabel, fontsize=13, labelpad=15)
        ax.set_ylabel(self.ylabel, fontsize=13, labelpad=15)
        ax.set_xlim(*self.x_limits)

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
            self.footnote.format(len(self.data)),
            wrap=True,
            horizontalalignment='center',
            fontsize=10,
            style='italic'
        )

        # Adjust layout
        plt.subplots_adjust(left=0.12, right=0.92, top=0.84, bottom=0.22)

        # Save
        plt.savefig(f"assignment_1/output/4_openness_vs_age_by_religion_{suffix}.png", bbox_inches='tight')
        plt.savefig(f"assignment_1/output/4_openness_vs_age_by_religion_{suffix}.pdf", bbox_inches='tight')
        plt.close()

# --- Configuration ---
FILE_PATH = "ESS10-subset.csv"
OPENNESS_ITEMS = ['ipcrtiv', 'ipgdtim', 'impdiff', 'ipadvnt', 'impfun', 'impfree']
TITLE = "Relationship Between Age and Openness to Change"
SUBTITLE = (
    "Openness to change tends to decrease with age in Bulgaria,\n"
    "with non-religious individuals showing slightly lower openness overall."
)
XLABEL = "Age"
YLABEL = "Average Openness to Change"
FOOTNOTE = (
    "Source: European Social Survey Round 10 (country: Bulgaria)\n"
    "Openness score = average agreement with six personal values: creativity, fun,\n"
    "freedom, adventure, trying new things, independence. Higher = more open. (N = {:,})"
)
X_LIMITS = (16, 90)

# --- Main script ---
data_processor = DataProcessor(FILE_PATH, OPENNESS_ITEMS)
data_processor.load_data().filter_data().reverse_scale().compute_openness().add_religion_label()
valid_df = data_processor.get_processed_data()

plotter = Plotter(valid_df, TITLE, SUBTITLE, XLABEL, YLABEL, FOOTNOTE, X_LIMITS)

# --- COLOR VERSION ---
plotter.plot_version(
    style_name="color",
    palette=["#66c2a5", "#d95f0e"],  # Balanced: greenish + darker orange
    linestyle_map={'Non-religious': (0, (4, 2)), 'Religious': 'solid'},
    suffix="color"
)

# --- BLACK-AND-WHITE VERSION ---
plotter.plot_version(
    style_name="bw",
    palette=["#BBBBBB", "black"],
    linestyle_map={'Non-religious': (0, (4, 2)), 'Religious': 'solid'},
    suffix="bw"
)

print('✅ Openness plots saved!')

# --- END ---