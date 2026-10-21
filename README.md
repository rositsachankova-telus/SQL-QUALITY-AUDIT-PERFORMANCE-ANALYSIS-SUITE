# SQL-QUALITY-AUDIT-PERFORMANCE-ANALYSIS-SUITE
This repository contains a comprehensive collection of MySQL queries for analyzing project workflows, rater performance, task timing, and quality metrics.


FILES INCLUDED:

1. Project_Discovery_Sampling_and_Quality_Audit.sql
   - Database monitoring and project discovery
   - Template identification and inventory
   - Project status distribution
   - Stratified project sampling across weeks
   - Task submission timing analysis
   - Rater profiling and performance categorization
   - Individual task audit and drill-down

2. Consensus_Two_Rater_Analysis.sql
   - Item identification by number of raters
   - Rater mapping with contact information
   - Detailed assertion comparison between raters
   - Answer completeness validation
   - Release and rework event tracking

3. Single_Rater_Task_Speed_Sampling.sql
   - Evaluation coverage analysis
   - Balanced speed sampling (10-10-10)
   - Weighted speed sampling (10-17-3)
   - Single-perspective quality auditing

TYPICAL WORKFLOW:

Step 1: Project Discovery
- Run SHOW PROCESSLIST to check database health
- Find your template ID using a sample project
- Count total projects under your template
- Review project status distribution
- Filter projects by criteria (locale, task count, date)

Step 2: Sampling Strategy
- Count projects per week
- Review all qualifying projects
- Execute stratified sampling to select representatives

Step 3: Task Timing Analysis
- Retrieve all task submissions with elapsed time
- Calculate statistics (min, max, avg, stdev)
- Categorize submissions by speed
- Identify distribution patterns

Step 4: Rater Profiling
- Profile all raters by speed
- Categorize as TOO FAST, NORMAL, or TOO SLOW
- Identify abnormal performers by project
- Drill down to specific tasks for problem raters

Step 5: Quality Analysis
- Map evaluation coverage (single vs. multi-rater)
- Compare responses from 2-rater items
- Validate answer completeness
- Track rework events
- Retrieve rater contact information

BEFORE RUNNING QUERIES:

- Replace template ID: 138502002 with your actual template ID
- Replace project IDs in sampling queries with your selected projects
- Update date range: 2026-09-22 and INTERVAL 3 MONTH to match your period
- Change locale filter if needed: 'English (US)'
- Adjust task count criteria: BETWEEN 500 AND 1000

SPEED CATEGORIES:

TOO FAST (< 1 min) = Rushed submissions, potential quality shortcuts
NORMAL (1-2 min) = Baseline, appropriately-paced work
5+ MIN = Slow submissions, potential bottlenecks or training needs

RATER PERFORMANCE FLAGS:

Problem Raters are identified when:
- Average submission time < 1 minute (rushed)
- Average submission time > 15 minutes (slow)
- Same pattern occurs across multiple projects

REQUIREMENTS:

- MySQL 5.7 or higher
- Read access to Project, TaskEvent, TaskProjectSummary, Task, ProjectEventPivot, Locale, UserAuthentication, User tables
- Knowledge of your project template IDs and analysis period

PERFORMANCE TIPS:

- Add LIMIT clauses to large result sets
- Run discovery queries first to narrow scope
- Ensure indexes on project_id, user_id, timestamp columns
- Apply date filters early in WHERE clause
- Use user-defined variables to avoid redundant calculations

VERSION: 1.0
Last Updated: 2026-10-12
