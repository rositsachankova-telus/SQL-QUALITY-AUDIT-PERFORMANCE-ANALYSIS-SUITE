-- Identifies items evaluated by exactly 2 raters across selected projects, displaying rater IDs, emails, and total ratings per item.
-- Useful for finding consensus-based evaluations and tracking who evaluated each task.
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


-- Retrieves all task assertions (answers/labels) for a specific item evaluated by specific raters on a project.
-- Used to compare detailed answers between raters to identify agreement or disagreement on responses.
SELECT 
    tps.project_id,
    Task.item_id,
    Task.user_id,
    ua.login AS rater_email,
    ta.key,
    ta.value
FROM TaskProjectSummary tps
INNER JOIN Task ON tps.id = Task.id
LEFT JOIN UserAuthentication ua ON Task.user_id = ua.id
LEFT JOIN TaskAssertions ta ON tps.id = ta.id
WHERE tps.project_id = 289288092
AND Task.item_id = 56647455041
AND Task.user_id IN (55716979, 65723012)
ORDER BY Task.user_id, ta.key;


-- Counts the number of answers submitted by each rater for items that were evaluated by exactly 2 raters across projects.
-- Helps identify if both raters completed all required answers and reveals answer submission completeness.
SELECT 
    tps.project_id,
    Task.item_id,
    Task.user_id,
    ua.login AS rater_email,
    COUNT(ta.key) AS answer_count
FROM TaskProjectSummary tps
INNER JOIN Task ON tps.id = Task.id
LEFT JOIN UserAuthentication ua ON Task.user_id = ua.id
LEFT JOIN TaskAssertions ta ON tps.id = ta.id
WHERE tps.project_id IN (289288092, 289402841, 290055045, 290100821, 290865465, 290881492, 290885441, 290921446, 291178920, 291183471)
AND Task.item_id IN (
    SELECT Task.item_id
    FROM Task
    INNER JOIN TaskProjectSummary tps2 ON tps2.id = Task.id
    WHERE tps2.project_id IN (289288092, 289402841, 290055045, 290100821, 290865465, 290881492, 290885441, 290921446, 291178920, 291183471)
    GROUP BY Task.item_id
    HAVING COUNT(DISTINCT Task.user_id) = 2
)
GROUP BY tps.project_id, Task.item_id, Task.user_id, ua.login
ORDER BY tps.project_id, Task.item_id, Task.user_id;


-- Retrieves release events (task returns) for 2-rater items, including timestamp and reason why the task was released back.
-- Identifies tasks that were sent back for rework and tracks which rater released it and why.
SELECT 
    tps.project_id,
    Task.item_id,
    Task.user_id,
    ua.login AS rater_email,
    te.timestamp AS released_time,
    te.description AS release_reason
FROM TaskProjectSummary tps
INNER JOIN Task ON tps.id = Task.id
LEFT JOIN UserAuthentication ua ON Task.user_id = ua.id
LEFT JOIN TaskEvent te ON tps.id = te.id
WHERE tps.project_id IN (289288092, 289402841, 290055045, 290100821, 290865465, 290881492, 290885441, 290921446, 291178920, 291183471)
AND Task.item_id IN (
    SELECT Task.item_id
    FROM Task
    INNER JOIN TaskProjectSummary tps2 ON tps2.id = Task.id
    WHERE tps2.project_id IN (289288092, 289402841, 290055045, 290100821, 290865465, 290881492, 290885441, 290921446, 291178920, 291183471)
    GROUP BY Task.item_id
    HAVING COUNT(DISTINCT Task.user_id) = 2
)
AND te.type = 'RELEASED'
ORDER BY tps.project_id, Task.item_id, Task.user_id;

