-- =============================================================================
-- Queries.sql
-- Stage B: College Manpower & HR Management System
-- Project: DBProject_1532_8415
-- Authors: Yoel Yekutiel, Itai Ben Ami
-- =============================================================================

-- =============================================================================
-- DUAL-FORM SELECT QUERIES (Q1–Q4): Each written in TWO ways
-- =============================================================================

-- ============================================================
-- Q1: Monthly attendance summary per department
-- Screen: Dashboard
-- Purpose: Show HR managers a monthly overview of shifts per department
-- ============================================================

-- Q1 Form A: JOIN approach
-- Efficiency: Direct JOIN, one pass, benefits from index on Employee.DepartmentID
SELECT
    d.DepartmentName,
    EXTRACT(YEAR  FROM a.WorkDate)::INT   AS WorkYear,
    EXTRACT(MONTH FROM a.WorkDate)::INT   AS WorkMonth,
    COUNT(DISTINCT a.EmployeeID)          AS EmployeeCount,
    COUNT(a.RecordID)                     AS TotalShifts,
    ROUND(
        AVG(
            EXTRACT(EPOCH FROM (a.ClockOutTime - a.ClockInTime)) / 3600.0
        )::NUMERIC, 2
    )                                     AS AvgShiftHours
FROM AttendanceRecord a
JOIN Employee         e ON a.EmployeeID    = e.EmployeeID
JOIN Department       d ON e.DepartmentID  = d.DepartmentID
GROUP BY d.DepartmentName,
         EXTRACT(YEAR  FROM a.WorkDate),
         EXTRACT(MONTH FROM a.WorkDate)
ORDER BY d.DepartmentName,
         WorkYear,
         WorkMonth;

-- Q1 Form B: Subquery / CTE approach
-- Efficiency: CTE materialises the per-employee aggregation first;
--             useful when the planner would otherwise re-evaluate the
--             aggregate for every outer row (older PostgreSQL versions).
WITH MonthlyStats AS (
    SELECT
        e.DepartmentID,
        EXTRACT(YEAR  FROM a.WorkDate)::INT AS WorkYear,
        EXTRACT(MONTH FROM a.WorkDate)::INT AS WorkMonth,
        COUNT(DISTINCT a.EmployeeID)        AS EmployeeCount,
        COUNT(a.RecordID)                   AS TotalShifts,
        ROUND(
            AVG(
                EXTRACT(EPOCH FROM (a.ClockOutTime - a.ClockInTime)) / 3600.0
            )::NUMERIC, 2
        )                                   AS AvgShiftHours
    FROM AttendanceRecord a
    JOIN Employee e ON a.EmployeeID = e.EmployeeID
    GROUP BY e.DepartmentID,
             EXTRACT(YEAR  FROM a.WorkDate),
             EXTRACT(MONTH FROM a.WorkDate)
)
SELECT
    d.DepartmentName,
    ms.WorkYear,
    ms.WorkMonth,
    ms.EmployeeCount,
    ms.TotalShifts,
    ms.AvgShiftHours
FROM MonthlyStats ms
JOIN Department d ON ms.DepartmentID = d.DepartmentID
ORDER BY d.DepartmentName, ms.WorkYear, ms.WorkMonth;

-- ============================================================
-- Q2: Employees who completed MORE training courses in 2025 than the
--     2025 average per employee
-- Screen: Staff
-- Purpose: Identify the most active learners of the year for HR review
-- ============================================================

-- Q2 Form A: Subquery in HAVING clause
-- Efficiency: Joins all 2025 training rows to Employee + Department BEFORE
--             grouping, and groups by several text columns.
SELECT
    e.EmployeeID,
    e.FirstName,
    e.LastName,
    d.DepartmentName,
    e.EmployeeType,
    COUNT(et.CourseID) AS CourseCount2025
FROM Employee e
JOIN Department        d  ON e.DepartmentID = d.DepartmentID
JOIN Employee_Training et ON e.EmployeeID   = et.EmployeeID
WHERE EXTRACT(YEAR FROM et.CompletionDate) = 2025
GROUP BY e.EmployeeID, e.FirstName, e.LastName, d.DepartmentName, e.EmployeeType
HAVING COUNT(et.CourseID) > (
    SELECT AVG(course_count)
    FROM (
        SELECT COUNT(CourseID) AS course_count
        FROM Employee_Training
        WHERE EXTRACT(YEAR FROM CompletionDate) = 2025
        GROUP BY EmployeeID
    ) sub
)
ORDER BY CourseCount2025 DESC, e.LastName;

