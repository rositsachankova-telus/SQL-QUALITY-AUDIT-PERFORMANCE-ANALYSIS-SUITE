-- This file contains all queries for identifying evaluation coverage patterns and performing both balanced and weighted speed-based sampling of single-rater tasks


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

-- Balanced stratified sampling (10-10-10) of single-rater tasks across three speed tiers: TOO FAST, NORMAL (1-2 min), and SLOW (5+ min).
-- Provides equal representation across speed ranges for comprehensive and unbiased quality auditing of single-perspective work.

-- Selects 10 random single-rater tasks completed in under 1 minute (TOO FAST category).
-- Enables quality review of rushed submissions to assess if speed correlates with accuracy issues.
(
    SELECT 
        tps.project_id,
        Task.item_id,
        Task.user_id AS rater_id,
        ROUND(AVG(TIMESTAMPDIFF(SECOND, t_start.timestamp, t_end.timestamp) / 60), 2) AS avg_time_minutes,
        'TOO FAST (< 1 min)' AS time_group
    FROM TaskProjectSummary tps
    INNER JOIN Task ON tps.id = Task.id
    INNER JOIN TaskEvent t_start ON tps.id = t_start.id
    INNER JOIN TaskEvent t_end ON t_start.id = t_end.id
    WHERE tps.project_id IN (289288092, 289402841, 290055045, 290100821, 290865465, 290881492, 290885441, 290921446, 291178920, 291183471)
    AND t_start.type = 'ACQUIRED'
    AND t_end.type = 'SUBMITTED'
    AND t_start.ix0 = 0
    AND Task.item_id IN (
        SELECT Task.item_id
        FROM TaskProjectSummary tps2
        INNER JOIN Task ON tps2.id = Task.id
        WHERE tps2.project_id IN (289288092, 289402841, 290055045, 290100821, 290865465, 290881492, 290885441, 290921446, 291178920, 291183471)
        GROUP BY tps2.project_id, Task.item_id
        HAVING COUNT(DISTINCT Task.user_id) = 1
    )
    GROUP BY tps.project_id, Task.item_id, Task.user_id
    HAVING avg_time_minutes < 1
    ORDER BY RAND()
    LIMIT 10
)
UNION ALL
-- Selects 10 random single-rater tasks completed in 1-2 minutes (NORMAL category).
-- Establishes a baseline of typical, appropriately-paced work to compare against fast and slow outliers.
(
    SELECT 
        tps.project_id,
        Task.item_id,
        Task.user_id AS rater_id,
        ROUND(AVG(TIMESTAMPDIFF(SECOND, t_start.timestamp, t_end.timestamp) / 60), 2) AS avg_time_minutes,
        '1-2 MIN' AS time_group
    FROM TaskProjectSummary tps
    INNER JOIN Task ON tps.id = Task.id
    INNER JOIN TaskEvent t_start ON tps.id = t_start.id
    INNER JOIN TaskEvent t_end ON t_start.id = t_end.id
    WHERE tps.project_id IN (289288092, 289402841, 290055045, 290100821, 290865465, 290881492, 290885441, 290921446, 291178920, 291183471)
    AND t_start.type = 'ACQUIRED'
    AND t_end.type = 'SUBMITTED'
    AND t_start.ix0 = 0
    AND Task.item_id IN (
        SELECT Task.item_id
        FROM TaskProjectSummary tps2
        INNER JOIN Task ON tps2.id = Task.id
        WHERE tps2.project_id IN (289288092, 289402841, 290055045, 290100821, 290865465, 290881492, 290885441, 290921446, 291178920, 291183471)
        GROUP BY tps2.project_id, Task.item_id
        HAVING COUNT(DISTINCT Task.user_id) = 1
    )
    GROUP BY tps.project_id, Task.item_id, Task.user_id
    HAVING avg_time_minutes BETWEEN 1 AND 2
    ORDER BY RAND()
    LIMIT 10
)
UNION ALL
-- Selects 10 random single-rater tasks completed in 5 minutes or more (SLOW category).
-- Investigates slow submissions to identify training needs, task complexity issues, or quality concerns.
(
    SELECT 
        tps.project_id,
        Task.item_id,
        Task.user_id AS rater_id,
        ROUND(AVG(TIMESTAMPDIFF(SECOND, t_start.timestamp, t_end.timestamp) / 60), 2) AS avg_time_minutes,
        '5+ MIN' AS time_group
    FROM TaskProjectSummary tps
    INNER JOIN Task ON tps.id = Task.id
    INNER JOIN TaskEvent t_start ON tps.id = t_start.id
    INNER JOIN TaskEvent t_end ON t_start.id = t_end.id
    WHERE tps.project_id IN (289288092, 289402841, 290055045, 290100821, 290865465, 290881492, 290885441, 290921446, 291178920, 291183471)
    AND t_start.type = 'ACQUIRED'
    AND t_end.type = 'SUBMITTED'
    AND t_start.ix0 = 0
    AND Task.item_id IN (
        SELECT Task.item_id
        FROM TaskProjectSummary tps2
        INNER JOIN Task ON tps2.id = Task.id
        WHERE tps2.project_id IN (289288092, 289402841, 290055045, 290100821, 290865465, 290881492, 290885441, 290921446, 291178920, 291183471)
        GROUP BY tps2.project_id, Task.item_id
        HAVING COUNT(DISTINCT Task.user_id) = 1
    )
    GROUP BY tps.project_id, Task.item_id, Task.user_id
    HAVING avg_time_minutes >= 5
    ORDER BY RAND()
    LIMIT 10
)
ORDER BY time_group, avg_time_minutes;

