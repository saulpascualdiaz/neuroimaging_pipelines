#!/bin/bash
# Author: Saül Pascual-Diaz
# Version: 1.4
# Date: September 9th, 2024
# 
# Description:
# This script generates DTI-derived diffusion maps, including Fractional Anisotropy (FA), Mean Diffusivity (MD), 
# Axial Diffusivity (AD), and Radial Diffusivity (RD) for each subject. The script calculates the brain mask directly 
# from the DWI data using MRtrix3’s 'dwi2mask' tool.
# The script assumes that the DWI data has been preprocessed using the 'dwi_preprocessing_appa_pipeline.sh' script
# from the 'neuroimaging_pipelines' GitHub repository.
#
# The preprocessing pipeline is expected to generate corrected DWI images in BIDS format with 
# filenames ending in '_dir-AP_dwi_corr.nii.gz', along with corresponding '.bval' and '.bvec' files.
#
# Input:
# - DWI preprocessed data directory (assumed to be in BIDS format)
# - Subject and session identifiers derived from the directory structure.
#
# Output:
# - DTI-derived maps (FA, MD, AD, and RD) stored in the DWI_DTI-derived_maps directory.

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
    
    # Check if the expected DWI file exists, skip to the next subject if not
    if file_exists ${in_dwi_file}.nii.gz; then continue; fi
    
    echo "Working on subject ${s}..."
    
    # Define output directory for DTI-derived maps
    od=${bids_derivatives}/DWI_DTI-derived_maps/${s}/ses-${ses}
    
    # Check if the DTI-derived maps already exist, skip processing if found
    if file_exists "${od}/${s}_ses-${ses}_dir-AP_dwi_corr_AD.nii.gz"; then
        echo "DTI-derived maps output found for subject: ${s}"
        continue
    fi

    # Create output directory if it doesn't exist
    if [ ! -d ${od} ]; then mkdir -p ${od}; fi  
    
    # Step 0: Calculate brainmask in case it didn't exist
    if ! file_exists ${in_dwi_file}_mean_brainmask.nii.gz; then
        run_command fslmaths ${in_dwi_file}.nii.gz -Tmean ${in_dwi_file}_mean.nii.gz
        run_command bet2 ${in_dwi_file}_mean.nii.gz ${in_dwi_file}_mean_brain.nii.gz -f 0.45 -g 0.0
        run_command fslmaths ${in_dwi_file}_mean_brain.nii.gz -thr 0 -bin ${in_dwi_file}_mean_brainmask.nii.gz
    fi

    # Step 1: Generate tensor file with brain mask applied
    tensor_file="${od}/${s}_ses-${ses}_dir-AP_dwi_corr_tensor.nii.gz"
    dwi2tensor ${in_dwi_file}.nii.gz -fslgrad ${in_dwi_file}.bvec ${in_dwi_file}.bval -mask ${in_dwi_file}_mean_brainmask.nii.gz - | mrconvert - ${tensor_file}
    
    # Step 2: Generate Fractional Anisotropy (FA) map
    run_command tensor2metric -fa ${od}/${s}_ses-${ses}_dir-AP_dwi_corr_FA.nii.gz -mask ${in_dwi_file}_mean_brainmask.nii.gz ${tensor_file}
    run_command fslmaths ${od}/${s}_ses-${ses}_dir-AP_dwi_corr_FA.nii.gz -nan ${od}/${s}_ses-${ses}_dir-AP_dwi_corr_FA.nii.gz
    
    # Step 3: Generate Mean Diffusivity (MD) map
    run_command tensor2metric -adc ${od}/${s}_ses-${ses}_dir-AP_dwi_corr_MD.nii.gz -mask ${in_dwi_file}_mean_brainmask.nii.gz ${tensor_file}
    run_command fslmaths ${od}/${s}_ses-${ses}_dir-AP_dwi_corr_MD.nii.gz -nan ${od}/${s}_ses-${ses}_dir-AP_dwi_corr_MD.nii.gz

    # Step 4: Generate Radial Diffusivity (RD) map
    run_command tensor2metric -rd ${od}/${s}_ses-${ses}_dir-AP_dwi_corr_RD.nii.gz -mask ${in_dwi_file}_mean_brainmask.nii.gz ${tensor_file}
    run_command fslmaths ${od}/${s}_ses-${ses}_dir-AP_dwi_corr_RD.nii.gz -nan ${od}/${s}_ses-${ses}_dir-AP_dwi_corr_RD.nii.gz
    
    # Step 5: Generate Axial Diffusivity (AD) map
    run_command tensor2metric -ad ${od}/${s}_ses-${ses}_dir-AP_dwi_corr_AD.nii.gz -mask ${in_dwi_file}_mean_brainmask.nii.gz ${tensor_file}
    run_command fslmaths ${od}/${s}_ses-${ses}_dir-AP_dwi_corr_AD.nii.gz -nan ${od}/${s}_ses-${ses}_dir-AP_dwi_corr_AD.nii.gz

    rm ${tensor_file}
done
