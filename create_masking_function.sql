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
-- Function: mask_first_name
-- -----------------------------------------------------------------------------
-- Purpose: Anonymizes first names while maintaining uniqueness
-- Input: firstname TEXT - Original first name
-- Output: TEXT - Masked name in format: User_<8_char_hash>
-- Example: John -> User_5d41402a
-- Properties: IMMUTABLE - Consistent hashing preserves data relationships
-- Use Case: When you need to join tables by name but hide real identities
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION mask_first_name(firstname TEXT)
RETURNS TEXT AS $$
BEGIN
    -- Handle NULL values
    IF firstname IS NULL THEN
        RETURN NULL;
    END IF;
    
    -- Generate consistent masked name using first 8 chars of MD5 hash
    -- substr() extracts substring: substr(string, start_position, length)
    -- This creates short, readable but anonymized names
    RETURN 'User_' || substr(md5(firstname), 1, 8);
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- -----------------------------------------------------------------------------
-- Function: mask_middle_name
-- -----------------------------------------------------------------------------
-- Purpose: Anonymizes middle names while maintaining uniqueness
-- Input: middlename TEXT - Original middle name
-- Output: TEXT - Masked name in format: User_<8_char_hash>
-- Example: Robert -> User_b0baee9d
-- Properties: IMMUTABLE - Consistent hashing for referential integrity
-- Note: Separate function from first_name for clarity and potential future
--       different masking strategies
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION mask_middle_name(middlename TEXT)
RETURNS TEXT AS $$
BEGIN
    -- Handle NULL values (many records may not have middle names)
    IF middlename IS NULL THEN
        RETURN NULL;
    END IF;
    
    -- Same masking strategy as first name for consistency
    RETURN 'User_' || substr(md5(middlename), 1, 8);
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- -----------------------------------------------------------------------------
-- Function: mask_last_name
-- -----------------------------------------------------------------------------
-- Purpose: Anonymizes last names/surnames while maintaining uniqueness
-- Input: lastname TEXT - Original last name
-- Output: TEXT - Masked name in format: User_<8_char_hash>
-- Example: Smith -> User_c6f057b8
-- Properties: IMMUTABLE - Deterministic output preserves relationships
-- Use Case: Family relationships or surname-based queries remain valid
--           while protecting identity
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION mask_last_name(lastname TEXT)
RETURNS TEXT AS $$
BEGIN
    -- Handle NULL values
    IF lastname IS NULL THEN
        RETURN NULL;
    END IF;
    
    -- Consistent hashing ensures family members with same last name
    -- get the same masked surname
    RETURN 'User_' || substr(md5(lastname), 1, 8);
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
--    SELECT mask_first_name('John');
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
