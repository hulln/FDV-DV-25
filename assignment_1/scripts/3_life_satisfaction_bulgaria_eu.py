import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
from matplotlib.lines import Line2D

class DataManager:
    """
    Handles loading, cleaning, and preparing data for plotting.
    """
    def __init__(self, bg_file, eu_file, ess_round_info):
        self.bg_file = bg_file
        self.eu_file = eu_file
        self.ess_round_info = ess_round_info
        self.ess_round_to_year = {k: v[0] for k, v in ess_round_info.items()}
        self.ess_years = sorted(self.ess_round_to_year.values())
        self.df_bg = None
        self.df_eu = None
        self.df_bg_clean = None
        self.df_eu_clean = None
        self.avg_life_bg_full = None
        self.avg_life_eu_full = None

    def load_data(self):
        """Loads data from CSV files."""
        self.df_bg = pd.read_csv(self.bg_file)
        self.df_eu = pd.read_csv(self.eu_file)
        return self

    def prepare_data(self):
        """Maps ESS round to year and cleans the data."""
        self.df_bg['year'] = self.df_bg['essround'].map(self.ess_round_to_year)
        self.df_eu['year'] = self.df_eu['essround'].map(self.ess_round_to_year)

        self.df_bg_clean = self.df_bg[self.df_bg['stflife'].between(0, 10, inclusive='both')].copy()
        self.df_eu_clean = self.df_eu[self.df_eu['stflife'].between(0, 10, inclusive='both')].copy()
        return self

    def aggregate_data(self):
        """Groups data by year and calculates the mean life satisfaction."""
        avg_life_bg = self.df_bg_clean.groupby('year')['stflife'].mean().reset_index()
        avg_life_eu = self.df_eu_clean.groupby('year')['stflife'].mean().reset_index()

        all_years = pd.DataFrame({'year': self.ess_years})
        self.avg_life_bg_full = pd.merge(all_years, avg_life_bg, on='year', how='left')
        self.avg_life_eu_full = pd.merge(all_years, avg_life_eu, on='year', how='left')
        return self

    def get_bulgaria_data(self):
        """Returns the processed Bulgaria data."""
        return self.avg_life_bg_full

    def get_europe_data(self):
        """Returns the processed Europe data."""
        return self.avg_life_eu_full

    def get_total_observations_bg(self):
        """Returns the total number of valid observations for Bulgaria."""
        return len(self.df_bg_clean)

