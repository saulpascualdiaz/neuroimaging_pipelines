#!/bin/bash

# ADNI3 DWI Preprocessing Batch Script
# Parallel execution manager for DWI preprocessing pipeline
# Author: Saül Pascual-Diaz
# Date: 2025/07/29

set -e

# =============================================================================
# CONFIGURATION
# =============================================================================
BIDS_DIR="/path/to/BIDS"
SESSION="baseline"
DERIVATIVES_DIR="${BIDS_DIR}/derivatives/dwi_preprocessing"
SCRIPT_DIR="$(dirname "$0")"
JOB_SCRIPT="${SCRIPT_DIR}/ADNI3_dwi_preprocessing_job.sh"
MAX_PARALLEL_JOBS=3  # Adjust based on your system capabilities

echo "==================================================================="
echo "ADNI3 - DWI Preprocessing Batch Manager"
echo "==================================================================="
echo "BIDS Directory: ${BIDS_DIR}"
echo "Session: ${SESSION}"
echo "Derivatives: ${DERIVATIVES_DIR}"
echo "Max parallel jobs: ${MAX_PARALLEL_JOBS}"
echo "Job script: ${JOB_SCRIPT}"
echo "Started: $(date)"
echo "==================================================================="

# =============================================================================
# VALIDATION
# =============================================================================

# Check if job script exists
if [[ ! -f "$JOB_SCRIPT" ]]; then
    echo "ERROR: Job script not found: $JOB_SCRIPT"
    exit 1
fi

# Make job script executable
chmod +x "$JOB_SCRIPT"

# Create derivatives directory
mkdir -p "${DERIVATIVES_DIR}"

# Find all subjects
ALL_SUBJECTS=($(find "${BIDS_DIR}" -maxdepth 1 -name "sub-*" -type d | xargs -n1 basename | sort))

if [[ ${#ALL_SUBJECTS[@]} -eq 0 ]]; then
    echo "ERROR: No subjects found in ${BIDS_DIR}"
    exit 1
fi

echo "Found ${#ALL_SUBJECTS[@]} subject(s): ${ALL_SUBJECTS[*]}"
echo ""

# =============================================================================
# PARALLEL PROCESSING FUNCTIONS
# =============================================================================
    
# Function to wait for available slot
wait_for_slot() {
    while [[ ${#RUNNING_PIDS[@]} -ge $MAX_PARALLEL_JOBS ]]; do
        # Check for completed jobs and remove them
        local new_pids=()
        for pid in "${RUNNING_PIDS[@]}"; do
            if kill -0 "$pid" 2>/dev/null; then
                new_pids+=("$pid")
            fi
        done
        RUNNING_PIDS=("${new_pids[@]}")
        
        if [[ ${#RUNNING_PIDS[@]} -ge $MAX_PARALLEL_JOBS ]]; then
            sleep 1
        fi
    done
}

# =============================================================================
# MAIN PROCESSING LOOP
# =============================================================================

echo "Starting parallel processing with max ${MAX_PARALLEL_JOBS} concurrent jobs..."
echo ""

# Arrays to track processing status
PROCESSED_SUBJECTS=()
FAILED_SUBJECTS=()
RUNNING_PIDS=()

# Start processing subjects
for subject in "${ALL_SUBJECTS[@]}"; do
    # Wait for an available slot
    wait_for_slot
    
    echo "Starting ${subject}..."
    
    # Start processing in background
    (
        log_file="${DERIVATIVES_DIR}/${subject}_batch.log"
        echo "Starting ${subject} at $(date)" > "$log_file"
        
        # Call the job script with parameters
        if "${JOB_SCRIPT}" "${subject}" "${BIDS_DIR}" "${SESSION}" "${DERIVATIVES_DIR}" >> "$log_file" 2>&1; then
            echo "✓ ${subject} completed successfully at $(date)" >> "$log_file"
            echo "✓ ${subject} completed successfully"
            echo "$subject:success" > "/tmp/result_${subject}_$$"
        else
            echo "✗ ${subject} failed at $(date)" >> "$log_file"
            echo "✗ ${subject} failed"
            echo "$subject:failed" > "/tmp/result_${subject}_$$"
        fi
    ) &
    
    # Store the PID
    RUNNING_PIDS+=($!)
    
    # Small delay to prevent overwhelming the system
    sleep 0.5
done

echo ""
echo "All subjects started. Waiting for completion..."
echo ""

# Wait for all background jobs to complete
wait

# Collect results
for subject in "${ALL_SUBJECTS[@]}"; do
    result_file="/tmp/result_${subject}_$$"
    if [[ -f "$result_file" ]]; then
        result=$(cat "$result_file")
        if [[ "$result" == *":success" ]]; then
            PROCESSED_SUBJECTS+=("$subject")
        else
            FAILED_SUBJECTS+=("$subject")
        fi
        rm -f "$result_file"
    else
        FAILED_SUBJECTS+=("$subject")
    fi
done

# =============================================================================
# SUMMARY
# =============================================================================

echo ""
echo "==================================================================="
echo "BATCH PROCESSING SUMMARY"
echo "==================================================================="
echo "Completed: $(date)"
echo "Total subjects: ${#ALL_SUBJECTS[@]}"
echo "Successfully processed: ${#PROCESSED_SUBJECTS[@]}"
echo "Failed: ${#FAILED_SUBJECTS[@]}"
echo ""

if [[ ${#PROCESSED_SUBJECTS[@]} -gt 0 ]]; then
    echo "Successfully processed subjects:"
    printf '  ✓ %s
' "${PROCESSED_SUBJECTS[@]}"
    echo ""
fi

if [[ ${#FAILED_SUBJECTS[@]} -gt 0 ]]; then
    echo "Failed subjects:"
    printf '  ✗ %s
' "${FAILED_SUBJECTS[@]}"
    echo ""
    echo "Check individual log files in ${DERIVATIVES_DIR} for error details."
fi

echo "Results saved to: ${DERIVATIVES_DIR}"
echo "==================================================================="

# Exit with appropriate code
if [[ ${#FAILED_SUBJECTS[@]} -gt 0 ]]; then
    echo "Some subjects failed. Check logs for details."
    exit 1
else
    echo "All subjects processed successfully!"
    exit 0
fi


