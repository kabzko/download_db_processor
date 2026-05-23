-- =============================================================================
-- MASKING FUNCTIONS FOR PII DATA SANITIZATION
-- =============================================================================
-- Purpose: Create reusable PostgreSQL functions to mask/anonymize sensitive 
--          personally identifiable information (PII) in database records
-- Usage: Run this script BEFORE running mask_pii_data.sql
-- Author: Database Team
-- Last Modified: 2025-02-08
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Function: mask_email
-- -----------------------------------------------------------------------------
-- Purpose: Converts real email addresses to anonymized format while maintaining
--          uniqueness through MD5 hashing
-- Input: email TEXT - Original email address
-- Output: TEXT - Masked email in format: user<md5_hash>@example.com
-- Example: john.doe@gmail.com -> user5d41402abc4b2a76b9719d911017c592@example.com
-- Properties: IMMUTABLE - Same input always produces same output (deterministic)
--             This ensures referential integrity across related tables
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION mask_email(email TEXT)
RETURNS TEXT AS $$
BEGIN
    -- Handle NULL values to prevent errors
    IF email IS NULL THEN
        RETURN NULL;
    END IF;
    
    -- Generate consistent anonymized email using MD5 hash
    -- MD5 ensures same email always maps to same masked value
    -- This preserves relationships between tables (foreign keys)
    RETURN 'user' || md5(email)::text || '@example.com';
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- -----------------------------------------------------------------------------
-- Function: mask_phone
-- -----------------------------------------------------------------------------
-- Purpose: Replaces real phone numbers with random fake numbers
-- Input: phone TEXT - Original phone number
-- Output: TEXT - Random phone in format: 555-XXXX-XXXX
-- Example: +1-234-567-8900 -> 555-1234-5678
-- Properties: VOLATILE - Different output for each call (non-deterministic)
--             Use this when you don't need to preserve relationships
-- Note: All masked phones start with 555 (reserved for fictional use in North America)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION mask_phone(phone TEXT)
RETURNS TEXT AS $$
BEGIN
    -- Handle NULL values
    IF phone IS NULL THEN
        RETURN NULL;
    END IF;
    
    -- Generate random phone number with 555 prefix (fictional)
    -- LPAD ensures 4-digit format with leading zeros if needed
    -- random() generates values between 0 and 1, multiplied to get 0-9999
    RETURN '555-' || LPAD((random() * 9999)::int::text, 4, '0') || '-' || LPAD((random() * 9999)::int::text, 4, '0');
END;
$$ LANGUAGE plpgsql VOLATILE;

-- -----------------------------------------------------------------------------
-- Table: mask_last_names
-- -----------------------------------------------------------------------------
-- Purpose: Lookup table of fake last names used by mask_full_name()
-- Option 3: Hardcoded name table - no extension required
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS mask_last_names (name TEXT);
TRUNCATE mask_last_names;
INSERT INTO mask_last_names (name) VALUES
    ('Smith'),('Johnson'),('Williams'),('Brown'),('Jones'),
    ('Garcia'),('Miller'),('Davis'),('Wilson'),('Taylor'),
    ('Anderson'),('Thomas'),('Jackson'),('White'),('Harris'),
    ('Martin'),('Thompson'),('Young'),('Allen'),('King'),
    ('Wright'),('Scott'),('Torres'),('Nguyen'),('Hill'),
    ('Flores'),('Green'),('Adams'),('Nelson'),('Baker'),
    ('Rivera'),('Campbell'),('Mitchell'),('Carter'),('Roberts'),
    ('Gomez'),('Phillips'),('Evans'),('Turner'),('Diaz'),
    ('Parker'),('Cruz'),('Edwards'),('Collins'),('Reyes'),
    ('Stewart'),('Morris'),('Morales'),('Murphy'),('Cook'),
    ('Rogers'),('Gutierrez'),('Ortiz'),('Morgan'),('Cooper'),
    ('Peterson'),('Bailey'),('Reed'),('Kelly'),('Howard'),
    ('Ramos'),('Kim'),('Cox'),('Ward'),('Richardson'),
    ('Watson'),('Brooks'),('Chavez'),('Wood'),('James'),
    ('Bennett'),('Gray'),('Mendoza'),('Ruiz'),('Hughes'),
    ('Price'),('Alvarez'),('Castillo'),('Sanders'),('Patel'),
    ('Myers'),('Long'),('Ross'),('Foster'),('Jimenez'),
    ('Powell'),('Jenkins'),('Perry'),('Russell'),('Sullivan'),
    ('Bell'),('Coleman'),('Butler'),('Henderson'),('Barnes'),
    ('Gonzales'),('Fisher'),('Vasquez'),('Simmons'),('Romero');

-- -----------------------------------------------------------------------------
-- Function: mask_full_name
-- -----------------------------------------------------------------------------
-- Purpose: Anonymizes full names with a realistic-looking fake name
-- Input: fullname TEXT - Original full name (e.g. "John Smith")
-- Output: TEXT - Masked name in format: <FirstWord> <RandomLastName>
-- Example: "John Smith" -> "John Carter"
-- Properties: VOLATILE - Random last name picked on each call
-- Note: Uses mask_last_names table (Option 3), no extension required
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION mask_full_name(fullname TEXT)
RETURNS TEXT AS $$
DECLARE
    random_last_name TEXT;
