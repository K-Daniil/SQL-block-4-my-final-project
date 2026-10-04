CREATE DATABASE final_project_sql;
USE final_project_sql;
/* 1.список клиентов с непрерывной историей за год*/
WITH monthly_activity AS (
    SELECT 
        ID_client, DATE_FORMAT(STR_TO_DATE(date_new, '%d/%m/%Y'), '%Y-%m') AS month_year, COUNT(DISTINCT Id_check) AS ops_count, SUM(Sum_payment) AS total_sum
    FROM transactions_info
    WHERE STR_TO_DATE(date_new, '%d/%m/%Y') BETWEEN '2015-06-01' AND '2016-06-01'
    GROUP BY ID_client, month_year
),
continuous_clients AS (
    SELECT ID_client
    FROM monthly_activity
    GROUP BY ID_client
    HAVING COUNT(DISTINCT month_year) >= 12
)
SELECT 
    t.ID_client, ROUND(SUM(t.Sum_payment) / COUNT(DISTINCT t.Id_check), 2) AS avg_check, ROUND(SUM(t.Sum_payment) / COUNT(DISTINCT DATE_FORMAT(STR_TO_DATE(t.date_new, '%d/%m/%Y'), '%Y-%m')), 2) AS avg_monthly_spending,
    COUNT(DISTINCT t.Id_check) AS total_operations, ROUND(SUM(t.Sum_payment), 2) AS total_sum
FROM transactions_info t
JOIN continuous_clients c ON t.ID_client = c.ID_client
WHERE STR_TO_DATE(t.date_new, '%d/%m/%Y') BETWEEN '2015-06-01' AND '2016-06-01'
GROUP BY t.ID_client
ORDER BY t.ID_client;

/* 2.1: Информация в разрезе месяцев*/
WITH monthly_summary AS (
    SELECT DATE_FORMAT(STR_TO_DATE(date_new, '%d/%m/%Y'), '%Y-%m') AS month_year, SUM(Sum_payment) AS month_sum, COUNT(DISTINCT Id_check) AS month_ops,
        COUNT(DISTINCT ID_client) AS active_clients,
        SUM(Sum_payment) / COUNT(DISTINCT Id_check) AS avg_check
    FROM transactions_info
    WHERE STR_TO_DATE(date_new, '%d/%m/%Y') BETWEEN '2015-06-01' AND '2016-06-01'
    GROUP BY month_year
),
year_totals AS (
    SELECT 
        SUM(Sum_payment) AS year_sum,
        COUNT(DISTINCT Id_check) AS year_ops
    FROM transactions_info
    WHERE STR_TO_DATE(date_new, '%d/%m/%Y') BETWEEN '2015-06-01' AND '2016-06-01'
)
SELECT 
    m.month_year, ROUND(m.avg_check, 2) AS avg_check_month, m.month_ops AS ops_count_in_month, m.active_clients AS active_clients_count, ROUND(m.month_ops * 100.0 / y.year_ops, 2) AS share_ops_year_pct,
    ROUND(m.month_sum * 100.0 / y.year_sum, 2) AS share_sum_year_pct
FROM monthly_summary m, year_totals y
ORDER BY m.month_year;


/* 2.2: Процентное соотношение M/F/NA в каждом месяце с их долей затрат*/

SELECT DATE_FORMAT(STR_TO_DATE(t.date_new, '%d/%m/%Y'), '%Y-%m') AS month_year, COALESCE(c.Gender, 'NA') AS gender, COUNT(DISTINCT t.ID_client) AS clients_count,
    ROUND(COUNT(DISTINCT t.ID_client) * 100.0 / SUM(COUNT(DISTINCT t.ID_client)) OVER (PARTITION BY DATE_FORMAT(STR_TO_DATE(t.date_new, '%d/%m/%Y'), '%Y-%m')), 2) AS gender_client_pct,
    ROUND(SUM(t.Sum_payment), 2) AS gender_sum, ROUND(SUM(t.Sum_payment) * 100.0 / SUM(SUM(t.Sum_payment)) OVER (PARTITION BY DATE_FORMAT(STR_TO_DATE(t.date_new, '%d/%m/%Y'), '%Y-%m')), 2) AS gender_spend_pct
FROM transactions_info t
LEFT JOIN customer_info c ON t.ID_client = c.Id_client
WHERE STR_TO_DATE(t.date_new, '%d/%m/%Y') BETWEEN '2015-06-01' AND '2016-06-01'
GROUP BY month_year, gender
ORDER BY month_year, gender;

/* 3.1: Возрастные группы клиентов с шагом 10 лет и 'NA'*/

SELECT 
    CASE 
        WHEN c.Age IS NULL THEN 'NA'
        ELSE CONCAT(FLOOR(c.Age / 10) * 10, '-', FLOOR(c.Age / 10) * 10 + 9)
    END AS age_group,
    ROUND(SUM(t.Sum_payment), 2) AS total_sum,
    COUNT(DISTINCT t.Id_check) AS total_ops
FROM transactions_info t
LEFT JOIN customer_info c ON t.ID_client = c.Id_client
WHERE STR_TO_DATE(t.date_new, '%d/%m/%Y') BETWEEN '2015-06-01' AND '2016-06-01'
GROUP BY age_group
ORDER BY age_group;

/* 3.2: Возрастные группы поквартально — средние показатели и % */
WITH quarterly_data AS (
    SELECT 
        CONCAT(YEAR(STR_TO_DATE(t.date_new, '%d/%m/%Y')), '-Q', QUARTER(STR_TO_DATE(t.date_new, '%d/%m/%Y'))) AS quarter_num,
        CASE 
            WHEN c.Age IS NULL THEN 'NA'
            ELSE CONCAT(FLOOR(c.Age / 10) * 10, '-', FLOOR(c.Age / 10) * 10 + 9)
        END AS age_group,
        SUM(t.Sum_payment) AS q_sum,
        COUNT(DISTINCT t.Id_check) AS q_ops
    FROM transactions_info t
    LEFT JOIN customer_info c ON t.ID_client = c.Id_client
    WHERE STR_TO_DATE(t.date_new, '%d/%m/%Y') BETWEEN '2015-06-01' AND '2016-06-01'
    GROUP BY quarter_num, age_group
)
SELECT 
    q.quarter_num, q.age_group, ROUND(q.q_sum / q.q_ops, 2) AS avg_check, q.q_ops AS operations_count, ROUND(q.q_sum, 2) AS total_spending, ROUND(q.q_sum * 100.0 / SUM(q.q_sum) OVER (PARTITION BY q.quarter_num), 2) AS share_sum_quarter_pct,
    ROUND(q.q_ops * 100.0 / SUM(q.q_ops) OVER (PARTITION BY q.quarter_num), 2) AS share_ops_quarter_pct
FROM quarterly_data q
ORDER BY q.quarter_num, q.age_group;




