# Sleep Health & Lifestyle Analysis

What goes with better sleep, and with sleep disorders? An end-to-end analysis of 374 people: data cleaning, exploratory analysis, statistical testing, a prediction model, lifestyle profiles, and an interactive dashboard.

**Notebook:** (https://github.com/saikarthik011101-pro/sleep-health-analysis)  |

## Headline findings
1. **Stress is the factor most tied to sleep quality.** Spearman correlation of -0.90 on the 132 distinct records (sleep duration 0.88, resting heart rate -0.74).
2. **The gender gap in sleep quality is a stress story.** Men score 0.75 points lower than women, but the gap is about zero (-0.02, 95% range -0.17 to 0.12) once occupation and stress are accounted for.
3. **BMI and occupation separate sleep disorder rates sharply.** 93% of normal-BMI people have no disorder, against 13% of overweight people. Disorder rates run from about 10% (doctors, engineers, lawyers) to 78-94% (teachers, nurses, salespeople).
4. **More steps does not mean better sleep.** No reliable link (correlation 0.02 on all rows; 0.15 and not significant on distinct records).
5. **A model flags sleep disorders at 83% accuracy on distinct records** (guessing: 55%), but BMI category alone reaches 77%. The model adds a few points, not a transformation.
6. **Four lifestyle profiles** (from calm and well-rested to highest stress) have disorder rates from 17% to 82%, even though the disorder column was not used to form them.

**Practical takeaway:** in this data, stress, not exercise volume, is the factor most tied to poor sleep. Among occupations with at least 10 people, salespeople have the highest average stress (7.1 out of 10) and the shortest sleep (6.4 hours).

## What I did
| Step | What | Method |
|---|---|---|
| 1 | Cleaning and feature engineering | Merged duplicate labels, split blood pressure, built age, activity, sleep and blood pressure groups |
| 2 | Exploratory analysis | 9 charts, each answering one business question |
| 3 | Statistical testing | Spearman, Mann-Whitney, Kruskal-Wallis, chi-square, regression; Holm correction for 18 tests; every test run on all rows and on distinct records |
| 4 | Prediction and profiles | Logistic regression, decision tree, random forest vs baselines with grouped cross-validation; K-Means profiles on distinct records |
| 5 | SQL and Power BI | SQL (DuckDB) cleaning, a star-schema data model and 13 business questions using CTEs, window functions and FILTER; a 4-page Power BI dashboard with DAX measures |
## Read this first: data limitations
- **Most rows are repeats.** Only 132 of 374 records are distinct, and the dataset looks synthetic. So every statistical test was repeated on distinct records, and the model was tested with grouped cross-validation so a record's copies never sit in both training and test data.
- **Small groups.** Managers (1), scientists (4) and software engineers (4) are too small for occupation tests, and the obese BMI group has 10 people.
- **Self-reported measures.** Stress and sleep quality are ratings, and poor sleep can also raise stress.
- **Association, not cause.** Gender and occupation overlap heavily here (all nurses are women, all salespeople are men), so their effects cannot be fully separated.
- **Not medical advice.** This is a portfolio analysis of a small, likely synthetic dataset.

## Run it
**Notebook (Colab):** upload `sleep_analysis.ipynb`, choose Runtime > Run all, and upload the original dataset CSV when asked. Section 9 runs the SQL in `sql/` and exports the tables for Power BI.

**Dashboard:** open `powerbi/Sleep_Health_Dashboard.pbix` in Power BI Desktop (Windows). The data is embedded.

## SQL highlights
- `sql/01_clean_and_model.sql`: cleans the raw data (label fixes, blood pressure split, repeated-record flag), builds a fact table and nine lookup tables.
- `sql/02_business_questions.sql`: 13 queries using CTEs, `RANK`, `LAG`, `SUM() OVER (PARTITION BY ...)`, `FILTER` and `HAVING`.
- The SQL results are reconciled against the pandas results in the notebook.

## Dashboard
Four pages: Home,Overview, Drivers, Who is at risk,.
![Screenshots](powerbi/screenshots/)

## Repo contents
- `sleep_analysis.ipynb`: the full analysis, including the SQL section
- `sql/`: the two SQL scripts
- `powerbi/`: the `.pbix` file, theme, exported CSVs and screenshots
- `charts/`: charts saved by the notebook

## Tech
Python, pandas, SciPy, statsmodels, scikit-learn, Matplotlib, SQL (DuckDB), Power BI (DAX).

## Data source
Sleep Health and Lifestyle dataset from Kaggle.