BEGIN
    -- Handle NULL values
    IF fullname IS NULL THEN
        RETURN NULL;
    END IF;

    -- Pick a random last name from the mask_last_names table
    SELECT name INTO random_last_name
    FROM mask_last_names
    ORDER BY random()
    LIMIT 1;

    -- Extract the first word of the real full name and append the random last name
    RETURN split_part(fullname, ' ', 1) || ' ' || random_last_name;
END;
$$ LANGUAGE plpgsql VOLATILE;

-- -----------------------------------------------------------------------------
-- Function: mask_code
-- -----------------------------------------------------------------------------
-- Purpose: Anonymizes code values while maintaining uniqueness
-- Input: code TEXT - Original code value
-- Output: TEXT - Masked code in format: Code_<8_char_hash>
-- Example: ABC123 -> Code_5d41402a
-- Properties: IMMUTABLE - Same input always produces same output (deterministic)
--             This ensures referential integrity across related tables
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION mask_code(code TEXT)
RETURNS TEXT AS $$
BEGIN
    -- Handle NULL values
    IF code IS NULL THEN
        RETURN NULL;
    END IF;

    -- Generate consistent masked code using first 8 chars of MD5 hash
    RETURN 'Code_' || substr(md5(code), 1, 8);
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- -----------------------------------------------------------------------------
-- Function: mask_company
-- -----------------------------------------------------------------------------
-- Purpose: Anonymizes company names while maintaining uniqueness
-- Input: company TEXT - Original company name
-- Output: TEXT - Masked company in format: Company_<8_char_hash>
-- Example: Acme Corp -> Company_3d41902a
-- Properties: IMMUTABLE - Same input always produces same output (deterministic)
--             This ensures referential integrity across related tables
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION mask_company(company TEXT)
RETURNS TEXT AS $$
BEGIN
    -- Handle NULL values
    IF company IS NULL THEN
        RETURN NULL;
    END IF;

    -- Generate consistent masked company name using first 8 chars of MD5 hash
    RETURN 'Company_' || substr(md5(company), 1, 8);
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- -----------------------------------------------------------------------------
-- Function: mask_credit_card
-- -----------------------------------------------------------------------------
-- Purpose: Masks credit card numbers while preserving last 4 digits for reference
-- Input: cc TEXT - Original credit card number
-- Output: TEXT - Masked card in format: XXXX-XXXX-XXXX-1234
-- Example: 1234-5678-9012-3456 -> XXXX-XXXX-XXXX-3456
-- Properties: IMMUTABLE - Same card always produces same masked output
-- Use Case: Support staff can verify card type/bank without seeing full number
-- Compliance: Meets PCI-DSS requirement to mask all but last 4 digits
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION mask_credit_card(cc TEXT)
RETURNS TEXT AS $$
BEGIN
    -- Handle NULL values (not all users may have saved cards)
    IF cc IS NULL THEN
        RETURN NULL;
    END IF;
    
    -- Mask all digits except last 4
    -- RIGHT() function extracts rightmost characters
    -- This allows customer service to identify card without exposing full number
    RETURN 'XXXX-XXXX-XXXX-' || RIGHT(cc, 4);
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- -----------------------------------------------------------------------------
-- Function: mask_random_number
-- -----------------------------------------------------------------------------
-- Purpose: Generates a random 9-digit number and returns it as a string
-- Input: None (no parameters required)
-- Output: TEXT - A random 9-digit number as string e.g. '482031947'
-- Example: SELECT mask_random_number(); -> '739401823'
-- Properties: VOLATILE - Different random output on every call
-- Use Case: Masking employee IDs, reference numbers, national IDs,
--           or any numeric identifier that must remain 9 digits
-- Note: Always returns exactly 9 digits (padded with leading zeros if needed)
--       Range: 100000000 to 999999999 (guarantees 9 digits, no leading zero)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION mask_random_number()
RETURNS TEXT AS $$
DECLARE
    -- Generate random number between 100000000 and 999999999
    -- This guarantees exactly 9 digits with no leading zeros
    random_num BIGINT;
BEGIN
    -- floor(random() * (max - min + 1)) + min gives a number in range [min, max]
    -- 100000000 = smallest 9-digit number (no leading zeros)
    -- 999999999 = largest 9-digit number
    random_num := floor(random() * (999999999 - 100000000 + 1) + 100000000)::BIGINT;
    
    -- Cast to TEXT to return as string
    RETURN random_num::TEXT;
END;
$$ LANGUAGE plpgsql VOLATILE;

-- =============================================================================
-- USAGE INSTRUCTIONS
-- =============================================================================
-- 1. Execute this script first to create all masking functions
--    psql -U postgres -d your_database -f create_masking_function.sql
--
-- 2. Verify functions were created:
--    SELECT routine_name FROM information_schema.routines 
--    WHERE routine_schema = 'public' AND routine_name LIKE 'mask_%';
--
-- 3. Test functions before applying to production data:
--    SELECT mask_email('test@example.com');
--    SELECT mask_phone('555-123-4567');
--    SELECT mask_full_name('John Smith');  -- e.g. JohnCarter
--    SELECT mask_random_number();
--
-- 4. Then run mask_pii_data.sql to apply masking to actual tables
--
-- =============================================================================
-- IMPORTANT NOTES
-- =============================================================================
-- - Always backup database before running masking operations
-- - Test on a copy of production data first
-- - These functions can be reused across multiple sanitization operations
-- =============================================================================
