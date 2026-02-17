-- =============================================================================
-- PII DATA MASKING SCRIPT
-- =============================================================================
-- Purpose: Apply masking functions to sanitize personally identifiable 
--          information (PII) in database tables
-- Prerequisites: create_masking_function.sql must be executed first
-- Usage: psql -U postgres -d database_name -f mask_pii_data.sql
-- Author: Database Team
-- Last Modified: 2025-02-08
-- =============================================================================
-- IMPORTANT: Always run this in a TRANSACTION for safety
-- If anything goes wrong, you can ROLLBACK to restore original data
-- =============================================================================

BEGIN;

-- =============================================================================
-- SECTION 1: MASK EMPLOYEE TABLE
-- =============================================================================
-- Purpose: Anonymize all sensitive employee information
-- Tables affected: employee
-- Records affected: ALL employee records
-- PII masked: email, contact number, first name, middle name, last name
-- =============================================================================

-- Display current state before masking (for verification)
DO $$
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE 'STARTING EMPLOYEE TABLE SANITIZATION';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Total employee records: %', (SELECT COUNT(*) FROM employee);
    RAISE NOTICE 'Sample original data (first record):';
END $$;

-- Show sample before masking (for audit trail)
SELECT 
    id,
    email as original_email,
    contact as original_contact,
    firstname as original_firstname,
    middlename as original_middlename,
    sss as original_sss,
    phic as original_phic,
    hdmf as original_hdmf,
    local_address as original_local_address,
    local_zip_code as original_local_zip_code,
    rfid as original_rfid,
    birthplace as original_birthplace,
    dependents as original_dependents,
    fathersname as original_fathersname,
    contactperson as original_contactperson,
    contactnumber as original_contactnumber,
    contactaddress as original_contactaddress,
    resignationdate as original_resignationdate,
    fingerprint as original_fingerprint,
    birthdate as original_birthdate
FROM employee 
LIMIT 1;

-- Mask all employee sensitive data
-- This updates ALL records in the employee table
UPDATE employee
SET
    email = mask_email(email),          -- Convert to user<hash>@example.com
    contact = mask_phone(contact),      -- Convert to 555-XXXX-XXXX
    firstname = mask_first_name(firstname),   -- Convert to User_<hash>
    middlename = mask_middle_name(middlename), -- Convert to User_<hash>                      -- Remove RFID data completely
    sss = mask_random_number(), -- Replace SSS with random 9-digit number
    phic = mask_random_number(), -- Replace PhilHealth with random 9-digit number
    hdmf = mask_random_number(), -- Replace Pag-IBIG with random 9-digit number
    local_address = NULL,                    -- Remove local address completely
    local_zip_code = NULL,                    -- Remove local zip code completely
    rfid = NULL,  
    birthplace = NULL,                    -- Remove birthplace completely
    dependents = NULL,                    -- Remove dependents completely
    fathersname = NULL,                    -- Remove father's name completely
    contactperson = NULL,                    -- Remove contact person completely
    contactnumber = NULL,                    -- Remove contact number completely
    contactaddress = NULL,                    -- Remove contact address completely
    resignationdate = NULL,                    -- Remove resignation date completely
    fingerprint = NULL,                    -- Remove fingerprint data completely
    birthdate = NULL;                    -- Remove birthdate completely

-- Verify masking was applied
DO $$
DECLARE
    masked_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO masked_count 
    FROM employee 
    WHERE email LIKE '%@example.com';
    
    RAISE NOTICE '✓ Employee records masked: %', masked_count;
END $$;

-- Show sample after masking (for verification)
SELECT 
    id,
    email as masked_email,
    contact as masked_contact,
    firstname as masked_firstname,
    middlename as masked_middlename,
    sss as masked_sss,
    phic as masked_phic,
    hdmf as masked_hdmf,
    local_address as masked_local_address,
    local_zip_code as masked_local_zip_code,
    rfid as masked_rfid,
    birthplace as masked_birthplace,
    dependents as masked_dependents,
    fathersname as masked_fathersname,
    contactperson as masked_contactperson,
    contactnumber as masked_contactnumber,
    contactaddress as masked_contactaddress,
    resignationdate as masked_resignationdate,
    fingerprint as masked_fingerprint,
    birthdate as masked_birthdate
FROM employee 
LIMIT 1;

-- =============================================================================
-- SECTION 2: MASK USERS TABLE - RECORDS LINKED TO EMPLOYEES
-- =============================================================================
-- Purpose: Anonymize user records that are associated with employee records
-- Tables affected: users (linked to employee table via employee_id)
-- Join condition: users.employee_id = employee.id
-- Records affected: Only users who have a valid employee_id reference
-- Business logic: These are users who are also employees in the system
-- =============================================================================

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'MASKING USERS LINKED TO EMPLOYEES';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Users with employee_id: %', (
        SELECT COUNT(*) FROM users WHERE employee_id IS NOT NULL
    );
END $$;

-- Mask user data for records linked to employee table
-- Uses EXISTS clause for better performance on large tables
-- EXISTS is faster than IN or JOIN for this type of update
UPDATE users
SET 
    email = mask_email(email),              -- Anonymize email address
    fullname = mask_first_name(fullname)    -- Anonymize full name
WHERE EXISTS (
    -- Check if this user has a corresponding employee record
    SELECT 1 
    FROM employee 
    WHERE employee.id = users.employee_id
);

-- Verify masking for this segment
DO $$
DECLARE
    masked_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO masked_count 
    FROM users 
    WHERE email LIKE '%@example.com' 
      AND employee_id IS NOT NULL;
    
    RAISE NOTICE '✓ Linked user records masked: %', masked_count;
END $$;

-- =============================================================================
-- SECTION 3: MASK USERS TABLE - EMPLOYEE STATUS WITHOUT EMPLOYEE_ID
-- =============================================================================
-- Purpose: Anonymize user records marked as employees but without employee_id
-- Tables affected: users
-- Conditions: 
--   - employee_id IS NULL (no link to employee table)
--   - is_employee = TRUE (flagged as employee in system)
-- Business logic: These may be:
--   - Former employees with deleted employee records
--   - Employees in transition/onboarding
--   - Data inconsistency cases that need cleanup
-- =============================================================================

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'MASKING USERS WITH EMPLOYEE STATUS (NO LINK)';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Users with is_employee=TRUE but no employee_id: %', (
        SELECT COUNT(*) FROM users 
        WHERE employee_id IS NULL AND is_employee = TRUE
    );
END $$;

-- Mask users who are flagged as employees but have no employee_id
-- This handles edge cases where employee records may have been deleted
-- or where there's a data inconsistency
UPDATE users
SET 
    email = mask_email(email),              -- Anonymize email address
    fullname = mask_first_name(fullname)    -- Anonymize full name
WHERE employee_id IS NULL                   -- No link to employee table
  AND is_employee = TRUE;                   -- But marked as employee

-- Verify masking for this segment
DO $$
DECLARE
    masked_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO masked_count 
    FROM users 
    WHERE email LIKE '%@example.com' 
      AND employee_id IS NULL 
      AND is_employee = TRUE;
    
    RAISE NOTICE '✓ Employee-status user records masked: %', masked_count;
END $$;

-- Automatically commit (comment this out for manual control)
COMMIT;