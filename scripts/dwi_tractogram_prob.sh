#!/bin/bash
# Author: Saül Pascual-Diaz
# Version: 1
# Date: September 9th, 2024
#
# Description:
# This script performs tractography and generates a structural connectome based on stream count and FA-weighted values.
# It assumes that the DWI data has been preprocessed using the 'dwi_preprocessing_appa_pipeline.sh' script
# from the 'neuroimaging_pipelines' GitHub repository.
#
# The script generates the following outputs for each subject:
# 1. Brain mask for diffusion data.
# 2. Response function for constrained spherical deconvolution (CSD).
# 3. Fiber orientation distributions (FODs).
# 4. Tractogram (5 million streamlines).
# 5. SIFTed tractogram (1 million streamlines).
# 6. Atlas labels in diffusion space (Brainnetome Atlas).
# 7. Structural connectome using stream count.
# 8. FA-weighted structural connectome.
#
# Note:
# Before running this script, you must have already run the 'dwi_DTI-derived_maps.sh' script to generate FA maps 
# that will be used in Step 8 to create the FA-weighted connectome.
#
# Input:
# - Preprocessed DWI data in BIDS format.
# - Brainnetome Atlas file for diffusion space conversion.
#
# Output:
# - Tractograms and connectome matrices stored in the DWI_tractograms directory.

# Paths
bids_derivatives="/Volumes/working_disk_blue/SPRINT_MPS/bids_derivatives"
dwi_preprocessed="${bids_derivatives}/DWI_postprocessed"
git_dir="/Users/spascual/git/saulpascualdiaz/neuroimaging_pipelines"
DTI_dir="/Volumes/working_disk_blue/SPRINT_MPS/bids_derivatives/DWI_DTI-derived_maps"

# ANSI Color variables
BLUE='\033[1;34m'
NC='\033[0m' # Sin color (reset)

run_command() {
    echo -e "${BLUE}command:${NC} $*"
    "$@"
}

# Loop through each subject in the preprocessed DWI directory
for s in $(ls ${dwi_preprocessed}); do
    ses="baseline"  # Define session identifier (default: baseline)
    
    # Define input file paths based on the subject and session
    in_dwi_file=${dwi_preprocessed}/${s}/ses-${ses}/${s}_ses-${ses}_dir-AP_dwi_corr
    
    # Check if the expected DWI file exists, skip to next subject if not
    if [ ! -f ${in_dwi_file}.nii.gz ]; then continue; fi
    
    echo "Working on subject ${s}..."
    
    # Define output directory
    od=${bids_derivatives}/DWI_tractograms/${s}/ses-${ses}
    wd=${od}/${s}_ses-${ses}_dir-AP_dwi
    if [ ! -d ${od} ]; then mkdir -p ${od}; fi

    start_time=$(date +%s)

    # Step 0: Calculate brainmask in case it didn't exist
    if [ ! -f ${in_dwi_file}_mean_brainmask.nii.gz ]; then
        run_command fslmaths ${in_dwi_file}.nii.gz -Tmean ${in_dwi_file}_mean.nii.gz
        run_command bet2 ${in_dwi_file}_mean.nii.gz ${in_dwi_file}_mean_brain.nii.gz -f 0.45 -g 0.0
        run_command fslmaths ${in_dwi_file}_mean_brain.nii.gz -thr 0 -bin ${in_dwi_file}_mean_brainmask.nii.gz
    fi

    # Step 1: Estimate response function
    if [ ! -f ${wd}_response.txt ]; then
        run_command dwi2response tournier ${in_dwi_file}.nii.gz ${wd}_response.txt -fslgrad ${in_dwi_file}.bvec ${in_dwi_file}.bval -mask ${in_dwi_file}_mean_brainmask.nii.gz
    fi

    # Step 2: Perform constrained spherical deconvolution (CSD) to estimate FODs
    if [ ! -f ${wd}_fod.mif ]; then
        run_command dwi2fod csd ${in_dwi_file}.nii.gz ${wd}_response.txt ${wd}_fod.mif -fslgrad ${in_dwi_file}.bvec ${in_dwi_file}.bval -mask ${in_dwi_file}_mean_brainmask.nii.gz
    fi

    # Step 3: Generate tractogram with 5 million streamlines
    if [ ! -f ${wd}_tractogram_5M.tck ]; then
        run_command tckgen ${wd}_fod.mif ${wd}_tractogram_5M.tck -seed_dynamic ${wd}_fod.mif -select 5M -mask ${in_dwi_file}_mean_brainmask.nii.gz -maxlength 250
    fi

    # Step 4: SIFT to reduce the tractogram to 1 million streamlines
    if [ ! -f ${wd}_tractogram_SIFT_1M.tck ]; then
        run_command tcksift ${wd}_tractogram_5M.tck ${wd}_fod.mif ${wd}_tractogram_SIFT_1M.tck -term_number 1M
    fi

    # Cleanning files
    for f in ${wd}_fod.mif ${wd}_tractogram_5M.tck ${wd}_response.txt; do
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
done
