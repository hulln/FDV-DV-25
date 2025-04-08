import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns

class DataProcessor:
    """
    Handles data loading, cleaning, and aggregation.
    """
    def __init__(self, file_path):
        self.file_path = file_path
        self.df = None

    def load_data(self):
        """
        Loads data from the specified file path.
        """
        self.df = pd.read_csv(self.file_path)
        return self

    def extract_variables(self, columns):
        """
        Extracts specified columns from the dataframe.
        """
        self.df_chart = self.df[columns].copy()
        return self

    def clean_data(self):
        """
        Cleans the data by applying filters and handling missing values.
        """
        self.df_chart['stflife'] = self.df_chart['stflife'].apply(lambda x: x if 0 <= x <= 10 else None)
        self.df_chart['religious'] = self.df_chart['rlgblg'].apply(lambda x: 'Religious' if x == 1 else 'Non-religious' if x == 2 else None)
        self.df_chart = self.df_chart[self.df_chart['sclmeet'].between(1, 7)]
        self.df_chart = self.df_chart.dropna(subset=['stflife', 'religious'])
        return self

    def aggregate_data(self):
        """
        Aggregates the data to calculate means for plotting.
        """
        self.grouped = self.df_chart.groupby(['sclmeet', 'religious'])['stflife'].mean().reset_index()
        self.means = self.df_chart.groupby('religious')['stflife'].mean().to_dict()
        return self

    def get_total_observations(self):
        """
        Counts and returns the total number of valid observations.
        """
        return len(self.df_chart)

class Plotter:
    """
    Handles the plotting of data using matplotlib and seaborn.
    """
    def __init__(self, data_processor, x_labels):
        self.data_processor = data_processor
        self.x_labels = x_labels
        sns.set(style="white", font_scale=1.1)
        self.fig, self.ax = plt.subplots(figsize=(12, 8), dpi=150)
        self.palette = sns.color_palette("Set2", 2)

    def create_bar_plot(self):
        """
        Creates a bar plot to visualize life satisfaction vs. socializing frequency,
        differentiated by religious belief.
        """
        sns.barplot(
            data=self.data_processor.grouped,
            x='sclmeet',
            y='stflife',
            hue='religious',
            palette=self.palette,
            width=0.7,
            ax=self.ax
        )
        return self

    def customize_plot(self, total_n):
        """
        Customizes the plot with titles, labels, mean lines, and a footnote.
        """
        self._remove_chart_borders()
        self._add_mean_lines()
        self._set_titles_and_labels()
        self._clean_legend()
        self._add_footnote(total_n)
        self._adjust_layout()
        return self

    def _remove_chart_borders(self):
        """
        Removes the top, right, left, and bottom spines from the plot.
        """
        sns.despine(top=True, right=True, left=True, bottom=True)
        self.ax.grid(False)

    def _add_mean_lines(self):
        """
        Adds horizontal lines representing the mean life satisfaction for each
        religious group.
        """
        for rel, avg in self.data_processor.means.items():
            color = self.palette[0] if rel == "Religious" else self.palette[1]
            self.ax.axhline(
                y=avg,
                linestyle='--',
                color=color,
                linewidth=1.2,
                alpha=0.9,
                zorder=5
            )

    def _set_titles_and_labels(self):
        """
        Sets the main title, subtitle, x-axis label, and y-axis label for the plot.
        """
        self.fig.suptitle(
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
            labels=self.x_labels,
            rotation=0,
            ha='center'
        )
        plt.yticks(range(0, 11))
        plt.ylim(0, 10)

    def _clean_legend(self):
        """
        Cleans up the legend by removing unnecessary handles and labels.
        """
        handles, labels = self.ax.get_legend_handles_labels()
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

    def _add_footnote(self, total_n):
        """
        Adds a footnote with the data source and sample size.
        """
        plt.figtext(
            0.5, 0.02,
            f'Source: European Social Survey Round 10 (country: Bulgaria)\n'
            f'Life satisfaction is rated on a scale from 0 (extremely dissatisfied) to 10 (extremely satisfied). (N = {total_n:,})',
            wrap=True,
            horizontalalignment='center',
            fontsize=10,
            style='italic'
        )

    def _adjust_layout(self):
        """
        Adjusts the layout of the subplots to make room for all elements.
        """
        plt.subplots_adjust(left=0.15, right=0.90, top=0.85, bottom=0.25)

    def save_and_show_plot(self, file_name):
        """
        Saves the plot to a file and displays it.
        """
        plt.savefig(file_name, bbox_inches='tight')
        plt.show()
        plt.close()

# --- Main script ---
file_path = "ESS10-subset.csv"
x_labels = [
    'Never',
    'Less than\nonce a month',
    'Once\na month',
    'Several\ntimes\na month',
    'Once\na week',
    'Several\ntimes\na week',
    'Every\nday'
]

# Initialize data processor and load data
data_processor = DataProcessor(file_path)
data_processor.load_data().extract_variables(['stflife', 'rlgblg', 'sclmeet']).clean_data().aggregate_data()

# Get total observations
total_n = data_processor.get_total_observations()

# Initialize plotter and create plot
plotter = Plotter(data_processor, x_labels)
plotter.create_bar_plot().customize_plot(total_n).save_and_show_plot('assignment_1/1_bar_chart.png')

print('✅ Final clean bar chart saved with dynamic N!')

# --- END ---
