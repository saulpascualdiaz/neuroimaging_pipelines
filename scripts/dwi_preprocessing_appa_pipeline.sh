#!/bin/bash
# Author: Saül Pascual-Diaz
# Version: 1.1
# Date: August 5th, 2024

# Description:
# This script processes diffusion-weighted imaging (DWI) data for multiple subjects
# following the Brain Imaging Data Structure (BIDS) format. It checks for the presence
# of necessary input files, performs denoising, and runs the FSL pre-processing pipeline.
# The script utilizes GNU `parallel` to process multiple subjects in parallel, leveraging 
# the processing power of multi-core systems.

# Assumptions:
# - The BIDS directory structure follows the standard format.
# - The script is run in an environment where all necessary tools (dwidenoise, fslroi, 
#   mrcat, dwifslpreproc, mrdegibbs) are available.
# - GNU `parallel` is installed and available in your system's PATH.

# Installation of GNU `parallel`:
# - On macOS, you can install `parallel` using Homebrew. First, install Homebrew 
#   if you don't have it:
#     /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
# - Then, install `parallel` using the following command:
#     brew install parallel
#
# Usage:
# - This script uses `parallel` to run the DWI processing pipeline on multiple subjects 
#   simultaneously. You can configure the number of parallel jobs by setting the `parallel_jobs` 
#   variable below. Ensure that the total number of threads used by all parallel jobs does not exceed 
#   the number of available CPU cores.

# Configuration
bids_dir=/path/to/bids/data
bids_out=/path/to/bids/derivatives/subfolder
parallel_jobs=6  # Set the number of parallel jobs (subjects) to process simultaneously

# Do not modify beyond this point ------------------------------------------------
# ANSI color codes
BLUE='\033[0;34m'
RED='\033[0;31m'
GREEN='\033[0;32m'
ORANGE='\033[0;33m'
NC='\033[0m' # No Color

process_subject() {
    s=$1
    printf "${BLUE}Working in subject ${s}...${NC}\n"

    # Basic variables
    ses="baseline"
    wd="${bids_dir}/${s}/ses-${ses}/dwi/${s}_ses-${ses}_dir"
    od="${bids_out}/${s}/ses-${ses}/${s}_ses-${ses}_dir"
    start_time=$(date +%s)
    
    if [ -f ${od}-AP_dwi_corr.nii.gz ]; then
        printf "${GREEN}Subject ${s} already pre-processed.${NC}\n"
        return
    fi

    # Checking for input files
    missing_files=false
    for f in "${wd}-AP_dwi.bval" "${wd}-AP_dwi.bvec" "${wd}-AP_dwi.nii.gz" "${wd}-PA_dwi.nii.gz"; do
        if [ ! -f "${f}" ]; then
            printf "${RED}[WARNING] Skipping subject ${s}. Missing input file: ${f}${NC}\n"
            missing_files=true
        fi
    done
    
    if [ "$missing_files" = true ]; then
        return
    fi
    
    if [ ! -d ${bids_out}/${s}/ses-${ses} ]; then
        mkdir -p ${bids_out}/${s}/ses-${ses}
    fi
    
    # DWI denoising
    if [ ! -f ${od}-AP_dwi_denoised.nii.gz ]; then
        dwidenoise ${wd}-AP_dwi.nii.gz ${od}-AP_dwi_denoised.nii.gz
        if [ $? -eq 0 ]; then
            printf "${GREEN}Denoising completed for subject ${s}${NC}\n"
        else
            printf "${RED}[ERROR] Denoising failed for subject ${s}${NC}\n"
            return
        fi
    else
        printf "${ORANGE}Denoised file already exists for subject ${s}, skipping denoising${NC}\n"
    fi
    
    # Step 2: Remove Gibbs ringing
    if [ ! -f ${od}-AP_dwi_unringed.nii.gz ]; then
        mrdegibbs ${od}-AP_dwi_denoised.nii.gz  ${od}-AP_dwi_unringed.nii.gz
        if [ $? -eq 0 ]; then
            printf "${GREEN}Gibbs ringing removal completed for subject ${s}${NC}\n"
        else
            printf "${RED}[ERROR] Gibbs ringing removal failed for subject ${s}${NC}\n"
        fi
    else
        printf "${ORANGE}Gibbs ringing file already exists for subject ${s}, skipping Gibbs ringing removal${NC}\n"
    fi

    # FSL DWI pre-processing
    if [ ! -f ${od}-AP_dwi_corr.nii.gz ]; then
        fslroi ${wd}-AP_dwi.nii.gz ${od}-AP_dwi_b0.nii.gz 0 1
        fslroi ${wd}-PA_dwi.nii.gz ${od}-PA_dwi_b0.nii.gz 0 1
        mrcat ${od}-AP_dwi_b0.nii.gz ${od}-PA_dwi_b0.nii.gz ${od}-b0_pair.mif -axis 3
        dwifslpreproc ${od}-AP_dwi_unringed.nii.gz \
            ${od}-AP_dwi_corr.nii.gz -fslgrad ${wd}-AP_dwi.bvec ${wd}-AP_dwi.bval \
            -export_grad_fsl ${od}-AP_dwi_corr.bvec ${od}-AP_dwi_corr.bval \
            -rpe_pair -se_epi ${od}-b0_pair.mif  -eddy_options " --slm=linear "\
            -pe_dir ap -align_seepi
        if [ $? -eq 0 ]; then
            printf "${GREEN}FSL pre-processing completed for subject ${s}${NC}\n"
        else
            printf "${RED}[ERROR] FSL pre-processing failed for subject ${s}${NC}\n"
        fi
    fi

    # Cleanning files
    for f in "${od}-AP_dwi_b0.nii.gz" "${od}-AP_dwi_denoised.nii.gz" \
        "${od}-b0_pair.mif" "${od}-PA_dwi_b0.nii.gz" "${od}-AP_dwi_unringed.nii.gz"; do
        if [ -f ${f} ]; then
            rm ${f}
        fi
    done

    end_time=$(date +%s)
    duration=$((end_time - start_time))
    if [ $duration -ge 3600 ]; then
        echo -e "${BLUE}Subject ${s} processing time: $(($duration / 3600)) hours, $((($duration % 3600) / 60)) minutes, and $(($duration % 60)) seconds.${NC}\n"
    elif [ $duration -ge 60 ]; then
        echo -e "${BLUE}Subject ${s} processing time: $(($duration / 60)) minutes and $(($duration % 60)) seconds.${NC}\n"
    else
        echo -e "${BLUE}Subject ${s} processing time: $duration seconds.${NC}\n"
    fi
}

export bids_dir bids_out BLUE RED GREEN ORANGE NC
export -f process_subject

# Execute the processing function in parallel for each subject in the bids_dir
# The parallel_jobs variable controls the number of parallel jobs (subjects) to process simultaneously.
ls ${bids_dir} | parallel -j ${parallel_jobs} process_subject {}