class Plotter:
    """
    Handles the plotting of life satisfaction data.
    """
    def __init__(self, data_manager, title, footnote, color_bg, color_eu):
        self.data_manager = data_manager
        self.title = title
        self.footnote = footnote
        self.color_bg = color_bg
        self.color_eu = color_eu
        sns.set_style("whitegrid")
        self.fig, self.ax = plt.subplots(figsize=(12, 7))

    def create_plot(self):
        """Generates the life satisfaction plot."""
        self._set_suptitle()
        self._plot_data()
        self._add_data_labels()
        self._set_axes_and_ticks()
        self._set_legend()
        self._set_footnote()
        self._remove_spines()
        self._adjust_layout()
        return self

    def _set_suptitle(self):
        """Sets the title of the plot."""
        self.fig.suptitle(
            self.title,
            fontsize=18,
            weight='bold',
            y=0.95,
            x=0.5
        )

    def _plot_data(self):
        """Plots the Bulgaria and Europe data."""
        bg_data = self.data_manager.get_bulgaria_data()
        eu_data = self.data_manager.get_europe_data()

        # Bulgaria as scatter
        self.ax.scatter(bg_data['year'],
                        bg_data['stflife'],
                        color=self.color_bg, edgecolors='white', s=100, linewidth=2,
                        label='Bulgaria', zorder=3)

        # Europe as line
        self.ax.plot(eu_data['year'],
                     eu_data['stflife'],
                     linestyle='--', color=self.color_eu, linewidth=1.5,
                     alpha=0.8, label='European Average', zorder=3)

    def _add_data_labels(self):
        """Adds data labels to the plot."""
        bg_data = self.data_manager.get_bulgaria_data()
        eu_data = self.data_manager.get_europe_data()

        for _, row in bg_data.iterrows():
            if not pd.isna(row['stflife']):
                self.ax.text(row['year'], row['stflife'] + 0.1, f"{row['stflife']:.1f}",
                             ha='center', fontsize=9, color=self.color_bg)

        for _, row in eu_data.iterrows():
            if not pd.isna(row['stflife']):
                self.ax.text(row['year'], row['stflife'] - 0.25, f"{row['stflife']:.1f}",
                             ha='center', fontsize=9, color=self.color_eu)

    def _set_axes_and_ticks(self):
        """Sets the axes, ticks, and grid."""
        ess_years = self.data_manager.ess_years
        self.ax.set_yticks(range(4, 9))
        self.ax.set_xticks(ess_years)
        self.ax.set_xticklabels(ess_years, rotation=0, fontsize=10)
        self.ax.tick_params(axis='y', labelsize=10)
        self.ax.set_ylim(4, 8)
        self.ax.grid(True, alpha=0.3)

    def _set_legend(self):
        """Sets the legend for the plot."""
        legend_elements = [
            Line2D([0], [0],
                   color=self.color_bg, marker='o', markersize=7,
                   markeredgecolor=self.color_bg, markeredgewidth=2,
                   linestyle='None', label='Bulgaria'),
            Line2D([0], [0],
                   color=self.color_eu, linestyle='--', linewidth=1.5,
                   label='European Average')
        ]
        self.ax.legend(
            handles=legend_elements,
            fontsize='11',
            loc='upper center',
            bbox_to_anchor=(0.5, 1.06),
            ncol=2,
            frameon=False
        )

    def _set_footnote(self):
        """Sets the footnote with dynamic N."""
        total_n_bg = self.data_manager.get_total_observations_bg()
        self.fig.text(
            0.5, 0.02,
            self.footnote.format(total_n_bg),
            wrap=True,
            horizontalalignment='center',
            fontsize=10,
            style='italic'
        )

    def _remove_spines(self):
        """Removes the spines from the plot."""
        for spine in self.ax.spines.values():
            spine.set_visible(False)

    def _adjust_layout(self):
        """Adjusts the layout of the plot."""
        self.fig.subplots_adjust(bottom=0.22)

    def save_plot(self, filename):
        """Saves the plot to a file."""
        plt.savefig(filename, dpi=300)

# --- Configuration ---
ESS_ROUND_INFO = {
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
COLOR_BG = '#E69F00'  # Orange
COLOR_EU = '#0072B2'  # Blue
TITLE = 'Life Satisfaction in Bulgaria Across Time'
FOOTNOTE = (
    'Source: European Social Survey (country: Bulgaria)\n'
    'Life satisfaction is rated on a scale from 0 (extremely dissatisfied) to 10 (extremely satisfied). '
    '(N = {:,})\n'
    'Note: Not all countries participated in every survey round. '
    'The European average reflects only the countries that provided data in each respective year. '
    '\nBulgaria is included in the average only for the years it participated.'
)

# --- Main script ---
data_manager = DataManager(
    bg_file="ESS_stflife_bulgaria.csv",
    eu_file="ESS_stflife_europe.csv",
    ess_round_info=ESS_ROUND_INFO
)

data_manager.load_data().prepare_data().aggregate_data()

plotter = Plotter(
    data_manager=data_manager,
    title=TITLE,
    footnote=FOOTNOTE,
    color_bg=COLOR_BG,
    color_eu=COLOR_EU
)

plotter.create_plot().save_plot('assignment_1/3_life_satisfaction_bulgaria_eu.png')

print('✅ Final clean life satisfaction plot saved with dynamic N!')

# --- END ---