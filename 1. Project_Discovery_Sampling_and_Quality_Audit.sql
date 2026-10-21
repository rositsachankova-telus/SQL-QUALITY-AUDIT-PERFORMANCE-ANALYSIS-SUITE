
SHOW PROCESSLIST;

-- This file contains the complete pipeline from project discovery and filtering through stratified sampling to detailed task timing analysis, 
-- rater performance profiling, and quality auditing with contact information.

-- Retrieves template information for a specific project to identify the project template ID and its properties.
-- Use this to find which template a project uses before filtering by template_id in other queries.
SELECT p.id            AS sample_project_id,
       p.template_id,
       vf.name         AS template_path,
       vf.display_name,
       vf.rater_visible_template_name,
       vf.type,
       vf.project_type,
       vf.status       AS template_status
FROM Project p
LEFT JOIN VersionedFile vf ON vf.id = p.template_id
WHERE p.id = 290707100;

-- Counts the total number of projects using a specific template.
-- Provides a baseline metric for project volume under a given template.
SELECT 
    COUNT(*) AS total_projects
FROM Project p
WHERE p.template_id = 138502002;

-- Groups projects by completion status (COMPLETED, INVALIDATED, IN_PROGRESS) with counts and date ranges.
-- Identifies project distribution across statuses and tracks which projects have been invalidated.
SELECT pep.event_last,
       COUNT(*)                                        AS projects,
       SUM(pep.invalidated_timestamp_last IS NOT NULL) AS ever_invalidated,
       MIN(p.start_date)                               AS first_project,
       MAX(p.start_date)                               AS last_project
FROM Project p
LEFT JOIN ProjectEventPivot pep ON pep.id = p.id
WHERE p.template_id = 138502002
  AND p.insert_time >= '2026-03-01'
GROUP BY pep.event_last
ORDER BY projects DESC;

-- Counts unique completed projects within a 3-month window and shows the earliest/latest project timestamps.
-- Confirms data availability for the analysis period and identifies any missing data.
SELECT 
    COUNT(DISTINCT p.id) AS unique_projects,
    MIN(p.insert_time) AS earliest_project,
    MAX(p.insert_time) AS latest_project,
    COUNT(*) AS total_rows_before_grouping
FROM Project p
LEFT JOIN TaskProjectSummary tps ON p.id = tps.project_id
LEFT JOIN ProjectEventPivot pep ON p.id = pep.id
WHERE p.template_id = 138502002
AND p.insert_time >= DATE_SUB('2026-09-22', INTERVAL 3 MONTH)
AND p.insert_time <= '2026-09-22'
AND pep.event_last = 'COMPLETED';

-- Lists all projects with their task counts, ordered by insertion time (most recent first).
-- Provides a complete inventory of projects and allows quick identification of project size by task volume.
SELECT 
    p.id AS project_id,
    p.template_id,
    p.insert_time,
    COUNT(tps.id) AS task_count
FROM Project p
LEFT JOIN TaskProjectSummary tps ON p.id = tps.project_id
WHERE p.template_id = 138502002
GROUP BY p.id, p.template_id, p.insert_time
ORDER BY p.insert_time DESC
LIMIT 1000;

-- Counts projects that meet specific criteria: English (US) locale, 500-1000 tasks, and completed status within 3 months.
-- Used to validate how many qualifying projects exist before sampling.
SELECT 
    COUNT(DISTINCT p.id) AS projects_meeting_criteria
FROM Project p
LEFT JOIN TaskProjectSummary tps ON p.id = tps.project_id
LEFT JOIN ProjectEventPivot pep ON p.id = pep.id
LEFT JOIN Locale l ON p.locale_id = l.id
WHERE p.template_id = 138502002
AND p.insert_time >= DATE_SUB('2026-09-22', INTERVAL 3 MONTH)
AND p.insert_time <= '2026-09-22'
AND pep.event_last = 'COMPLETED'
AND l.name = 'English (US)'
AND (
    SELECT COUNT(*) FROM TaskProjectSummary tps2 
    WHERE tps2.project_id = p.id
) > 500
AND (
    SELECT COUNT(*) FROM TaskProjectSummary tps3 
    WHERE tps3.project_id = p.id
) <= 1000;

