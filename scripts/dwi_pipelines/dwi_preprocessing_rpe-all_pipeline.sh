#!/bin/bash
# Author: Saül Pascual-Diaz
# Version: 1.0
# Date: January 22th, 2026

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

# Example of structure:
# /Users/s_name/project_name/bids/sub-9999/dwi/sub-9999_acq-ap_dwi.bval
# /Users/s_name/project_name/bids/sub-9999/dwi/sub-9999_acq-ap_dwi.bvec
# /Users/s_name/project_name/bids/sub-9999/dwi/sub-9999_acq-ap_dwi.nii.gz
# /Users/s_name/project_name/bids/sub-9999/dwi/sub-9999_acq-pa_dwi.bval
# /Users/s_name/project_name/bids/sub-9999/dwi/sub-9999_acq-pa_dwi.bvec
# /Users/s_name/project_name/bids/sub-9999/dwi/sub-9999_acq-pa_dwi.json
# /Users/s_name/project_name/bids/sub-9999/dwi/sub-9999_acq-pa_dwi.nii.gz

# /Users/s_name/project_name/bids/sub-9999/dwi/sub-9998_acq-ap_dwi.bval
# /Users/s_name/project_name/bids/sub-9999/dwi/sub-9998_acq-ap_dwi.bvec
# /Users/s_name/project_name/bids/sub-9999/dwi/sub-9998_acq-ap_dwi.nii.gz
# /Users/s_name/project_name/bids/sub-9999/dwi/sub-9998_acq-pa_dwi.bval
# /Users/s_name/project_name/bids/sub-9999/dwi/sub-9998_acq-pa_dwi.bvec
# /Users/s_name/project_name/bids/sub-9999/dwi/sub-9998_acq-pa_dwi.json
# /Users/s_name/project_name/bids/sub-9999/dwi/sub-9998_acq-pa_dwi.nii.gz

# Installation of GNU `parallel`:
# - On macOS, you can install `parallel` using Homebrew. First, install Homebrew 
#   if you don't have it:
#     /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
# - Then, install `parallel` using the following command:
#     brew install parallel

# Usage:
# - This script uses `parallel` to run the DWI processing pipeline on multiple subjects 
#   simultaneously. You can configure the number of parallel jobs by setting the `parallel_jobs` 
#   variable below. Ensure that the total number of threads used by all parallel jobs does not exceed 
#   the number of available CPU cores.

# Configuration
bids_dir=/Users/s_name/project_name/bids
bids_out=/Users/s_name/project_name/bids/derivatives
parallel_jobs=6  # Set the number of parallel jobs (subjects) to process simultaneously
source /Users/spascual/Downloads/Sehwan_dwi/code/common_bash_functions.sh

process_subject() {
    s=$1
    printf "${BLUE}Working in subject ${s}...${NC}\n"

    # Basic variables
    wd="${bids_dir}/${s}/dwi/${s}_acq"
    od="${bids_out}/${s}/${s}_acq"
    start_time=$(date +%s)
    
    if [ -f ${od}-ap_dwi_corr.nii.gz ]; then
        printf "${GREEN}Subject ${s} already pre-processed.${NC}\n"
        return
    fi

    # Checking for input files
    missing_files=false
    for f in "${wd}-ap_dwi.bval" "${wd}-ap_dwi.bvec" "${wd}-ap_dwi.nii.gz" "${wd}-pa_dwi.bval" "${wd}-pa_dwi.bvec" "${wd}-pa_dwi.nii.gz"; do
        if ! file_exists "${f}"; then
            printf "${RED}[WARNING] Skipping subject ${s}. Missing input file: ${f}${NC}\n"
            missing_files=true
        fi
    done
    
    if [ "$missing_files" = true ]; then
        return
    fi
    
    if [ ! -d ${bids_out}/${s} ]; then
        mkdir -p ${bids_out}/${s}
    fi
    
    # DWI denoising and Gibbs ringing removal
    for dir in "ap" "pa"; do
        if ! file_exists ${od}-${dir}_dwi.mif; then
            mrconvert ${wd}-${dir}_dwi.nii.gz ${od}-${dir}_dwi.mif -json_import ${wd}-${dir}_dwi.json -fslgrad ${wd}-${dir}_dwi.bvec ${wd}-${dir}_dwi.bval
        fi
        if ! file_exists ${od}-${dir}_dwi_denoised.mif; then
            dwidenoise ${od}-${dir}_dwi.mif ${od}-${dir}_dwi.mif
        fi
        if ! file_exists ${od}-${dir}_dwi_unringed.mif; then
            mrdegibbs ${od}-${dir}_dwi_denoised.mif  ${od}-${dir}_dwi_unringed.mif
        fi
    done

    if ! file_exists ${od}-ap_dwi_corr.nii.gz; then
        echo "Running Mr. Cat ฅ^•ﻌ•^ฅ"
        mrcat ${od}-ap_dwi_unringed.mif ${od}-pa_dwi_unringed.mif ${od}-all_dwi_unringed.mif -axis 3
        dwifslpreproc ${od}-all_dwi_unringed.mif ${od}-ap_dwi_corr.nii.gz -rpe_all -pe_dir ap -export_grad_fsl ${od}-ap_dwi_corr.bvec ${od}-ap_dwi_corr.bval -eddy_options " --slm=linear "
    fi

    # Cleanning files
    for dir in "ap" "pa"; do
        for f in "${od}-${dir}_dwi.mif"  "${od}-${dir}_dwi.mif" "${od}-${dir}_dwi_unringed.mif" "${od}-all_dwi_unringed.mif"; do
            if file_exists ${f}; then
                rm ${f}
            fi
        done
    done
}

export -f file_exists
export -f process_subject
export bids_dir bids_out BLUE RED GREEN ORANGE NC
ls ${bids_dir} | parallel -j ${parallel_jobs} process_subject {}
