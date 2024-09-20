#!/bin/bash
# Author: Saül Pascual-Diaz
# Version: 1
# Date: September 9th, 2024
# 
# Description:
# This script processes DWI data using TractSeg to perform tract segmentation and endings segmentation.
# The script assumes that the DWI data has been preprocessed using the 'dwi_preprocessing_appa_pipeline.sh' script
# from the 'neuroimaging_pipelines' GitHub repository.
#
# The preprocessing pipeline is expected to generate corrected DWI images in BIDS format with 
# filenames ending in '_dir-AP_dwi_corr.nii.gz', along with corresponding '.bval' and '.bvec' files.
#
# Input:
# - DWI preprocessed data directory (assumed to be in BIDS format)
# - Subject and session identifiers derived from directory structure
#
# Output:
# - Tract segmentation and endings segmentation stored in the DWI_tractseg directory

# Paths
bids_derivatives="/Volumes/working_disk_blue/SPRINT_MPS/bids_derivatives"
dwi_preprocessed="${bids_derivatives}/DWI_postprocessed"
git_dir="/Users/spascual/git/saulpascualdiaz/neuroimaging_pipelines"
source ${git_dir}/dependences/functions/common_bash_functions.sh

# Loop through each subject in the preprocessed DWI directory
for s in $(ls ${dwi_preprocessed}); do
    ses="baseline"  # Define session identifier (default: baseline)
    
    # Define input file paths based on the subject and session
    in_dwi_file=${dwi_preprocessed}/${s}/ses-${ses}/${s}_ses-${ses}_dir-AP_dwi_corr
    
    # Check if the expected DWI file exists, skip to next subject if not
    if ! file_exists -f ${in_dwi_file}.nii.gz; then continue; fi
    
    echo "Working on subject ${s}..."
    
    # Define output directory for TractSeg results
    od=${bids_derivatives}/DWI_tractseg/${s}/ses-${ses}
    
    if [ -d "${od}/bundle_segmentations" ]; then
        echo "TractSeg output found for subject: ${s}"
        continue
    fi

    if [ ! -d ${od} ]; then mkdir -p ${od}; fi  # Create output directory if it doesn't exist

    # Step 0: Calculate brainmask in case it didn't exist
    if ! file_exists ${in_dwi_file}_mean_brainmask.nii.gz; then
        run_command fslmaths ${in_dwi_file}.nii.gz -Tmean ${in_dwi_file}_mean.nii.gz
        run_command bet2 ${in_dwi_file}_mean.nii.gz ${in_dwi_file}_mean_brain.nii.gz -f 0.45 -g 0.0
        run_command fslmaths ${in_dwi_file}_mean_brain.nii.gz -thr 0 -bin ${in_dwi_file}_mean_brainmask.nii.gz
    fi

    # Step 1: Tract segmentation using TractSeg
    TractSeg -i ${in_dwi_file}.nii.gz --bvals ${in_dwi_file}.bval --bvecs ${in_dwi_file}.bvec --output_type tract_segmentation -o ${od} --raw_diffusion_input --brain_mask ${in_dwi_file}_mean_brainmask.nii.gz
    
    # Step 2: Endings segmentation using TractSeg
    TractSeg -i ${od}/peaks.nii.gz --bvals ${in_dwi_file}.bval --bvecs ${in_dwi_file}.bvec --output_type endings_segmentation -o ${od} --brain_mask ${in_dwi_file}_mean_brainmask.nii.gz

done
