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

# Loop through each subject in the preprocessed DWI directory
for s in $(ls ${dwi_preprocessed}); do
    ses="baseline"  # Define session identifier (default: baseline)
    
    # Define input file paths based on the subject and session
    in_dwi_file=${dwi_preprocessed}/${s}/ses-${ses}/${s}_ses-${ses}_dir-AP_dwi_corr
    
    # Check if the expected DWI file exists, skip to the next subject if not
    if [ ! -f ${in_dwi_file}.nii.gz ]; then continue; fi
    
    echo "Working on subject ${s}..."
    
    # Define output directory for DTI-derived maps
    od=${bids_derivatives}/DWI_DTI-derived_maps/${s}/ses-${ses}
    
    # Check if the DTI-derived maps already exist, skip processing if found
    if [ -f "${od}/${s}_ses-${ses}_dir-AP_dwi_corr_AD.nii.gz" ]; then
        echo "DTI-derived maps output found for subject: ${s}"
        continue
    fi

    # Create output directory if it doesn't exist
    if [ ! -d ${od} ]; then mkdir -p ${od}; fi  
    
    # Step 1: Calculate brain mask from DWI data using the gradient table
    brain_mask_file="${od}/${s}_ses-${ses}_brainmask.nii.gz"
    dwi2mask ${in_dwi_file}.nii.gz -fslgrad ${in_dwi_file}.bvec ${in_dwi_file}.bval - | mrconvert - ${brain_mask_file}
    
    # Step 2: Generate tensor file with brain mask applied
    tensor_file="${od}/${s}_ses-${ses}_dir-AP_dwi_corr_tensor.nii.gz"
    dwi2tensor ${in_dwi_file}.nii.gz -fslgrad ${in_dwi_file}.bvec ${in_dwi_file}.bval -mask ${brain_mask_file} - | mrconvert - ${tensor_file}
    
    # Step 3: Generate Fractional Anisotropy (FA) map
    tensor2metric -fa ${od}/${s}_ses-${ses}_dir-AP_dwi_corr_FA.nii.gz -mask ${brain_mask_file} ${tensor_file}
    
    # Step 4: Generate Mean Diffusivity (MD) map
    tensor2metric -adc ${od}/${s}_ses-${ses}_dir-AP_dwi_corr_MD.nii.gz -mask ${brain_mask_file} ${tensor_file}
    
    # Step 5: Generate Radial Diffusivity (RD) map
    tensor2metric -rd ${od}/${s}_ses-${ses}_dir-AP_dwi_corr_RD.nii.gz -mask ${brain_mask_file} ${tensor_file}
    
    # Step 6: Generate Axial Diffusivity (AD) map
    tensor2metric -ad ${od}/${s}_ses-${ses}_dir-AP_dwi_corr_AD.nii.gz -mask ${brain_mask_file} ${tensor_file}
done
