-- 01_clean_and_model.sql
-- Input : raw_sleep (the CSV loaded as-is, snake_case column names)
-- Output: fact_sleep (one clean row per person) and small lookup tables (dim_*) for Power BI
-- Dialect: DuckDB, which is close to PostgreSQL

-- 1. Clean the raw data and add analysis columns
CREATE OR REPLACE TABLE fact_sleep AS
WITH tidy AS (
    SELECT
        person_id,
        TRIM(gender)                                         AS gender,
        age,
        CASE WHEN TRIM(occupation) = 'Sales Representative' THEN 'Salesperson'
             ELSE TRIM(occupation) END                       AS occupation,
        sleep_duration,
        quality_of_sleep,
        physical_activity_level,
        stress_level,
        CASE WHEN TRIM(bmi_category) = 'Normal Weight' THEN 'Normal'
             ELSE TRIM(bmi_category) END                     AS bmi_category,
        CAST(SPLIT_PART(blood_pressure, '/', 1) AS INTEGER)  AS systolic,
        CAST(SPLIT_PART(blood_pressure, '/', 2) AS INTEGER)  AS diastolic,
        heart_rate,
        daily_steps,
        COALESCE(NULLIF(TRIM(sleep_disorder), ''), 'None')   AS sleep_disorder
    FROM raw_sleep
),
cutoffs AS (
    -- one-third and two-thirds cut-points, so people with the same value always share a group
    SELECT
        quantile_cont(physical_activity_level, 1.0 / 3) AS act_lo,
        quantile_cont(physical_activity_level, 2.0 / 3) AS act_hi,
        quantile_cont(daily_steps, 1.0 / 3)             AS steps_lo,
        quantile_cont(daily_steps, 2.0 / 3)             AS steps_hi
    FROM tidy
),
flagged AS (
    -- copy_number = 1 marks the first time each distinct record appears
    SELECT
        tidy.*,
        ROW_NUMBER() OVER (
            PARTITION BY gender, age, occupation, sleep_duration, quality_of_sleep,
                         physical_activity_level, stress_level, bmi_category, systolic,
                         diastolic, heart_rate, daily_steps, sleep_disorder
            ORDER BY person_id
        ) AS copy_number
    FROM tidy
)
SELECT
    f.person_id, f.gender, f.age, f.occupation, f.sleep_duration, f.quality_of_sleep,
    f.physical_activity_level, f.stress_level, f.bmi_category, f.systolic, f.diastolic,
    f.heart_rate, f.daily_steps, f.sleep_disorder,
    CASE WHEN f.sleep_disorder <> 'None' THEN 1 ELSE 0 END AS has_disorder,
    CASE WHEN f.age < 30 THEN '20s'
         WHEN f.age < 40 THEN '30s'
         WHEN f.age < 50 THEN '40s'
         ELSE '50+' END AS age_group,
    CASE WHEN f.sleep_duration < 6 THEN 'Short (<6h)'
         WHEN f.sleep_duration < 8 THEN 'Healthy (6 to <8h)'
         ELSE 'Long (8h+)' END AS sleep_category,
    CASE WHEN f.physical_activity_level <= c.act_lo THEN 'Low'
         WHEN f.physical_activity_level <= c.act_hi THEN 'Medium'
         ELSE 'High' END AS activity_group,
    CASE WHEN f.daily_steps <= c.steps_lo THEN 'Low'
         WHEN f.daily_steps <= c.steps_hi THEN 'Medium'
         ELSE 'High' END AS steps_group,
    CASE WHEN f.stress_level <= 4 THEN 'Low (1-4)'
         WHEN f.stress_level <= 6 THEN 'Medium (5-6)'
         ELSE 'High (7-10)' END AS stress_band,
    CASE WHEN f.systolic >= 140 OR f.diastolic >= 90 THEN 'High'
         WHEN f.systolic >= 130 OR f.diastolic >= 80 THEN 'Elevated'
         ELSE 'Normal' END AS bp_category,
    -- rule of thumb read off a decision tree fit on this same data, so not validated on new people
    CASE WHEN f.bmi_category <> 'Normal' AND f.systolic >= 129 THEN 'Higher-risk profile'
         WHEN f.bmi_category = 'Normal' AND f.quality_of_sleep >= 6 THEN 'Lower-risk profile'
         ELSE 'Mixed profile' END AS risk_segment,
    f.copy_number,
    CASE WHEN f.copy_number = 1 THEN 'Distinct record' ELSE 'Repeated copy' END AS record_type
FROM flagged f
CROSS JOIN cutoffs c;

-- 2. Lookup tables (they give Power BI a sort order and a few handy attributes)
CREATE OR REPLACE TABLE dim_age_group AS
SELECT * FROM (VALUES ('20s', 1), ('30s', 2), ('40s', 3), ('50+', 4)) AS t(age_group, sort_order);

CREATE OR REPLACE TABLE dim_bmi AS
SELECT * FROM (VALUES ('Normal', 1), ('Overweight', 2), ('Obese', 3)) AS t(bmi_category, sort_order);

CREATE OR REPLACE TABLE dim_sleep_category AS
SELECT * FROM (VALUES ('Short (<6h)', 1), ('Healthy (6 to <8h)', 2), ('Long (8h+)', 3)) AS t(sleep_category, sort_order);

CREATE OR REPLACE TABLE dim_activity AS
SELECT * FROM (VALUES ('Low', 1), ('Medium', 2), ('High', 3)) AS t(activity_group, sort_order);

CREATE OR REPLACE TABLE dim_stress_band AS
SELECT * FROM (VALUES ('Low (1-4)', 1), ('Medium (5-6)', 2), ('High (7-10)', 3)) AS t(stress_band, sort_order);

CREATE OR REPLACE TABLE dim_disorder AS
SELECT * FROM (VALUES ('None', 'No disorder', 1), ('Insomnia', 'Insomnia', 2), ('Sleep Apnea', 'Sleep apnea', 3))
    AS t(sleep_disorder, disorder_label, sort_order);

CREATE OR REPLACE TABLE dim_bp AS
SELECT * FROM (VALUES ('Normal', 1), ('Elevated', 2), ('High', 3)) AS t(bp_category, sort_order);

CREATE OR REPLACE TABLE dim_risk_segment AS
SELECT * FROM (VALUES ('Higher-risk profile', 1), ('Mixed profile', 2), ('Lower-risk profile', 3))
    AS t(risk_segment, sort_order);

CREATE OR REPLACE TABLE dim_occupation AS
SELECT occupation,
       COUNT(*) AS people_in_data,
       CASE WHEN COUNT(*) >= 10 THEN '10 or more people' ELSE 'Under 10 people' END AS group_size
FROM fact_sleep
GROUP BY occupation;