-- Groups projects by ISO week number with counts of projects per week and the date range for each week.
-- Shows project distribution across weeks to inform stratified sampling decisions.
SELECT 
    WEEK(p.insert_time) AS week_number,
    COUNT(DISTINCT p.id) AS projects_in_week,
    MIN(p.insert_time) AS week_start,
    MAX(p.insert_time) AS week_end
FROM Project p
LEFT JOIN ProjectEventPivot pep ON p.id = pep.id
LEFT JOIN Locale l ON p.locale_id = l.id
WHERE p.template_id = 138502002
AND p.insert_time >= DATE_SUB('2026-09-22', INTERVAL 3 MONTH)
AND p.insert_time <= '2026-09-22'
AND pep.event_last = 'COMPLETED'
AND l.name = 'English (US)'
AND (SELECT COUNT(*) FROM TaskProjectSummary WHERE project_id = p.id) BETWEEN 500 AND 1000
GROUP BY WEEK(p.insert_time)
ORDER BY week_number;

-- Lists all 33 qualifying projects with their IDs, statuses, week numbers, year, locale, and task counts.
-- Provides a complete view of all available projects for sampling.
SELECT 
    p.id AS project_id,
    p.template_id,
    p.insert_time,
    WEEK(p.insert_time) AS week_number,
    YEAR(p.insert_time) AS year_num,
    pep.event_last AS status,
    l.name AS locale,
    (SELECT COUNT(*) FROM TaskProjectSummary WHERE project_id = p.id) AS task_count
FROM Project p
LEFT JOIN ProjectEventPivot pep ON p.id = pep.id
LEFT JOIN Locale l ON p.locale_id = l.id
WHERE p.template_id = 138502002
AND p.insert_time >= DATE_SUB('2026-09-22', INTERVAL 3 MONTH)
AND p.insert_time <= '2026-09-22'
AND pep.event_last = 'COMPLETED'
AND l.name = 'English (US)'
AND (SELECT COUNT(*) FROM TaskProjectSummary WHERE project_id = p.id) BETWEEN 500 AND 1000
ORDER BY WEEK(p.insert_time), p.insert_time, p.id;

