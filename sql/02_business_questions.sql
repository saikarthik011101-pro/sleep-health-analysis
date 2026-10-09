-- 02_business_questions.sql
-- Thirteen business questions answered with SQL on fact_sleep. Each starts with a line "-- Qnn: question".

-- Q01: How many rows are there, and how many are exact repeats?
SELECT COUNT(*) AS rows_total,
       SUM(CASE WHEN copy_number = 1 THEN 1 ELSE 0 END) AS distinct_records,
       SUM(CASE WHEN copy_number > 1 THEN 1 ELSE 0 END) AS repeated_rows,
       SUM(CASE WHEN age IS NULL OR sleep_duration IS NULL OR quality_of_sleep IS NULL
                  OR stress_level IS NULL OR heart_rate IS NULL OR daily_steps IS NULL
                  OR systolic IS NULL THEN 1 ELSE 0 END) AS rows_with_missing_values
FROM fact_sleep;

-- Q02: What does the average person look like?
SELECT ROUND(AVG(age), 1) AS avg_age,
       ROUND(AVG(sleep_duration), 2) AS avg_sleep_hours,
       ROUND(AVG(quality_of_sleep), 2) AS avg_sleep_quality,
       ROUND(AVG(stress_level), 2) AS avg_stress,
       ROUND(100.0 * AVG(has_disorder), 1) AS pct_with_disorder
FROM fact_sleep;

-- Q03: How common is each sleep disorder? (window function for the share of the total)
SELECT sleep_disorder,
       COUNT(*) AS people,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct_of_all
FROM fact_sleep
GROUP BY sleep_disorder
ORDER BY people DESC;

-- Q04: How does sleep change as stress rises? (LAG shows the step from the previous stress level)
SELECT stress_level,
       COUNT(*) AS people,
       ROUND(AVG(quality_of_sleep), 2) AS avg_quality,
       ROUND(AVG(sleep_duration), 2) AS avg_hours,
       ROUND(AVG(quality_of_sleep) - LAG(AVG(quality_of_sleep)) OVER (ORDER BY stress_level), 2) AS quality_change_vs_previous_level
FROM fact_sleep
GROUP BY stress_level
ORDER BY stress_level;

-- Q05: How do outcomes change across stress bands?
SELECT stress_band,
       COUNT(*) AS people,
       ROUND(AVG(sleep_duration), 2) AS avg_hours,
       ROUND(AVG(quality_of_sleep), 2) AS avg_quality,
       ROUND(100.0 * AVG(CASE WHEN sleep_duration < 7 THEN 1 ELSE 0 END), 0) AS pct_under_7h,
       ROUND(100.0 * AVG(has_disorder), 0) AS pct_with_disorder
FROM fact_sleep
GROUP BY stress_band
ORDER BY MIN(stress_level);

-- Q06: Which factors move together with sleep quality? (Pearson correlation, all rows vs distinct records)
SELECT 'Stress' AS factor,
       ROUND(CORR(stress_level, quality_of_sleep), 2) AS all_rows,
       ROUND(CORR(stress_level, quality_of_sleep) FILTER (WHERE copy_number = 1), 2) AS distinct_records
FROM fact_sleep
UNION ALL
SELECT 'Sleep duration',
       ROUND(CORR(sleep_duration, quality_of_sleep), 2),
       ROUND(CORR(sleep_duration, quality_of_sleep) FILTER (WHERE copy_number = 1), 2)
FROM fact_sleep
UNION ALL
SELECT 'Resting heart rate',
       ROUND(CORR(heart_rate, quality_of_sleep), 2),
       ROUND(CORR(heart_rate, quality_of_sleep) FILTER (WHERE copy_number = 1), 2)
FROM fact_sleep
UNION ALL
SELECT 'Activity minutes',
       ROUND(CORR(physical_activity_level, quality_of_sleep), 2),
       ROUND(CORR(physical_activity_level, quality_of_sleep) FILTER (WHERE copy_number = 1), 2)
