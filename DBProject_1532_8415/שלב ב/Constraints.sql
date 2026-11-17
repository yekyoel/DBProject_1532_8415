-- =============================================================================
-- Constraints.sql
-- Stage B: College Manpower & HR Management System
-- Project: DBProject_1532_8415
-- Authors: Yoel Yekutiel, Itai Ben Ami
-- =============================================================================
-- Three new constraints added via ALTER TABLE.
-- None of these existed in the original schema.
-- =============================================================================

-- ============================================================
-- PRE-CHECK: existing rows that would violate the new constraints.
-- All three must return 0 before running the ALTER TABLE commands.
-- If not, fix the data first (see FIX statements below).
-- ============================================================
SELECT COUNT(*) AS low_salaries   FROM Employee         WHERE BaseSalary < 5000;
SELECT COUNT(*) AS bad_clockins   FROM AttendanceRecord WHERE ClockInTime NOT BETWEEN '05:00:00' AND '16:00:00';
SELECT EmployeeID, WorkDate, COUNT(*) AS dup_count
FROM AttendanceRecord GROUP BY EmployeeID, WorkDate HAVING COUNT(*) > 1;

-- FIX (only if needed):
-- UPDATE Employee SET BaseSalary = 5000 WHERE BaseSalary < 5000;
-- DELETE FROM AttendanceRecord a USING AttendanceRecord b
--  WHERE a.EmployeeID = b.EmployeeID AND a.WorkDate = b.WorkDate
--    AND a.RecordID > b.RecordID;

-- ============================================================
-- C1: Minimum salary constraint
-- Motivation: No employee should earn below the legal/college minimum wage.
--             Prevents erroneous data-entry of zero or negative salaries.
-- ============================================================

ALTER TABLE Employee
    ADD CONSTRAINT chk_min_salary
    CHECK (BaseSalary >= 5000);

-- Violation example (will raise ERROR: new row violates check constraint):
 INSERT INTO Employee (EmployeeID, FirstName, LastName, ID_Number, HireDate,
                       BaseSalary, DepartmentID, EmployeeType)
 VALUES (9999, 'Test', 'User', '999999999', '2024-01-01',
         3000, 101, 'Administrative');
-- ERROR:  new row for relation "employee" violates check constraint "chk_min_salary"

-- ============================================================
-- C2: Reasonable clock-in time window
-- Motivation: College operations run between 06:00 and 22:00.
--             Clock-in times outside 05:00–16:00 indicate data-entry errors.
-- ============================================================

ALTER TABLE AttendanceRecord
    ADD CONSTRAINT chk_reasonable_clockin
    CHECK (ClockInTime >= '05:00:00' AND ClockInTime <= '16:00:00');

-- Violation example:
 INSERT INTO AttendanceRecord (EmployeeID, RecordID, WorkDate,
                               ClockInTime, ClockOutTime)
 VALUES (1, 99999, '2026-11-01', '03:00:00', '11:00:00');
-- ERROR:  new row for relation "attendancerecord" violates check constraint
--         "chk_reasonable_clockin"

-- ============================================================
-- C3: One attendance record per employee per day (uniqueness)
-- Motivation: Duplicate punch-ins for the same day would inflate shift counts
--             and corrupt salary calculations. This enforces data integrity.
-- ============================================================

ALTER TABLE AttendanceRecord
    ADD CONSTRAINT uq_employee_workdate
    UNIQUE (EmployeeID, WorkDate);

-- Violation example:
INSERT INTO AttendanceRecord (EmployeeID, RecordID, WorkDate,
                               ClockInTime, ClockOutTime)
 VALUES (1, 99998, '2025-01-05', '08:00:00', '17:00:00');
 (Employee 1 already has a record on 2025-01-05)
-- ERROR:  duplicate key value violates unique constraint "uq_employee_workdate"

-- ============================================================
-- Verification: list all constraints on affected tables
-- ============================================================
SELECT conname, contype, conrelid::regclass AS table_name,
       pg_get_constraintdef(oid) AS definition
FROM pg_constraint
WHERE conrelid IN ('Employee'::regclass, 'AttendanceRecord'::regclass)
ORDER BY table_name, conname;