-- Selects 10 projects using weighted sampling: 2 from week 25, 1 from week 29, 1 from week 30, 4 from week 36, 2 from week 37.
-- Creates a balanced cross-section of projects across time periods for comprehensive quality auditing.
(
    SELECT p.id AS project_id, p.insert_time, WEEK(p.insert_time) AS week_number, 
           (SELECT COUNT(*) FROM TaskProjectSummary WHERE project_id = p.id) AS task_count
    FROM Project p
    LEFT JOIN ProjectEventPivot pep ON p.id = pep.id
    LEFT JOIN Locale l ON p.locale_id = l.id
    WHERE p.template_id = 138502002
    AND p.insert_time >= DATE_SUB('2026-09-22', INTERVAL 3 MONTH)
    AND p.insert_time <= '2026-09-22'
    AND pep.event_last = 'COMPLETED'
    AND l.name = 'English (US)'
    AND (SELECT COUNT(*) FROM TaskProjectSummary WHERE project_id = p.id) BETWEEN 500 AND 1000
    AND WEEK(p.insert_time) = 25
    ORDER BY RAND() LIMIT 2
)
UNION ALL
(
    SELECT p.id AS project_id, p.insert_time, WEEK(p.insert_time) AS week_number, 
           (SELECT COUNT(*) FROM TaskProjectSummary WHERE project_id = p.id) AS task_count
    FROM Project p
    LEFT JOIN ProjectEventPivot pep ON p.id = pep.id
    LEFT JOIN Locale l ON p.locale_id = l.id
    WHERE p.template_id = 138502002
    AND p.insert_time >= DATE_SUB('2026-09-22', INTERVAL 3 MONTH)
    AND p.insert_time <= '2026-09-22'
    AND pep.event_last = 'COMPLETED'
    AND l.name = 'English (US)'
    AND (SELECT COUNT(*) FROM TaskProjectSummary WHERE project_id = p.id) BETWEEN 500 AND 1000
    AND WEEK(p.insert_time) = 29
    ORDER BY RAND() LIMIT 1
)
UNION ALL
(
    SELECT p.id AS project_id, p.insert_time, WEEK(p.insert_time) AS week_number, 
           (SELECT COUNT(*) FROM TaskProjectSummary WHERE project_id = p.id) AS task_count
    FROM Project p
    LEFT JOIN ProjectEventPivot pep ON p.id = pep.id
    LEFT JOIN Locale l ON p.locale_id = l.id
    WHERE p.template_id = 138502002
    AND p.insert_time >= DATE_SUB('2026-09-22', INTERVAL 3 MONTH)
    AND p.insert_time <= '2026-09-22'
    AND pep.event_last = 'COMPLETED'
    AND l.name = 'English (US)'
    AND (SELECT COUNT(*) FROM TaskProjectSummary WHERE project_id = p.id) BETWEEN 500 AND 1000
    AND WEEK(p.insert_time) = 30
    ORDER BY RAND() LIMIT 1
)
UNION ALL
(
    SELECT p.id AS project_id, p.insert_time, WEEK(p.insert_time) AS week_number, 
           (SELECT COUNT(*) FROM TaskProjectSummary WHERE project_id = p.id) AS task_count
    FROM Project p
    LEFT JOIN ProjectEventPivot pep ON p.id = pep.id
    LEFT JOIN Locale l ON p.locale_id = l.id
    WHERE p.template_id = 138502002
    AND p.insert_time >= DATE_SUB('2026-09-22', INTERVAL 3 MONTH)
    AND p.insert_time <= '2026-09-22'
    AND pep.event_last = 'COMPLETED'
    AND l.name = 'English (US)'
    AND (SELECT COUNT(*) FROM TaskProjectSummary WHERE project_id = p.id) BETWEEN 500 AND 1000
    AND WEEK(p.insert_time) = 36
    ORDER BY RAND() LIMIT 4
)
UNION ALL
(
    SELECT p.id AS project_id, p.insert_time, WEEK(p.insert_time) AS week_number, 
           (SELECT COUNT(*) FROM TaskProjectSummary WHERE project_id = p.id) AS task_count
    FROM Project p
    LEFT JOIN ProjectEventPivot pep ON p.id = pep.id
    LEFT JOIN Locale l ON p.locale_id = l.id
    WHERE p.template_id = 138502002
    AND p.insert_time >= DATE_SUB('2026-09-22', INTERVAL 3 MONTH)
    AND p.insert_time <= '2026-09-22'
    AND pep.event_last = 'COMPLETED'
    AND l.name = 'English (US)'
    AND (SELECT COUNT(*) FROM TaskProjectSummary WHERE project_id = p.id) BETWEEN 500 AND 1000
    AND WEEK(p.insert_time) = 37
    ORDER BY RAND() LIMIT 2
)
ORDER BY week_number, project_id;

-- Lists all invalidated projects within the 3-month period with their template IDs and timestamps.
-- Identifies projects that failed or were rejected for re-evaluation purposes.
SELECT 
    p.id AS project_id,
    p.template_id,
    p.insert_time,
    pep.event_last AS status
FROM Project p
LEFT JOIN ProjectEventPivot pep ON p.id = pep.id
WHERE p.template_id = 138502002
AND p.insert_time >= DATE_SUB('2026-09-22', INTERVAL 3 MONTH)
AND p.insert_time <= '2026-09-22'
AND pep.event_last = 'INVALIDATED'
ORDER BY p.insert_time DESC;

-- Retrieves all task submissions with timing (acquired to submitted) in MM:SS format for the template.
-- Provides raw task-level timing data across all matching projects for detailed performance analysis.
SELECT 
    t_start.id,
    tps.project_id,
    Task.user_id,
    Task.item_id,
    t_start.timestamp as acquired_time,
    t_end.timestamp as submitted_time,
    CONCAT(
        LPAD(FLOOR(TIMESTAMPDIFF(SECOND, t_start.timestamp, t_end.timestamp) / 60), 2, '0'),
        ':',
        LPAD(TIMESTAMPDIFF(SECOND, t_start.timestamp, t_end.timestamp) % 60, 2, '0')
    ) as time_spent
