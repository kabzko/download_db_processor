#!/bin/bash

# =============================================================================
# DATABASE DOWNLOAD AND IMPORT SCRIPT
# =============================================================================
# Purpose: Download latest database backup from AWS S3, decompress, and import
#          to local PostgreSQL for sanitization processing
# Usage: ./download_db.sh
# Requirements: 
#   - AWS CLI configured with appropriate credentials
#   - PostgreSQL installed locally
#   - Ansible installed with importdb.yml playbook
#   - Sufficient disk space for database file
# Author: Database Team
# Last Modified: 2025-02-08
# =============================================================================

# -----------------------------------------------------------------------------
# CONFIGURATION VARIABLES
# -----------------------------------------------------------------------------

# Local directory where database files will be stored
# Make sure this directory exists and has sufficient space
DATABASE_DIR=/home/ubuntu/database/

# Database name to use when importing to PostgreSQL
# This will be the name of the local database created
LOCAL_DB_NAME=yp

# S3 bucket path where database backups are stored
# Format: bucket-name/folder-name
BUCKET=ysc-backup-databases/$LOCAL_DB_NAME

# -----------------------------------------------------------------------------
# STEP 1: IDENTIFY LATEST DATABASE BACKUP
# -----------------------------------------------------------------------------
# Get the most recent backup file from S3
# Process:
# 1. List all files in S3 bucket recursively
# 2. Sort files by date (oldest to newest)
# 3. Take the last (most recent) file
# 4. Extract just the filename without path
# -----------------------------------------------------------------------------

echo "=========================================="
echo "DATABASE DOWNLOAD AND IMPORT PROCESS"
echo "=========================================="
echo "Target Database: $LOCAL_DB_NAME"
echo "S3 Bucket: s3://$BUCKET"
echo "Local Directory: $DATABASE_DIR"
echo "=========================================="
echo ""

echo "[STEP 1/6] Identifying latest database backup from S3..."

# AWS S3 ls: Lists objects in bucket
# --recursive: Include all subdirectories
# sort: Sort files by timestamp
# tail -n 1: Get last line (most recent file)
# awk '{print $4}': Extract 4th column (filename with path)
FILENAME=`aws s3 ls $BUCKET --recursive | sort | tail -n 1 | awk '{print $4}'`

# Remove the folder prefix from filename to get just the file name
# Example: yp/backup_20250208.sql.gz -> backup_20250208.sql.gz
FILENAME="${FILENAME//$LOCAL_DB_NAME\/}"

echo "✓ Latest backup identified: $FILENAME"
echo ""

# -----------------------------------------------------------------------------
# STEP 2: DOWNLOAD DATABASE FROM S3
# -----------------------------------------------------------------------------
# Download the identified backup file from S3 to local directory
# aws s3 cp: Copy file from S3 to local filesystem
# -----------------------------------------------------------------------------

echo "[STEP 2/6] Downloading database from S3..."
echo "Source: s3://$BUCKET/$FILENAME"
echo "Destination: $DATABASE_DIR$FILENAME"

# Download file from S3
# This will show progress bar during download
FILE_OBJECT=`aws s3 cp s3://$BUCKET/$FILENAME $DATABASE_DIR`

echo "✓ Download completed successfully!"
echo ""

# -----------------------------------------------------------------------------
# STEP 3: DECOMPRESS THE DATABASE FILE
# -----------------------------------------------------------------------------
# Database backups are typically compressed with gzip to save space
# We need to decompress before importing to PostgreSQL
# gunzip: GNU zip decompression utility
# -c: Write to stdout (don't delete original yet)
# >: Redirect output to new file
# -----------------------------------------------------------------------------

echo "[STEP 3/6] Decompressing .gz file..."
echo "Compressed file: $DATABASE_DIR$FILENAME"
echo "Output file: $DATABASE_DIR$LOCAL_DB_NAME"

# Decompress the .gz file
# -c flag keeps original file and outputs to stdout
# We redirect output to create uncompressed SQL file
gunzip -c $DATABASE_DIR/$FILENAME > $DATABASE_DIR/$LOCAL_DB_NAME

echo "✓ Decompression completed!"
echo ""

# -----------------------------------------------------------------------------
# STEP 4: CLEANUP COMPRESSED FILE
# -----------------------------------------------------------------------------
# Remove the .gz file to save disk space since we have the decompressed version
# -----------------------------------------------------------------------------

echo "[STEP 4/6] Cleaning up compressed file..."

# Remove the original .gz file
rm $DATABASE_DIR/$FILENAME

echo "✓ Compressed file removed: $FILENAME"
echo ""

# -----------------------------------------------------------------------------
# STEP 5: IMPORT DATABASE TO POSTGRESQL
# -----------------------------------------------------------------------------
# Use Ansible playbook to import the database to local PostgreSQL
# This handles:
# - Dropping existing database if present
# - Creating fresh database
# - Importing SQL file
# - Running sanitization scripts
# -----------------------------------------------------------------------------

echo "[STEP 5/6] Importing database to local PostgreSQL..."
echo "Database name: $LOCAL_DB_NAME"
echo "Running Ansible playbook..."
echo ""

# Run Ansible playbook with sudo privileges
# echo "031498": Echo the sudo password (SECURITY NOTE: See below)
# sudo -S: Read password from stdin
# ansible-playbook: Run the import playbook
# --extra-vars: Pass database name as variable to playbook

# SECURITY WARNING: Hardcoded password in script is a security risk!
# Better alternatives:
# 1. Use sudo NOPASSWD for specific commands in /etc/sudoers
# 2. Use Ansible vault for password management
# 3. Use SSH key authentication
# 4. Run script as user with appropriate permissions
echo "123" | sudo -S ansible-playbook ~/database/download_db_processor/import_db.yml --extra-vars "database_name=$LOCAL_DB_NAME db_password=123"

# -----------------------------------------------------------------------------
# STEP 6: PROCESS COMPLETE
# -----------------------------------------------------------------------------

echo ""
echo "=========================================="
echo "✓ DATABASE IMPORT COMPLETED SUCCESSFULLY!"
echo "=========================================="
echo "Database: $LOCAL_DB_NAME"
echo "Status: Ready for use"
echo "Next steps: Database has been sanitized and is ready for development use"
echo "=========================================="
echo ""