-- Q2 Form B: JOIN with derived table
-- Efficiency: The derived table (avg_sub) is computed once and joined;
--             the planner may choose a hash join which is faster when the
--             outer table is large, avoiding a correlated re-scan.
SELECT
    e.EmployeeID,
    e.FirstName,
    e.LastName,
    d.DepartmentName,
    e.EmployeeType,
    ec.CourseCount2025
FROM (
    SELECT EmployeeID, COUNT(CourseID) AS CourseCount2025
    FROM Employee_Training
    WHERE EXTRACT(YEAR FROM CompletionDate) = 2025
    GROUP BY EmployeeID
) ec
JOIN Employee   e ON ec.EmployeeID   = e.EmployeeID
JOIN Department d ON e.DepartmentID  = d.DepartmentID
CROSS JOIN (
    SELECT AVG(CourseCount2025) AS AvgCourses FROM (
        SELECT COUNT(CourseID) AS CourseCount2025
        FROM Employee_Training
        WHERE EXTRACT(YEAR FROM CompletionDate) = 2025
        GROUP BY EmployeeID
    ) sub
) avg_sub
WHERE ec.CourseCount2025 > avg_sub.AvgCourses
ORDER BY ec.CourseCount2025 DESC, e.LastName;

-- ============================================================
-- Q3: Employees with NO attendance record in the last 3 months
-- Screen: Attendance
-- Purpose: Flag potentially inactive / absent employees for HR follow-up
-- ============================================================

-- Q3 Form A: NOT IN with subquery
-- Efficiency: Simple and readable; works well when the subquery result set
--             is small (few active employees in the period).
SELECT
    e.EmployeeID,
    e.FirstName,
    e.LastName,
    d.DepartmentName,
    e.HireDate,
    EXTRACT(YEAR  FROM e.HireDate)::INT AS HireYear,
    EXTRACT(MONTH FROM e.HireDate)::INT AS HireMonth
FROM Employee e
JOIN Department d ON e.DepartmentID = d.DepartmentID
WHERE e.EmployeeID NOT IN (
    SELECT DISTINCT EmployeeID
    FROM AttendanceRecord
    WHERE WorkDate >= CURRENT_DATE - INTERVAL '3 months'
)
ORDER BY e.LastName, e.FirstName;

-- Q3 Form B: NOT EXISTS
-- Efficiency: Short-circuits on the first matching row; superior to NOT IN
--             when the subquery could potentially return NULLs (NOT IN with
--             NULLs returns no rows at all), and usually faster on large sets
--             because PostgreSQL can use an anti-join plan.
SELECT
    e.EmployeeID,
    e.FirstName,
    e.LastName,
    d.DepartmentName,
    e.HireDate,
    EXTRACT(YEAR  FROM e.HireDate)::INT AS HireYear,
    EXTRACT(MONTH FROM e.HireDate)::INT AS HireMonth
FROM Employee e
JOIN Department d ON e.DepartmentID = d.DepartmentID
WHERE NOT EXISTS (
    SELECT 1
    FROM AttendanceRecord a
    WHERE a.EmployeeID = e.EmployeeID
      AND a.WorkDate >= CURRENT_DATE - INTERVAL '3 months'
)
ORDER BY e.LastName, e.FirstName;

-- ============================================================
-- Q4: Budget utilisation vs average salary per department
-- Screen: Departments
-- Purpose: Show finance team salary burden relative to departmental budget
-- ============================================================

-- Q4 Form A: JOIN + GROUP BY
-- Efficiency: Single aggregation pass; straightforward execution plan.
SELECT
    d.DepartmentName,
    d.Budget,
    COUNT(e.EmployeeID)                        AS EmployeeCount,
    ROUND(SUM(e.BaseSalary)::NUMERIC, 2)       AS TotalSalary,
    ROUND(AVG(e.BaseSalary)::NUMERIC, 2)       AS AvgSalary,
    ROUND((SUM(e.BaseSalary) / d.Budget * 100)::NUMERIC, 2) AS SalaryBudgetPct
FROM Department d
JOIN Employee e ON d.DepartmentID = e.DepartmentID
GROUP BY d.DepartmentID, d.DepartmentName, d.Budget
ORDER BY SalaryBudgetPct DESC;