FROM TaskEvent t_start
INNER JOIN TaskEvent t_end ON t_start.id = t_end.id
INNER JOIN TaskProjectSummary tps ON t_start.id = tps.id
INNER JOIN Task ON t_start.id = Task.id
INNER JOIN Project p ON tps.project_id = p.id
LEFT JOIN ProjectEventPivot pep ON p.id = pep.id
WHERE t_start.type = 'ACQUIRED'
AND t_end.type = 'SUBMITTED'
AND t_start.ix0 = 0
AND p.template_id = 138502002
AND p.insert_time >= DATE_SUB(NOW(), INTERVAL 3 MONTH)
AND pep.event_last = 'COMPLETED'
LIMIT 3000;

-- Retrieves all task submissions for the 10 selected projects with timing in MM:SS format, ordered by project and timestamp.
-- Provides focused timing data for the sampled projects without row limits.
SELECT 
    t_start.id,
    tps.project_id,
    Task.user_id,
    Task.item_id,
    t_start.timestamp as acquired_time,
    t_end.timestamp as submitted_time,
    CONCAT(
        LPAD(FLOOR(TIMESTAMPDIFF(SECOND, t_start.timestamp, t_end.timestamp) / 60), 2, '0'),
        ':',
        LPAD(TIMESTAMPDIFF(SECOND, t_start.timestamp, t_end.timestamp) % 60, 2, '0')
    ) as time_spent
FROM TaskEvent t_start
INNER JOIN TaskEvent t_end ON t_start.id = t_end.id
INNER JOIN TaskProjectSummary tps ON t_start.id = tps.id
INNER JOIN Task ON t_start.id = Task.id
WHERE t_start.type = 'ACQUIRED'
AND t_end.type = 'SUBMITTED'
AND t_start.ix0 = 0
AND tps.project_id IN (289288092, 289402841, 290055045, 290100821, 290865465, 290881492, 290885441, 290921446, 291178920, 291183471)
ORDER BY tps.project_id, t_start.timestamp;

-- Calculates overall statistics (total, min, max, average, and standard deviation) of submission times across the 10 projects.
-- Provides baseline metrics to identify performance outliers and overall workflow efficiency.
SELECT 
    COUNT(*) as total_submissions,
    MIN(TIMESTAMPDIFF(SECOND, t_start.timestamp, t_end.timestamp) / 60) as min_minutes,
    MAX(TIMESTAMPDIFF(SECOND, t_start.timestamp, t_end.timestamp) / 60) as max_minutes,
    ROUND(AVG(TIMESTAMPDIFF(SECOND, t_start.timestamp, t_end.timestamp) / 60), 2) as avg_minutes,
    ROUND(STDDEV(TIMESTAMPDIFF(SECOND, t_start.timestamp, t_end.timestamp) / 60), 2) as stddev_minutes
FROM TaskEvent t_start
INNER JOIN TaskEvent t_end ON t_start.id = t_end.id
INNER JOIN TaskProjectSummary tps ON t_start.id = tps.id
WHERE t_start.type = 'ACQUIRED'
AND t_end.type = 'SUBMITTED'
AND t_start.ix0 = 0
AND tps.project_id IN (289288092, 289402841, 290055045, 290100821, 290865465, 290881492, 290885441, 290921446, 291178920, 291183471);

-- Groups submissions into three time categories (under 3 min, 3-5 min, 5+ min) and calculates percentage distribution.
-- Shows how submissions are distributed across speed tiers to identify task completion patterns.
SELECT 
    CASE 
        WHEN TIMESTAMPDIFF(SECOND, t_start.timestamp, t_end.timestamp) / 60 < 3 THEN 'Under 3 min'
        WHEN TIMESTAMPDIFF(SECOND, t_start.timestamp, t_end.timestamp) / 60 < 5 THEN '3-5 min'
        ELSE '5+ min'
    END as time_category,
    COUNT(*) as submission_count,
    ROUND(COUNT(*) * 100 / @total_count, 2) as percentage
