#!/bin/bash

# Set the paths
BIDS_DIR="/your/bids/dir"
DERIVATIVES_DIR="$BIDS_DIR/derivatives/freesurfer"
FMRIPREP_OUT_DIR="$BIDS_DIR/derivatives/fmriprep"
LICENSE_FILE="$BIDS_DIR/code/fs_license_saul.txt"

# Check if paths exist
if [[ ! -d "$BIDS_DIR" ]]; then
    echo "❌ Error: BIDS directory does not exist: $BIDS_DIR"
    exit 1
fi

if [[ ! -d "$DERIVATIVES_DIR" ]]; then
    echo "⚠️ Warning: Creating missing FreeSurfer derivatives directory: $DERIVATIVES_DIR"
    mkdir -p "$DERIVATIVES_DIR"
fi

if [[ ! -d "$FMRIPREP_OUT_DIR" ]]; then
    echo "⚠️ Warning: Creating missing fMRIPrep derivatives directory: $FMRIPREP_OUT_DIR"
    mkdir -p "$FMRIPREP_OUT_DIR"
fi

if [[ ! -f "$LICENSE_FILE" ]]; then
    echo "❌ Error: FreeSurfer license file is missing: $LICENSE_FILE"
    exit 1
fi

# # Remove empty JSON files (to avoid BIDS validation issues)
# echo "🛠️ Removing empty JSON files..."
# find "$BIDS_DIR" -type f -name "*.json" -size 0 -delete

# Extract subject IDs from the participants.tsv file (skipping header and empty lines)
SUBJECTS=$(awk 'NR>1 {print $1}' "$BIDS_DIR/participants.tsv" | sed '/^$/d')

if [[ -z "$SUBJECTS" ]]; then
    echo "❌ Error: No valid subjects found in participants.tsv!"
    exit 1
fi

# Function to run fMRIPrep for a single subject
run_fmriprep() {
    local subject=$1
    if [[ -z "$subject" ]]; then
        echo "⚠️ Warning: Encountered an empty subject. Skipping."
        return
    fi

    echo "🚀 Processing subject $subject with fMRIPrep..."
    
    docker run --rm \
      -v "${BIDS_DIR}:/data:ro" \
      -v "${DERIVATIVES_DIR}:/freesurfer" \
      -v "${FMRIPREP_OUT_DIR}:/out" \
      -v "${LICENSE_FILE}:/data/code/fs_license_saul.txt:ro" \
      nipreps/fmriprep:latest \
      /data /out participant \
      --participant-label "$subject" \
      --skip_bids_validation \
      --ignore slicetiming \
      --fs-license-file /data/code/fs_license_saul.txt \
      --fs-subjects-dir /freesurfer \
      --fs-no-reconall \
      --output-spaces MNI152NLin2009cAsym:res-2

    echo "✅ Finished processing subject $subject"
}

export BIDS_DIR DERIVATIVES_DIR FMRIPREP_OUT_DIR LICENSE_FILE
export -f run_fmriprep  # Export the function for GNU Parallel

# Print subjects for debugging
echo "📋 Subjects being processed:"
echo "$SUBJECTS"

# Run fMRIPrep in parallel (for example, 4 jobs at a time)
echo "$SUBJECTS" | parallel -j 5 run_fmriprep

echo "🎉 All subjects processed!"
