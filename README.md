# FDV-DV-25: Data Visualization Course Repository

This repository contains my work for the **Data Visualization** course (FDV-DV-25), including:

- **Assignment 1:** Charts for a newspaper article
- **Assignment 2:** Geospatial and linked plots with Shiny
- **Assignment 3:** To be added
- **Project:** Semester project on Tourism & Demography Visualization

## Repository structure

```
FDV-DV-25/                   # main GitHub repo
├── Assignment_1/            # first assignment
│   ├── data/
│   ├── output/
│   ├── scripts/
├── Assignment_2/            # second assignment
│   ├── data/
│   ├── output/
│   ├── app.R
├── Assignment_3/            # third assignment
├── Project/                 # project
│   ├── data/
│   ├── docs/
│   ├── output/
│   ├── scripts/
└── README.md
```

## Notes

- Each assignment and project is self-contained in its own folder.
- The main project uses `here()` package for robust path handling.
- All data is kept in `data/` folders; all generated charts in `output/`.