FROM (
    SELECT @total_count := COUNT(*) 
    FROM TaskEvent t_s 
    INNER JOIN TaskEvent t_e ON t_s.id = t_e.id 
    INNER JOIN TaskProjectSummary tps2 ON t_s.id = tps2.id 
    WHERE t_s.type = 'ACQUIRED' 
    AND t_e.type = 'SUBMITTED'
    AND tps2.project_id IN (289288092, 289402841, 290055045, 290100821, 290865465, 290881492, 290885441, 290921446, 291178920, 291183471)
) AS total_calc,
TaskEvent t_start
INNER JOIN TaskEvent t_end ON t_start.id = t_end.id
INNER JOIN TaskProjectSummary tps ON t_start.id = tps.id
WHERE t_start.type = 'ACQUIRED'
AND t_end.type = 'SUBMITTED'
AND t_start.ix0 = 0
AND tps.project_id IN (289288092, 289402841, 290055045, 290100821, 290865465, 290881492, 290885441, 290921446, 291178920, 291183471)
GROUP BY time_category
ORDER BY CASE 
    WHEN TIMESTAMPDIFF(SECOND, t_start.timestamp, t_end.timestamp) / 60 < 3 THEN 1
    WHEN TIMESTAMPDIFF(SECOND, t_start.timestamp, t_end.timestamp) / 60 < 5 THEN 2
    ELSE 3
END;

-- Profiles each rater by total submissions, average/min/max time, and assigns performance category (TOO FAST/NORMAL/TOO SLOW).
-- Identifies raters with performance anomalies requiring further investigation or coaching.
SELECT 
    Task.user_id AS rater_id,
    COUNT(*) AS total_submissions,
    ROUND(AVG(TIMESTAMPDIFF(SECOND, t_start.timestamp, t_end.timestamp) / 60), 2) AS avg_minutes,
    ROUND(MIN(TIMESTAMPDIFF(SECOND, t_start.timestamp, t_end.timestamp) / 60), 2) AS min_minutes,
    ROUND(MAX(TIMESTAMPDIFF(SECOND, t_start.timestamp, t_end.timestamp) / 60), 2) AS max_minutes,
    CASE 
        WHEN ROUND(AVG(TIMESTAMPDIFF(SECOND, t_start.timestamp, t_end.timestamp) / 60), 2) < 0.75 THEN 'TOO FAST (< 45s avg)'
        WHEN ROUND(AVG(TIMESTAMPDIFF(SECOND, t_start.timestamp, t_end.timestamp) / 60), 2) BETWEEN 1.5 AND 7 THEN 'NORMAL (1.5-7 min)'
        ELSE 'TOO SLOW (> 7 min)'
    END AS rater_category
FROM TaskEvent t_start
INNER JOIN TaskEvent t_end ON t_start.id = t_end.id
INNER JOIN TaskProjectSummary tps ON t_start.id = tps.id
INNER JOIN Task ON t_start.id = Task.id
WHERE t_start.type = 'ACQUIRED'
AND t_end.type = 'SUBMITTED'
AND t_start.ix0 = 0
AND tps.project_id IN (289288092, 289402841, 290055045, 290100821, 290865465, 290881492, 290885441, 290921446, 291178920, 291183471)
GROUP BY Task.user_id
ORDER BY avg_minutes ASC;

-- Shows raters with abnormal performance (TOO FAST or TOO SLOW) broken down by project.
-- Identifies whether performance issues are consistent across projects or project-specific.
SELECT 
    Task.user_id AS rater_id,
    tps.project_id,
    COUNT(*) AS total_submissions,
    ROUND(AVG(TIMESTAMPDIFF(SECOND, t_start.timestamp, t_end.timestamp) / 60), 2) AS avg_minutes,
    ROUND(MIN(TIMESTAMPDIFF(SECOND, t_start.timestamp, t_end.timestamp) / 60), 2) AS min_minutes,
    ROUND(MAX(TIMESTAMPDIFF(SECOND, t_start.timestamp, t_end.timestamp) / 60), 2) AS max_minutes,
    CASE 
        WHEN ROUND(AVG(TIMESTAMPDIFF(SECOND, t_start.timestamp, t_end.timestamp) / 60), 2) < 0.75 THEN 'TOO FAST (< 45s)'
        WHEN ROUND(AVG(TIMESTAMPDIFF(SECOND, t_start.timestamp, t_end.timestamp) / 60), 2) BETWEEN 1.5 AND 7 THEN 'NORMAL (1.5-7 min)'
        ELSE 'TOO SLOW (> 7 min)'
    END AS rater_category