-- Q4 Form B: Window function (AVG OVER PARTITION BY)
-- Efficiency: Computes the department average in a single window pass
--             alongside individual rows — useful when the caller also needs
--             individual employee salaries in the same result set.
--             For the pure department-level summary Form A is cheaper.
SELECT DISTINCT
    d.DepartmentName,
    d.Budget,
    COUNT(e.EmployeeID)      OVER (PARTITION BY d.DepartmentID) AS EmployeeCount,
    ROUND(SUM(e.BaseSalary)  OVER (PARTITION BY d.DepartmentID)::NUMERIC, 2) AS TotalSalary,
    ROUND(AVG(e.BaseSalary)  OVER (PARTITION BY d.DepartmentID)::NUMERIC, 2) AS AvgSalary,
    ROUND(
        (SUM(e.BaseSalary) OVER (PARTITION BY d.DepartmentID) / d.Budget * 100)::NUMERIC, 2
    ) AS SalaryBudgetPct
FROM Department d
JOIN Employee e ON d.DepartmentID = e.DepartmentID
ORDER BY SalaryBudgetPct DESC;

-- =============================================================================
-- SINGLE-FORM SELECT QUERIES (Q5–Q8)
-- =============================================================================

-- ============================================================
-- Q5: Tenured academic staff hired before 2015, ordered by seniority
-- Screen: Staff
-- Purpose: List long-serving tenured academics for recognition / promotion review
-- ============================================================
SELECT
    e.EmployeeID,
    e.FirstName,
    e.LastName,
    d.DepartmentName,
    ac.ResearchField,
    ac.TenureStatus,
    EXTRACT(YEAR  FROM e.HireDate)::INT                     AS HireYear,
    EXTRACT(MONTH FROM e.HireDate)::INT                     AS HireMonth,
    EXTRACT(DAY   FROM e.HireDate)::INT                     AS HireDay,
    DATE_PART('year', AGE(CURRENT_DATE, e.HireDate))::INT   AS YearsOfService
FROM Employee     e
JOIN AcademicStaff ac ON e.EmployeeID   = ac.EmployeeID
JOIN Department    d  ON e.DepartmentID = d.DepartmentID
WHERE ac.TenureStatus = 'Tenured'
  AND EXTRACT(YEAR FROM e.HireDate) < 2015
ORDER BY e.HireDate ASC;

-- ============================================================
-- Q6: Top 5 most completed training courses with yearly breakdown
-- Screen: Staff / Training report
-- Purpose: Identify popular courses for future HR training budget allocation
-- ============================================================
SELECT
    tc.CourseName,
    tc.ProviderName,
    EXTRACT(YEAR FROM et.CompletionDate)::INT  AS CompletionYear,
    EXTRACT(MONTH FROM et.CompletionDate)::INT AS CompletionMonth,
    COUNT(*)                                   AS CompletionCount
FROM Employee_Training et
JOIN TrainingCourse tc ON et.CourseID = tc.CourseID
GROUP BY tc.CourseID, tc.CourseName, tc.ProviderName,
         EXTRACT(YEAR  FROM et.CompletionDate),
         EXTRACT(MONTH FROM et.CompletionDate)
HAVING tc.CourseID IN (
    SELECT CourseID
    FROM Employee_Training
    GROUP BY CourseID
    ORDER BY COUNT(*) DESC
    LIMIT 5
)
ORDER BY CompletionCount DESC, CompletionYear, CompletionMonth;

-- ============================================================
-- Q7: Employees whose average 2026 shift is longer than the college-wide
--     2026 average by more than 15 minutes
-- Screen: Attendance / Overtime report
-- Purpose: Detect chronic overtime for wellbeing & compliance review
-- ============================================================
SELECT
    e.EmployeeID,
    e.FirstName,
    e.LastName,
    d.DepartmentName,
    COUNT(a.RecordID)                        AS ShiftCount,
    ROUND(
        AVG(
            EXTRACT(EPOCH FROM (a.ClockOutTime - a.ClockInTime)) / 3600.0
        )::NUMERIC, 2
    )                                        AS AvgShiftHours,
    EXTRACT(YEAR FROM MIN(a.WorkDate))::INT  AS YearRecorded
FROM AttendanceRecord a
JOIN Employee   e ON a.EmployeeID   = e.EmployeeID
JOIN Department d ON e.DepartmentID = d.DepartmentID
WHERE EXTRACT(YEAR FROM a.WorkDate) = 2026
GROUP BY e.EmployeeID, e.FirstName, e.LastName, d.DepartmentName
HAVING AVG(
    EXTRACT(EPOCH FROM (a.ClockOutTime - a.ClockInTime)) / 3600.0
) > (
    -- college-wide average shift length in 2026 + 15 minutes
    SELECT AVG(EXTRACT(EPOCH FROM (ClockOutTime - ClockInTime)) / 3600.0) + 0.25
    FROM AttendanceRecord
    WHERE EXTRACT(YEAR FROM WorkDate) = 2026
)
ORDER BY AvgShiftHours DESC;

