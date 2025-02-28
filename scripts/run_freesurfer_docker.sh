#!/bin/bash

# Set the paths
BIDS_DIR="/home/user/data/project/bids_data"
DERIVATIVES_DIR="$BIDS_DIR/derivatives/freesurfer"
LICENSE_FILE="$BIDS_DIR/code/fs_license.txt"

# Check if paths exist
if [[ ! -d "$BIDS_DIR" ]]; then
    echo "❌ Error: BIDS directory does not exist: $BIDS_DIR"
    exit 1
fi

if [[ ! -d "$DERIVATIVES_DIR" ]]; then
    echo "⚠️ Warning: Creating missing derivatives directory: $DERIVATIVES_DIR"
    mkdir -p "$DERIVATIVES_DIR"
fi

if [[ ! -f "$LICENSE_FILE" ]]; then
    echo "❌ Error: FreeSurfer license file is missing: $LICENSE_FILE"
    exit 1
fi

# Remove empty JSON files (fix BIDS validation errors)
echo "🛠️ Checking and removing empty JSON files..."
find "$BIDS_DIR" -type f -name "*.json" -size 0 -delete

# Extract subject IDs (remove empty lines)
SUBJECTS=$(awk 'NR>1 {print $1}' "$BIDS_DIR/participants.tsv" | sed '/^$/d')

if [[ -z "$SUBJECTS" ]]; then
    echo "❌ Error: No valid subjects found in participants.tsv!"
    exit 1
fi

# Function to run FreeSurfer 7.2.0 for a single subject
run_freesurfer() {
    local subject=$1
    if [[ -z "$subject" ]]; then
        echo "⚠️ Warning: Encountered an empty subject. Skipping."
        return
    fi

    # Verify that the input file exists on the **host system**
    HOST_T1_FILE="$BIDS_DIR/${subject}/anat/${subject}_run-01_T1w.nii.gz"
    if [[ ! -f "$HOST_T1_FILE" ]]; then
        echo "❌ Error: Missing input file on host: $HOST_T1_FILE"
        return
    fi

    echo "🚀 Processing $subject with FreeSurfer 7.2.0..."

    docker run --rm \
        -v "${BIDS_DIR}:/bids_data" \
        -v "${DERIVATIVES_DIR}:/output" \
        -v "${LICENSE_FILE}:/usr/local/freesurfer/.license" \
        -e SUBJECTS_DIR=/output \
        -e OMP_NUM_THREADS=8 \
        freesurfer/freesurfer:7.2.0 \
        recon-all -i "/bids_data/${subject}/anat/${subject}_run-01_T1w.nii.gz" \
                -subjid "$subject" \
                -all

    echo "✅ Finished processing $subject"
}

export BIDS_DIR DERIVATIVES_DIR LICENSE_FILE
export -f run_freesurfer  # Export function for parallel

# Print subjects for debugging
echo "📋 Subjects being processed:"
echo "$SUBJECTS"

# Run FreeSurfer in parallel (4 jobs at a time)
echo "$SUBJECTS" | parallel --env BIDS_DIR --env DERIVATIVES_DIR --env LICENSE_FILE -j 4 run_freesurfer
echo "🎉 All subjects processed!"
