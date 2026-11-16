-- =============================================================================
-- RollbackCommit.sql
-- Stage B: College Manpower & HR Management System
-- Project: DBProject_1532_8415
-- Authors: Yoel Yekutiel, Itai Ben Ami
-- =============================================================================
-- Demonstrates ROLLBACK and COMMIT transaction control.
-- Run each section independently in pgAdmin (highlight & execute).
-- =============================================================================

-- =============================================================================
-- SECTION 1: ROLLBACK DEMO
-- Action : Give employee 1 a temporary salary spike, then undo it.
-- Expected: After ROLLBACK the salary is identical to the original value.
-- =============================================================================

-- Step 1a: Check original salary
SELECT EmployeeID, FirstName, LastName, BaseSalary
FROM Employee
WHERE EmployeeID = 1;

BEGIN;

-- Step 1b: Apply temporary change
UPDATE Employee
SET BaseSalary = 99999.99
WHERE EmployeeID = 1;

-- Step 1c: Verify change is visible inside the transaction
SELECT EmployeeID, FirstName, LastName, BaseSalary
FROM Employee
WHERE EmployeeID = 1;
-- Expected: BaseSalary = 99999.99

-- Step 1d: Roll back – undo the change
ROLLBACK;

-- Step 1e: Confirm salary is restored to original
SELECT EmployeeID, FirstName, LastName, BaseSalary
FROM Employee
WHERE EmployeeID = 1;
-- Expected: BaseSalary = original value (before the BEGIN block)

-- =============================================================================
-- SECTION 2: COMMIT DEMO
-- Action : Increase department 101's budget by 10% and persist the change.
-- Expected: After COMMIT the new budget survives session reconnection.
-- =============================================================================

-- Step 2a: Check original budget
SELECT DepartmentID, DepartmentName, Budget
FROM Department
WHERE DepartmentID = 101;

BEGIN;

-- Step 2b: Apply budget increase
UPDATE Department
SET Budget = ROUND((Budget * 1.10)::NUMERIC, 2)
WHERE DepartmentID = 101;

-- Step 2c: Verify change inside the transaction
SELECT DepartmentID, DepartmentName, Budget
FROM Department
WHERE DepartmentID = 101;
-- Expected: Budget = original * 1.10

-- Step 2d: Commit – persist the change permanently
COMMIT;

-- Step 2e: Confirm change is still visible after commit
SELECT DepartmentID, DepartmentName, Budget
FROM Department
WHERE DepartmentID = 101;
-- Expected: Same updated value as step 2c

