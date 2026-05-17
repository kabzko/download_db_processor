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

-- =============================================================================
-- SECTION 3: MASK User Company TABLE
-- =============================================================================
-- Purpose: Anonymize user records marked
-- Tables affected: User_company
-- Business logic: These may be:
--   - Data inconsistency cases that need cleanup
-- =============================================================================

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'MASKING User Company';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'User Company %', (
        SELECT COUNT(*) FROM public."User_company"
    );
END $$;

UPDATE public."User_company"
SET 
    email = mask_email(email),              -- Anonymize email address
    name = mask_first_name(name),    -- Anonymize full name
    logo = NULL, -- Remove logo completely
    logo_thumbnail = NULL, -- Remove logo thumbnail completely
    bir_number = NULL, -- Remove BIR Number data completely
    complete_address = NULL, -- Remove complete address data completely
    contact_person = NULL, -- Remove contact person data completely
    telephone = NULL, -- Remove telephone data completely
    tin = mask_random_number(), -- Replace TIN with random 9-digit number
    vat_number = NULL, -- Remove VAT number completely
    code = mask_first_name(code), -- Remove code completely
    authorized_representative_name = NULL, -- Remove authorized representative name completely
    authorized_representative_position = NULL, -- Remove authorized representative position completely
    authorized_representative_tin = NULL, -- Remove authorized representative TIN completely
    authorized_representative_phone = NULL; -- Remove authorized representative contact number completely

-- Verify masking for this segment
DO $$
DECLARE
    masked_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO masked_count 
    FROM public."User_company" 
    WHERE email LIKE '%@example.com';
    
    RAISE NOTICE '✓ User Company records masked: %', masked_count;
END $$;

-- =============================================================================
-- SECTION 4: MASK Supplier TABLE
-- =============================================================================
-- Purpose: Anonymize supplier records marked
-- Tables affected: Supplier
-- Business logic: These may be:
--   - Data inconsistency cases that need cleanup
-- =============================================================================

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'MASKING Supplier';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Supplier %', (
        SELECT COUNT(*) FROM public."supplier"
    );
END $$;

UPDATE public."supplier"
SET 
    email = mask_email(email),              -- Anonymize email address
    name = mask_first_name(name),    -- Anonymize full name
    code = mask_first_name(code), -- Remove code completely
    tin = mask_random_number(), -- Replace TIN with random 9-digit number
    address = NULL, -- Remove address completely
    contact_person = NULL, -- Remove contact person data completely
    payee = mask_first_name(payee); -- Remove payee completely

-- Verify masking for this segment
DO $$
DECLARE
    masked_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO masked_count 
    FROM public."supplier" 
    WHERE email LIKE '%@example.com';
    
    RAISE NOTICE '✓ Supplier records masked: %', masked_count;
END $$;

-- Automatically commit (comment this out for manual control)
COMMIT;