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
-- Record "Execution Time" here: 0.387 ms (Seq Scan on employee, cost=0.00..35.32)

-- ---- CREATE INDEX ----------------------------------------------------------
CREATE INDEX idx_employee_departmentid ON Employee(DepartmentID);

-- ---- AFTER -----------------------------------------------------------------
EXPLAIN ANALYZE
SELECT e.EmployeeID, e.FirstName, e.LastName, d.DepartmentName, e.BaseSalary
FROM Employee e
JOIN Department d ON e.DepartmentID = d.DepartmentID
WHERE e.DepartmentID = 103;
-- Record "Execution Time" here: 0.945 ms (Bitmap Index Scan on idx_employee_departmentid, cost dropped to 4.96..28.17)

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
-- Record "Execution Time" here: 2.245 ms (Seq Scan on attendancerecord, cost=0.00..439.97)

-- ---- CREATE INDEX ----------------------------------------------------------
CREATE INDEX idx_attendance_workdate ON AttendanceRecord(WorkDate);

-- ---- AFTER -----------------------------------------------------------------
EXPLAIN ANALYZE
SELECT EmployeeID, WorkDate, ClockInTime, ClockOutTime
FROM AttendanceRecord
WHERE WorkDate BETWEEN '2026-01-01' AND '2026-06-30';
-- Record "Execution Time" here: 0.757 ms (Bitmap Index Scan on idx_attendance_workdate, cost=80.32..310.33)

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
-- Record "Execution Time" here: 15.982 ms (Planning Time: 2.073 ms)

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
-- Record "Execution Time" here: 3.496 ms (Planning Time: 0.239 ms)

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