-- Weighted stratified sampling (10-17-3) of single-rater tasks prioritizing normal-speed work (1-2 min) where quality issues may hide.
-- Allocates more audit effort to middle-tier tasks while treating obvious outliers (too fast, too slow) as lower priority.

-- Selects 10 random single-rater tasks completed in under 1 minute (TOO FAST category).
-- Enables quality review of rushed submissions to assess if speed correlates with accuracy issues.
(
    SELECT 
        tps.project_id,
        Task.item_id,
        Task.user_id AS rater_id,
        ROUND(AVG(TIMESTAMPDIFF(SECOND, t_start.timestamp, t_end.timestamp) / 60), 2) AS avg_time_minutes,
        'TOO FAST (< 1 min)' AS time_group
    FROM TaskProjectSummary tps
    INNER JOIN Task ON tps.id = Task.id
    INNER JOIN TaskEvent t_start ON tps.id = t_start.id
    INNER JOIN TaskEvent t_end ON t_start.id = t_end.id
    WHERE tps.project_id IN (289288092, 289402841, 290055045, 290100821, 290865465, 290881492, 290885441, 290921446, 291178920, 291183471)
    AND t_start.type = 'ACQUIRED'
    AND t_end.type = 'SUBMITTED'
    AND t_start.ix0 = 0
    AND Task.item_id IN (
        SELECT Task.item_id
        FROM TaskProjectSummary tps2
        INNER JOIN Task ON tps2.id = Task.id
        WHERE tps2.project_id IN (289288092, 289402841, 290055045, 290100821, 290865465, 290881492, 290885441, 290921446, 291178920, 291183471)
        GROUP BY tps2.project_id, Task.item_id
        HAVING COUNT(DISTINCT Task.user_id) = 1
    )
    GROUP BY tps.project_id, Task.item_id, Task.user_id
    HAVING avg_time_minutes < 1
    ORDER BY RAND()
    LIMIT 10
)
UNION ALL
-- Selects 17 random single-rater tasks completed in 1-2 minutes (NORMAL category) - weighted for deeper analysis.
-- Prioritizes audit focus on normal-speed work where quality shortcuts may be hidden beneath acceptable timing.
(
    SELECT 
        tps.project_id,
        Task.item_id,
        Task.user_id AS rater_id,
        ROUND(AVG(TIMESTAMPDIFF(SECOND, t_start.timestamp, t_end.timestamp) / 60), 2) AS avg_time_minutes,
        '1-2 MIN' AS time_group
    FROM TaskProjectSummary tps
    INNER JOIN Task ON tps.id = Task.id
    INNER JOIN TaskEvent t_start ON tps.id = t_start.id
    INNER JOIN TaskEvent t_end ON t_start.id = t_end.id
    WHERE tps.project_id IN (289288092, 289402841, 290055045, 290100821, 290865465, 290881492, 290885441, 290921446, 291178920, 291183471)
    AND t_start.type = 'ACQUIRED'
    AND t_end.type = 'SUBMITTED'
    AND t_start.ix0 = 0
    AND Task.item_id IN (
        SELECT Task.item_id
        FROM TaskProjectSummary tps2
        INNER JOIN Task ON tps2.id = Task.id
        WHERE tps2.project_id IN (289288092, 289402841, 290055045, 290100821, 290865465, 290881492, 290885441, 290921446, 291178920, 291183471)
        GROUP BY tps2.project_id, Task.item_id
        HAVING COUNT(DISTINCT Task.user_id) = 1
    )
    GROUP BY tps.project_id, Task.item_id, Task.user_id
    HAVING avg_time_minutes BETWEEN 1 AND 2
    ORDER BY RAND()
    LIMIT 17
)
UNION ALL
-- Selects only 3 random single-rater tasks completed in 5+ minutes (SLOW category) - minimal sampling.
-- Treats slow submissions as obvious outliers requiring less audit effort since speed issues are already visible.
(
    SELECT 
        tps.project_id,
        Task.item_id,
        Task.user_id AS rater_id,
        ROUND(AVG(TIMESTAMPDIFF(SECOND, t_start.timestamp, t_end.timestamp) / 60), 2) AS avg_time_minutes,
        '5+ MIN' AS time_group
    FROM TaskProjectSummary tps
    INNER JOIN Task ON tps.id = Task.id
    INNER JOIN TaskEvent t_start ON tps.id = t_start.id
    INNER JOIN TaskEvent t_end ON t_start.id = t_end.id
    WHERE tps.project_id IN (289288092, 289402841, 290055045, 290100821, 290865465, 290881492, 290885441, 290921446, 291178920, 291183471)
    AND t_start.type = 'ACQUIRED'
    AND t_end.type = 'SUBMITTED'
    AND t_start.ix0 = 0
    AND Task.item_id IN (
        SELECT Task.item_id
        FROM TaskProjectSummary tps2
        INNER JOIN Task ON tps2.id = Task.id
        WHERE tps2.project_id IN (289288092, 289402841, 290055045, 290100821, 290865465, 290881492, 290885441, 290921446, 291178920, 291183471)
        GROUP BY tps2.project_id, Task.item_id
        HAVING COUNT(DISTINCT Task.user_id) = 1
    )
    GROUP BY tps.project_id, Task.item_id, Task.user_id
    HAVING avg_time_minutes >= 5
    ORDER BY RAND()
    LIMIT 3
)
ORDER BY time_group, avg_time_minutes;