-- ============================================================
-- Q8: Senior administrative staff (Director/Head) with subordinate counts
-- Screen: Departments / Management report
-- Purpose: Show span-of-control for each senior manager
-- ============================================================
SELECT
    mgr.EmployeeID                              AS ManagerID,
    mgr_e.FirstName || ' ' || mgr_e.LastName   AS ManagerName,
    d.DepartmentName,
    mgr.ManagementLevel,
    COUNT(sub.EmployeeID)                       AS SubordinateCount,
    MIN(e_sub.HireDate)                         AS EarliestSubordinateHireDate,
    MAX(e_sub.HireDate)                         AS LatestSubordinateHireDate
FROM AdministrativeStaff mgr
JOIN Employee mgr_e ON mgr.EmployeeID   = mgr_e.EmployeeID
JOIN Department d   ON mgr_e.DepartmentID = d.DepartmentID
JOIN AdministrativeStaff sub ON sub.EmployeeID <> mgr.EmployeeID
    AND sub.ManagementLevel NOT IN ('Director','Head of Administration')
JOIN Employee e_sub ON sub.EmployeeID = e_sub.EmployeeID
    AND e_sub.DepartmentID = mgr_e.DepartmentID
WHERE mgr.ManagementLevel IN ('Director','Head of Administration')
GROUP BY mgr.EmployeeID, mgr_e.FirstName, mgr_e.LastName,
         d.DepartmentName, mgr.ManagementLevel
HAVING COUNT(sub.EmployeeID) > 5
ORDER BY SubordinateCount DESC;

-- =============================================================================
-- DELETE QUERIES (3)
-- =============================================================================

-- D1: Archive cleanup — delete Q1-2025 (Jan–Mar) attendance records of
--     non-permanent academic staff (Adjunct / Visiting Professor)
-- Screen: Attendance — "Archive / Clean old records"
DELETE FROM AttendanceRecord
WHERE EXTRACT(YEAR  FROM WorkDate) = 2025
  AND EXTRACT(MONTH FROM WorkDate) BETWEEN 1 AND 3
  AND EmployeeID IN (
      SELECT EmployeeID
      FROM AcademicStaff
      WHERE TenureStatus IN ('Adjunct', 'Visiting Professor')
  );

-- D2: Delete training completion records for a course that has been retired
--     (course 218 — decommissioned provider)
DELETE FROM Employee_Training
WHERE CourseID = 218
  AND EXTRACT(YEAR FROM CompletionDate) < 2023;

-- D3: Data-quality cleanup — delete training records whose CompletionDate is
--     BEFORE the employee's HireDate (impossible, caused by bad data entry)
-- Screen: Staff — "Training history validation"
DELETE FROM Employee_Training et
USING Employee e
WHERE et.EmployeeID = e.EmployeeID
  AND et.CompletionDate < e.HireDate;

-- =============================================================================
-- UPDATE QUERIES (3)
-- =============================================================================

-- U1: Annual 5% salary increase for all Tenured academic staff
-- Screen: Staff — "Apply salary adjustment"
UPDATE Employee
SET BaseSalary = ROUND((BaseSalary * 1.05)::NUMERIC, 2)
WHERE EmployeeID IN (
    SELECT EmployeeID
    FROM AcademicStaff
    WHERE TenureStatus = 'Tenured'
);

-- U2: Promote eligible Administrative staff from 'Mid' to 'Senior'
--     Eligibility: hired before 2020 and BaseSalary >= 8000
-- Screen: Staff — "Bulk promotion"
UPDATE AdministrativeStaff
SET ManagementLevel = 'Senior'
WHERE ManagementLevel = 'Mid'
  AND EmployeeID IN (
      SELECT EmployeeID
      FROM Employee
      WHERE EXTRACT(YEAR FROM HireDate) < 2020
        AND BaseSalary >= 8000
  );

-- U3: Increase budget by 8% for departments whose total salary exceeds
--     70% of their current budget (budget pressure relief)
-- Screen: Departments — "Budget rebalance"
UPDATE Department
SET Budget = ROUND((Budget * 1.08)::NUMERIC, 2)
WHERE DepartmentID IN (
    SELECT e.DepartmentID
    FROM Employee e
    JOIN Department d ON e.DepartmentID = d.DepartmentID
    GROUP BY e.DepartmentID, d.Budget
    HAVING SUM(e.BaseSalary) > d.Budget * 0.70
);

