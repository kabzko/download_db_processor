#!/bin/bash

# export_db.sh - Advanced export script with multiple options
# Usage: ./export_db.sh <database_name> <output_folder> [options]

set -e
set -u

# Default values
DB_HOST=${DB_HOST:-localhost}
DB_PORT=${DB_PORT:-5432}
DB_USER=${DB_USER:-postgres}
DB_PASSWORD=${DB_PASSWORD:-}       # PostgreSQL password (set via env: export DB_PASSWORD=yourpassword)
COMPRESSION=${COMPRESSION:-gzip}  # gzip, bzip2, or none
KEEP_SQL=${KEEP_SQL:-false}        # Keep uncompressed SQL file
FORMAT=${FORMAT:-plain}            # plain or custom

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_debug() { echo -e "${BLUE}[DEBUG]${NC} $1"; }

# Check arguments
if [ $# -lt 2 ]; then
    log_error "Usage: $0 <database_name> <output_folder> [compression: gzip|bzip2|none]"
    exit 1
fi

DB_NAME=$1
OUTPUT_FOLDER=$2
COMPRESSION=${3:-gzip}
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Set file extensions based on format
if [ "$FORMAT" = "custom" ]; then
    BASE_FILE="${OUTPUT_FOLDER}${DB_NAME}_sanitized_${TIMESTAMP}.dump"
    DUMP_FORMAT="-Fc"  # Custom format
else
    BASE_FILE="${OUTPUT_FOLDER}${DB_NAME}_sanitized_${TIMESTAMP}.sql"
    DUMP_FORMAT="-Fp"  # Plain SQL
fi

# Create output folder
mkdir -p "$OUTPUT_FOLDER"

log_info "=========================================="
log_info "PostgreSQL Database Export Tool"
log_info "=========================================="
log_info "Database: $DB_NAME"
log_info "Host: $DB_HOST:$DB_PORT"
log_info "User: $DB_USER"
log_info "Output: $OUTPUT_FOLDER"
log_info "Format: $FORMAT"
log_info "Compression: $COMPRESSION"
log_info "=========================================="

# Export database
log_info "Exporting database..."
START_TIME=$(date +%s)

if [ "$FORMAT" = "custom" ]; then
    # Custom format (already compressed)
    PGPASSWORD="$DB_PASSWORD" pg_dump -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" \
            -d "$DB_NAME" -Fc -f "$BASE_FILE"
    FINAL_FILE="$BASE_FILE"
else
    # Plain SQL format
    PGPASSWORD="$DB_PASSWORD" pg_dump -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" \
            -d "$DB_NAME" -Fp -f "$BASE_FILE"
    
    # Compress if requested
    case $COMPRESSION in
        gzip)
            log_info "Compressing with gzip..."
            gzip -f "$BASE_FILE"
            FINAL_FILE="${BASE_FILE}.gz"
            ;;
        bzip2)
            log_info "Compressing with bzip2..."
            bzip2 -f "$BASE_FILE"
            FINAL_FILE="${BASE_FILE}.bz2"
            ;;
        none)
            log_info "No compression applied"
            FINAL_FILE="$BASE_FILE"
            ;;
        *)
            log_warning "Unknown compression: $COMPRESSION, using gzip"
            gzip -f "$BASE_FILE"
            FINAL_FILE="${BASE_FILE}.gz"
            ;;
    esac
fi

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

# Verify file
if [ ! -s "$FINAL_FILE" ]; then
    log_error "Export file is empty or doesn't exist!"
    exit 1
fi

# Get file size
FILE_SIZE=$(du -h "$FINAL_FILE" | cut -f1)

# Generate checksums
log_info "Generating checksums..."
if command -v sha256sum &> /dev/null; then
    SHA256=$(sha256sum "$FINAL_FILE" | cut -d' ' -f1)
    echo "$SHA256  $(basename $FINAL_FILE)" > "${FINAL_FILE}.sha256"
    log_info "SHA256: $SHA256"
fi

if command -v md5sum &> /dev/null; then
    MD5=$(md5sum "$FINAL_FILE" | cut -d' ' -f1)
    echo "$MD5  $(basename $FINAL_FILE)" > "${FINAL_FILE}.md5"
elif command -v md5 &> /dev/null; then
    MD5=$(md5 -q "$FINAL_FILE")
    echo "$MD5  $(basename $FINAL_FILE)" > "${FINAL_FILE}.md5"
fi

# Create metadata file
METADATA_FILE="${FINAL_FILE}.info"
cat > "$METADATA_FILE" << EOF
Database Export Metadata
========================
Database Name: $DB_NAME
Export Date: $(date)
Export Duration: ${DURATION} seconds
File Size: $FILE_SIZE
Compression: $COMPRESSION
Format: $FORMAT
Host: $DB_HOST:$DB_PORT
Exported By: $USER
Hostname: $(hostname)
PostgreSQL Version: $(PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -t -c "SELECT version();" | head -1)
EOF

# Final summary
echo ""
log_info "=========================================="
log_info "Export Completed Successfully!"
log_info "=========================================="
log_info "Output file: $FINAL_FILE"
log_info "File size: $FILE_SIZE"
log_info "Duration: ${DURATION} seconds"
log_info "Checksum files:"
[ -f "${FINAL_FILE}.md5" ] && log_info "  - ${FINAL_FILE}.md5"
[ -f "${FINAL_FILE}.sha256" ] && log_info "  - ${FINAL_FILE}.sha256"
log_info "Metadata: $METADATA_FILE"
log_info "=========================================="
echo ""

exit 0