FROM TaskEvent t_start
INNER JOIN TaskEvent t_end ON t_start.id = t_end.id
INNER JOIN TaskProjectSummary tps ON t_start.id = tps.id
INNER JOIN Task ON t_start.id = Task.id
WHERE t_start.type = 'ACQUIRED'
AND t_end.type = 'SUBMITTED'
AND t_start.ix0 = 0
AND tps.project_id IN (289288092, 289402841, 290055045, 290100821, 290865465, 290881492, 290885441, 290921446, 291178920, 291183471)
GROUP BY Task.user_id, tps.project_id
HAVING ROUND(AVG(TIMESTAMPDIFF(SECOND, t_start.timestamp, t_end.timestamp) / 60), 2) < 0.75
OR ROUND(AVG(TIMESTAMPDIFF(SECOND, t_start.timestamp, t_end.timestamp) / 60), 2) > 7
ORDER BY rater_category, avg_minutes ASC;

-- Pre-filters for problem raters (TOO FAST <1 min OR TOO SLOW >15 min) and shows their complete project-by-project breakdown.
-- Provides full context for flagged raters to understand where issues occur across different projects.
SELECT 
    Task.user_id AS rater_id,
    tps.project_id,
    COUNT(*) AS total_submissions,
    ROUND(AVG(TIMESTAMPDIFF(SECOND, t_start.timestamp, t_end.timestamp) / 60), 2) AS avg_minutes,
    ROUND(MIN(TIMESTAMPDIFF(SECOND, t_start.timestamp, t_end.timestamp) / 60), 2) AS min_minutes,
    ROUND(MAX(TIMESTAMPDIFF(SECOND, t_start.timestamp, t_end.timestamp) / 60), 2) AS max_minutes,
    CASE 
        WHEN ROUND(AVG(TIMESTAMPDIFF(SECOND, t_start.timestamp, t_end.timestamp) / 60), 2) < 1 THEN 'TOO FAST (< 45s)'
        WHEN ROUND(AVG(TIMESTAMPDIFF(SECOND, t_start.timestamp, t_end.timestamp) / 60), 2) > 15 THEN 'TOO SLOW (> 15 min)'
        ELSE 'NORMAL'
    END AS rater_category
FROM TaskEvent t_start
INNER JOIN TaskEvent t_end ON t_start.id = t_end.id
INNER JOIN TaskProjectSummary tps ON t_start.id = tps.id
INNER JOIN Task ON t_start.id = Task.id
WHERE t_start.type = 'ACQUIRED'
AND t_end.type = 'SUBMITTED'
AND t_start.ix0 = 0
AND tps.project_id IN (289288092, 289402841, 290055045, 290100821, 290865465, 290881492, 290885441, 290921446, 291178920, 291183471)
AND Task.user_id IN (
    SELECT DISTINCT Task.user_id
    FROM TaskEvent t_s
    INNER JOIN TaskEvent t_e ON t_s.id = t_e.id
    INNER JOIN TaskProjectSummary tps2 ON t_s.id = tps2.id
    INNER JOIN Task ON t_s.id = Task.id
    WHERE t_s.type = 'ACQUIRED'
    AND t_e.type = 'SUBMITTED'
    AND t_s.ix0 = 0
    AND tps2.project_id IN (289288092, 289402841, 290055045, 290100821, 290865465, 290881492, 290885441, 290921446, 291178920, 291183471)
    GROUP BY Task.user_id, tps2.project_id
    HAVING COUNT(*) > 1
    AND (ROUND(AVG(TIMESTAMPDIFF(SECOND, t_s.timestamp, t_e.timestamp) / 60), 2) < 1
    OR ROUND(AVG(TIMESTAMPDIFF(SECOND, t_s.timestamp, t_e.timestamp) / 60), 2) > 15)
)
GROUP BY Task.user_id, tps.project_id
ORDER BY Task.user_id, tps.project_id;

