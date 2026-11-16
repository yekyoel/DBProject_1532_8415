-- =============================================================================
-- Index.sql
-- Stage B: College Manpower & HR Management System
-- Project: DBProject_1532_8415
-- Authors: Yoel Yekutiel, Itai Ben Ami
-- =============================================================================
-- Three indexes with EXPLAIN ANALYZE timing.
-- Run each numbered section in order; paste the actual timing numbers into
-- the Stage B README after running in pgAdmin.
-- =============================================================================

-- =============================================================================
-- INDEX 1: Employee.DepartmentID
-- Motivation: This foreign-key column is used in nearly every join between
--             Employee and Department (Q1, Q2, Q4, Q7, Q8).  Without an index
--             PostgreSQL does a sequential scan of the 1,000-row Employee
--             table for each lookup.  A B-Tree index allows index scans that
--             jump directly to the matching rows.
-- =============================================================================

-- ---- BEFORE ----------------------------------------------------------------
EXPLAIN ANALYZE
SELECT e.EmployeeID, e.FirstName, e.LastName, d.DepartmentName, e.BaseSalary
FROM Employee e
JOIN Department d ON e.DepartmentID = d.DepartmentID
WHERE e.DepartmentID = 103;
-- Record "Execution Time" here: ____ ms

-- ---- CREATE INDEX ----------------------------------------------------------
CREATE INDEX idx_employee_departmentid ON Employee(DepartmentID);

-- ---- AFTER -----------------------------------------------------------------
EXPLAIN ANALYZE
SELECT e.EmployeeID, e.FirstName, e.LastName, d.DepartmentName, e.BaseSalary
FROM Employee e
JOIN Department d ON e.DepartmentID = d.DepartmentID
WHERE e.DepartmentID = 103;
-- Record "Execution Time" here: ____ ms

-- =============================================================================
-- INDEX 2: AttendanceRecord.WorkDate
-- Motivation: AttendanceRecord has 20,000 rows.  Queries Q1, Q3, Q7 all
--             filter by date ranges (BETWEEN, >= CURRENT_DATE - INTERVAL).
--             A B-Tree index on WorkDate converts full sequential scans into
--             efficient range index scans, dramatically reducing I/O.
-- =============================================================================

-- ---- BEFORE ----------------------------------------------------------------
EXPLAIN ANALYZE
SELECT EmployeeID, WorkDate, ClockInTime, ClockOutTime
FROM AttendanceRecord
WHERE WorkDate BETWEEN '2026-01-01' AND '2026-06-30';
-- Record "Execution Time" here: ____ ms

-- ---- CREATE INDEX ----------------------------------------------------------
CREATE INDEX idx_attendance_workdate ON AttendanceRecord(WorkDate);

-- ---- AFTER -----------------------------------------------------------------
EXPLAIN ANALYZE
SELECT EmployeeID, WorkDate, ClockInTime, ClockOutTime
FROM AttendanceRecord
WHERE WorkDate BETWEEN '2026-01-01' AND '2026-06-30';
-- Record "Execution Time" here: ____ ms

-- =============================================================================
-- INDEX 3: Employee_Training.CompletionDate
-- Motivation: Employee_Training has 20,000 rows and Q6 groups by
--             EXTRACT(YEAR FROM CompletionDate).  Without an index the planner
--             must read and hash every row.  A B-Tree index on CompletionDate
--             lets the planner use an index scan for year-partitioned GROUP BY,
--             reducing sort and aggregation cost.
-- =============================================================================

-- ---- BEFORE ----------------------------------------------------------------
EXPLAIN ANALYZE
SELECT CourseID,
       EXTRACT(YEAR FROM CompletionDate)::INT AS CompletionYear,
       COUNT(*) AS CompletionCount
FROM Employee_Training
GROUP BY CourseID, EXTRACT(YEAR FROM CompletionDate)
ORDER BY CompletionCount DESC;
-- Record "Execution Time" here: ____ ms

-- ---- CREATE INDEX ----------------------------------------------------------
CREATE INDEX idx_training_completiondate ON Employee_Training(CompletionDate);

-- ---- AFTER -----------------------------------------------------------------
EXPLAIN ANALYZE
SELECT CourseID,
       EXTRACT(YEAR FROM CompletionDate)::INT AS CompletionYear,
       COUNT(*) AS CompletionCount
FROM Employee_Training
GROUP BY CourseID, EXTRACT(YEAR FROM CompletionDate)
ORDER BY CompletionCount DESC;
-- Record "Execution Time" here: ____ ms

-- =============================================================================
-- Verify all indexes were created
-- =============================================================================
SELECT indexname, tablename, indexdef
FROM pg_indexes
WHERE indexname IN (
    'idx_employee_departmentid',
    'idx_attendance_workdate',
    'idx_training_completiondate'
)
ORDER BY tablename;