FROM fact_sleep
UNION ALL
SELECT 'Daily steps',
       ROUND(CORR(daily_steps, quality_of_sleep), 2),
       ROUND(CORR(daily_steps, quality_of_sleep) FILTER (WHERE copy_number = 1), 2)
FROM fact_sleep;

-- Q07: Which occupations sleep the least? (only groups with 10 or more people, ranked)
SELECT occupation,
       COUNT(*) AS people,
       ROUND(AVG(sleep_duration), 2) AS avg_hours,
       ROUND(AVG(quality_of_sleep), 2) AS avg_quality,
       ROUND(AVG(stress_level), 2) AS avg_stress,
       ROUND(100.0 * AVG(has_disorder), 0) AS pct_with_disorder,
       RANK() OVER (ORDER BY AVG(sleep_duration)) AS shortest_sleep_rank
FROM fact_sleep
GROUP BY occupation
HAVING COUNT(*) >= 10
ORDER BY shortest_sleep_rank;

-- Q08: How do disorders split within each BMI group? (percentage within the group)
SELECT bmi_category,
       sleep_disorder,
       COUNT(*) AS people,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY bmi_category), 1) AS pct_of_bmi_group
FROM fact_sleep
GROUP BY bmi_category, sleep_disorder
ORDER BY bmi_category, sleep_disorder;

-- Q09: Is the gender gap really an occupation effect? (compare men and women within the same job)
SELECT occupation,
       gender,
       COUNT(*) AS people,
       ROUND(AVG(quality_of_sleep), 2) AS avg_quality,
       ROUND(AVG(stress_level), 2) AS avg_stress,
       ROUND(100.0 * AVG(has_disorder), 0) AS pct_with_disorder
FROM fact_sleep
GROUP BY occupation, gender
HAVING COUNT(*) >= 5
ORDER BY occupation, gender;

-- Q10: Which occupation and BMI combinations have the highest disorder rates? (CTE, groups of 10 or more)
WITH combo AS (
    SELECT occupation,
           bmi_category,
           COUNT(*) AS people,
           AVG(has_disorder) AS disorder_rate
    FROM fact_sleep
    GROUP BY occupation, bmi_category
)
SELECT occupation,
       bmi_category,
       people,
       ROUND(100.0 * disorder_rate, 0) AS pct_with_disorder
FROM combo
WHERE people >= 10
ORDER BY disorder_rate DESC, people DESC;

-- Q11: How do sleep and disorder rates change with age?
SELECT age_group,
       COUNT(*) AS people,
       ROUND(AVG(sleep_duration), 2) AS avg_hours,
       ROUND(AVG(sleep_duration) - (SELECT AVG(sleep_duration) FROM fact_sleep), 2) AS hours_vs_overall,
       ROUND(100.0 * AVG(has_disorder), 0) AS pct_with_disorder
FROM fact_sleep
GROUP BY age_group
ORDER BY age_group;

-- Q12: Does a simple rule of thumb separate disorder rates? (rule read off a decision tree fit on this same data)
SELECT risk_segment,
       COUNT(*) AS people,
       SUM(has_disorder) AS with_disorder,
       ROUND(100.0 * AVG(has_disorder), 0) AS pct_with_disorder
FROM fact_sleep
GROUP BY risk_segment
ORDER BY pct_with_disorder DESC;

-- Q13: Do the BMI findings survive when each distinct record is counted once?
SELECT bmi_category,
       COUNT(*) AS people_all_rows,
       ROUND(100.0 * AVG(has_disorder), 0) AS pct_disorder_all_rows,
       COUNT(*) FILTER (WHERE copy_number = 1) AS people_distinct,
       ROUND(100.0 * AVG(has_disorder) FILTER (WHERE copy_number = 1), 0) AS pct_disorder_distinct
FROM fact_sleep
GROUP BY bmi_category
ORDER BY bmi_category;