-- Lists all individual tasks submitted in under 1 minute by raters flagged as TOO FAST on their projects.
-- Enables detailed quality review of rushed submissions to assess accuracy and completeness.
SELECT 
    Task.user_id AS rater_id,
    tps.project_id,
    Task.item_id AS task_id,
    t_start.timestamp as acquired_time,
    t_end.timestamp as submitted_time,
    ROUND(TIMESTAMPDIFF(SECOND, t_start.timestamp, t_end.timestamp) / 60, 2) AS time_minutes
FROM TaskEvent t_start
INNER JOIN TaskEvent t_end ON t_start.id = t_end.id
INNER JOIN TaskProjectSummary tps ON t_start.id = tps.id
INNER JOIN Task ON t_start.id = Task.id
WHERE t_start.type = 'ACQUIRED'
AND t_end.type = 'SUBMITTED'
AND t_start.ix0 = 0
AND tps.project_id IN (289288092, 289402841, 290055045, 290100821, 290865465, 290881492, 290885441, 290921446, 291178920, 291183471)
AND ROUND(TIMESTAMPDIFF(SECOND, t_start.timestamp, t_end.timestamp) / 60, 2) < 1
AND Task.user_id IN (
    SELECT DISTINCT Task.user_id
    FROM TaskEvent t_s
    INNER JOIN TaskEvent t_e ON t_s.id = t_e.id
    INNER JOIN TaskProjectSummary tps2 ON t_s.id = tps2.id
    INNER JOIN Task ON t_s.id = Task.id
    WHERE t_s.type = 'ACQUIRED'
    AND t_e.type = 'SUBMITTED'
    AND t_s.ix0 = 0
    AND tps2.project_id IN (289288092, 289402841, 290055045, 290100821, 290865465, 290881492, 290885441, 290921446, 291178920, 291183471)
    GROUP BY Task.user_id, tps2.project_id
    HAVING COUNT(*) > 1
    AND ROUND(AVG(TIMESTAMPDIFF(SECOND, t_s.timestamp, t_e.timestamp) / 60), 2) < 1
)
ORDER BY Task.user_id, tps.project_id, t_start.timestamp;

-- Lists all individual tasks taking over 15 minutes by raters flagged as TOO SLOW on their projects.
-- Enables investigation of slow tasks to identify bottlenecks, training needs, or workload imbalance issues.
SELECT 
    Task.user_id AS rater_id,
    tps.project_id,
    Task.item_id AS task_id,
    t_start.timestamp as acquired_time,
    t_end.timestamp as submitted_time,
    ROUND(TIMESTAMPDIFF(SECOND, t_start.timestamp, t_end.timestamp) / 60, 2) AS time_minutes
FROM TaskEvent t_start
INNER JOIN TaskEvent t_end ON t_start.id = t_end.id
INNER JOIN TaskProjectSummary tps ON t_start.id = tps.id
INNER JOIN Task ON t_start.id = Task.id
WHERE t_start.type = 'ACQUIRED'
AND t_end.type = 'SUBMITTED'
AND t_start.ix0 = 0
AND tps.project_id IN (289288092, 289402841, 290055045, 290100821, 290865465, 290881492, 290885441, 290921446, 291178920, 291183471)
AND ROUND(TIMESTAMPDIFF(SECOND, t_start.timestamp, t_end.timestamp) / 60, 2) > 15
AND Task.user_id IN (
    SELECT DISTINCT Task.user_id
    FROM TaskEvent t_s
    INNER JOIN TaskEvent t_e ON t_s.id = t_e.id
    INNER JOIN TaskProjectSummary tps2 ON t_s.id = tps2.id
    INNER JOIN Task ON t_s.id = Task.id
    WHERE t_s.type = 'ACQUIRED'
    AND t_e.type = 'SUBMITTED'
    AND t_s.ix0 = 0
    AND tps2.project_id IN (289288092, 289402841, 290055045, 290100821, 290865465, 290881492, 290885441, 290921446, 291178920, 291183471)
    GROUP BY Task.user_id, tps2.project_id
    HAVING COUNT(*) > 1
    AND ROUND(AVG(TIMESTAMPDIFF(SECOND, t_s.timestamp, t_e.timestamp) / 60), 2) > 15
)
ORDER BY Task.user_id, tps.project_id, t_start.timestamp;

