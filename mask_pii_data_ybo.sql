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

-- Mask all employee sensitive data
-- This updates ALL records in the employee table
UPDATE employee
SET
    name = mask_first_name(name),   -- Convert to User_<hash>
    email = mask_email(email),          -- Convert to user<hash>@example.com
    city_id = NULL,      -- Remove city data completely
    country_id = NULL,      -- Remove country data completely
    address1 = NULL,      -- Remove address1 completely
    address2 = NULL,      -- Remove address2 completely
    complete_location = NULL,      -- Remove complete location data completely
    tin = mask_random_number(), -- Replace TIN with random 9-digit number
    bank_account_no = mask_random_number(); -- Replace bank account with random 9-digit number

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

-- =============================================================================
-- SECTION 2: MASK User TABLE - NON-YAHSHUAN
-- =============================================================================
-- Purpose: Anonymize user records marked as non-yahshuan (is_yahshuan=FALSE)
-- Tables affected: User
-- Conditions: 
--   - is_yahshuan = FALSE (flagged as non-yahshuan in system)
-- Business logic: These may be:
--   - Data inconsistency cases that need cleanup
-- =============================================================================

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'MASKING User - NON-YAHSHUAN';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'User with is_yahshuan=FALSE: %', (
        SELECT COUNT(*) FROM public."User" 
        WHERE is_yahshuan = FALSE
    );
END $$;

UPDATE public."User"
SET 
    email = mask_email(email),              -- Anonymize email address
    fullname = mask_first_name(fullname)    -- Anonymize full name
WHERE is_yahshuan = FALSE;                   -- Mask User not marked as yahshuan

-- Verify masking for this segment
DO $$
DECLARE
    masked_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO masked_count 
    FROM public."User" 
    WHERE email LIKE '%@example.com' 
      AND is_yahshuan = FALSE;
    
    RAISE NOTICE '✓ User records masked: %', masked_count;
END $$;

-- Automatically commit (comment this out for manual control)
COMMIT;