-- Shows how many raters evaluated each item and lists their IDs; identifies single-rater vs. multi-rater (consensus) tasks.
-- Tracks evaluation coverage and consensus patterns for quality assurance and agreement analysis.
SELECT 
    tps.project_id,
    Task.item_id,
    COUNT(DISTINCT Task.user_id) AS number_of_raters,
    GROUP_CONCAT(DISTINCT Task.user_id ORDER BY Task.user_id SEPARATOR ', ') AS rater_ids,
    COUNT(*) AS total_ratings
FROM TaskProjectSummary tps
INNER JOIN Task ON tps.id = Task.id
WHERE tps.project_id IN (289288092, 289402841, 290055045, 290100821, 290865465, 290881492, 290885441, 290921446, 291178920, 291183471)
GROUP BY tps.project_id, Task.item_id
ORDER BY tps.project_id, number_of_raters DESC, Task.item_id;

-- Duplicate query: Shows how many raters evaluated each item with rater IDs.
-- Useful for reference or filtering consensus-based tasks.
SELECT 
    tps.project_id,
    Task.item_id,
    COUNT(DISTINCT Task.user_id) AS number_of_raters,
    GROUP_CONCAT(DISTINCT Task.user_id ORDER BY Task.user_id SEPARATOR ', ') AS rater_ids,
    COUNT(*) AS total_ratings
FROM TaskProjectSummary tps
INNER JOIN Task ON tps.id = Task.id
WHERE tps.project_id IN (289288092, 289402841, 290055045, 290100821, 290865465, 290881492, 290885441, 290921446, 291178920, 291183471)
GROUP BY tps.project_id, Task.item_id
ORDER BY tps.project_id, number_of_raters DESC, Task.item_id;

-- Shows items with their raters (IDs and emails) to identify who evaluated each task.
-- Enables traceability for quality audits and consensus analysis with contact information.
SELECT 
    tps.project_id,
    Task.item_id,
    COUNT(DISTINCT Task.user_id) AS number_of_raters,
    GROUP_CONCAT(DISTINCT Task.user_id ORDER BY Task.user_id SEPARATOR ', ') AS rater_ids,
    GROUP_CONCAT(DISTINCT ua.login ORDER BY Task.user_id SEPARATOR ', ') AS rater_emails,
    COUNT(*) AS total_ratings
FROM TaskProjectSummary tps
INNER JOIN Task ON tps.id = Task.id
LEFT JOIN UserAuthentication ua ON Task.user_id = ua.id
WHERE tps.project_id IN (289288092, 289402841, 290055045, 290100821, 290865465, 290881492, 290885441, 290921446, 291178920, 291183471)
GROUP BY tps.project_id, Task.item_id
ORDER BY tps.project_id, number_of_raters DESC, Task.item_id;

-- Sample query to view user authentication records and email addresses.
-- Useful for understanding user account structure before joining with other tables.
SELECT * FROM UserAuthentication LIMIT 5;

-- Retrieves rater IDs, authentication type, and email addresses for specific raters.
-- Enables direct contact with raters for feedback, coaching, or verification of performance issues.
SELECT 
    User.id as rater_id,
    UserAuthentication.type,
    UserAuthentication.login as email
FROM User
INNER JOIN UserAuthentication ON User.id = UserAuthentication.id
WHERE User.id IN (
    65917581, 2761778, 574791,
    79426074, 959721, 65435748,
    60148503, 63147262, 58566098,
    582896, 39384241, 573529,
    75023747, 40328547, 5313602,
    30110136, 18414902, 79941975,
    6382828, 3042010, 573969
)
ORDER BY User.id;

