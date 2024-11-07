#!/bin/bash
# Author: Saül Pascual-Diaz
# mail: spascual@ub.edu
# Department: Pain and Emotion Neuroscience Laboratory (PENLab)
# Version: 2.0
# Date: Nov 7th, 2024

# Description:
# This script performs coregistration of structural (T1-weighted) images and parcellation data with preprocessed 
# diffusion-weighted imaging (DWI) data for each subject. Additionally, it prepares data for tractography and segmentation.
# The script assumes that DWI preprocessing has already been completed using the `dwi_preprocessing_appa_pipeline.sh` script, 
# which is configured to handle BIDS-formatted data. This pipeline outputs corrected whole-brain tractograms.
# The script also uses anatomical images and parcellations from FreeSurfer for each subject.

# Usage:
# Run this script with bash, ensuring that paths for the BIDS directory, MATLAB, and SPM are correctly set.
# Adjust the 'bids_derivatives', 'MATLAB_PATH', and 'SPM_PATH' variables as needed.

# Assumptions:
# - The script requires preprocessed DWI data (AP orientation) for each subject.
# - FreeSurfer outputs, including T1-weighted images and parcellations, are present in each subject's folder.
# - MATLAB and SPM are installed for coregistration.
# - Data follows the BIDS (Brain Imaging Data Structure) format.


bids_derivatives="/bids/path/here/"
dwi_preproc="example_dwi_preproc"
git_dir="/path/2/git/"
fs_output="example_fs_output"
MATLAB_PATH="/matlab/bin/path" #i.e. /Applications/MATLAB_R2022a.app/bin/matlab
SPM_PATH="/spm/path/here"
threads=10

# do not modify beyond this point ------------------------------------------------
# ANSI color codes
BLUE='\033[0;34m'
NC='\033[0m' # No Color

#Shortcuts
for s in $(ls ${bids_derivatives}); do
    wd="${bids_derivatives}/${dwi_preproc}/${s}/ses-1/dwi/${s}_ses-1_dwi-AP_corr"
    fs="${bids_derivatives}/${fs_output}/${s}/ses-1/fs"
    
    # Preprocessed dwi volumes
    input_corr_dwi=${wd}.nii
    input_corr_val=${wd}.bval
    input_corr_vec=${wd}.bvec
    
    if [ ! -f ${wd}.nii ]; then continue; fi

    start_time=$(date +%s)

    # Structural 2 diff. coregistration
    if [ ! -f "${wd}_fs2diff_coords_T1w_brainmask_diff.nii.gz" ]; then
        mrconvert ${fs}/T1.mgz ${fs}/T1.nii
        mrconvert ${fs}/aparc+aseg.mgz ${fs}/aparc+aseg.nii
        mv ${fs}/T1.nii "${wd}_fs2diff_coords_T1w.nii"
        mv ${fs}/aparc+aseg.nii "${wd}_fs2diff_coords_aparc+aseg.nii"
        fslroi ${wd}.nii ${wd}_b0.nii.gz 0 1
        gzip -d ${wd}_b0.nii
        $MATLAB_PATH -nodisplay -nosplash -nodesktop -r "addpath('${SPM_PATH}'); addpath('${git_dir}/dependences/functions'); spm_coregister_parcellation('${wd}_b0.nii', '${wd}_fs2diff_coords_T1w.nii', '${wd}_fs2diff_coords_aparc+aseg.nii'); exit;"
   fi

    if [ ! -f "${wd}_mask.nii.gz" ]
    then
        fslroi ${wd}.nii ${wd}_b0.nii.gz 0 1
        dwi2mask ${wd}.nii \
            ${wd}_mask.nii.gz \
            -fslgrad ${wd}.bvec ${wd}.bval\
            -nthreads ${threads}
    fi

    if [ ! -f "${wd}_desc-csf_response.txt" ]
    then
        dwi2response dhollander ${wd}.nii \
            -fslgrad ${wd}.bvec ${wd}.bval \
            ${wd}_desc-wm_response.txt \
            ${wd}_desc-gm_response.txt \
            ${wd}_desc-csf_response.txt \
            -mask ${wd}_mask.nii.gz \
            -nthreads ${threads}
    fi

    if [ ! -f "${wd}_desc-wm_fod.mif" ]
    then
        dwi2fod msmt_csd ${wd}.nii \
            -fslgrad ${wd}.bvec \
            ${wd}.bval \
            ${wd}_desc-wm_response.txt \
            ${wd}_desc-wm_fod.mif \
            ${wd}_desc-gm_response.txt \
            ${wd}_desc-gm_fod.mif \
            ${wd}_desc-csf_response.txt \
            ${wd}_desc-csf_fod.mif \
            -mask ${wd}_mask.nii.gz \
            -nthreads ${threads}
    fi

    # 5 Tissues
    if [ ! -f "${wd}_fs2diff_coords_aparc+aseg_5TT.nii" ]; then
        5ttgen freesurfer "${wd}_fs2diff_coords_aparc+aseg.nii" "${wd}_fs2diff_coords_aparc+aseg_5TT.nii"
    fi

    # Creating matrix nodes
    if [ ! -f "${wd}_fs2diff_coords_aparc+aseg_nodes.nii.gz" ]; then
        labelconvert "${wd}_fs2diff_coords_aparc+aseg.nii" \
            ${fs_colorlut} ${fs_default} "${wd}_fs2diff_coords_aparc+aseg_nodes.nii.gz" -force
    fi

    # Tractogram calculation.
    if [ ! -f "${wd}_tractogram_10M.tck" ]
    then
    tckgen ${wd}_desc-wm_fod.mif\
        ${wd}_tractogram_10M.tck\
        -act "${wd}_fs2diff_coords_aparc+aseg_5TT.nii" \
        -backtrack -crop_at_gmwmi \
        -seed_dynamic ${wd}_desc-wm_fod.mif\
        -maxlength 250 -select 10M\
        -mask ${wd}_mask.nii.gz\
        -nthreads ${threads}
    fi

    if [ ! -f "${wd}_tractogram_2M_SIFT.tck" ]
    then    
    tcksift ${wd}_tractogram_10M.tck\
        ${wd}_desc-wm_fod.mif\
        ${wd}_tractogram_2M_SIFT.tck\
        -act "${wd}_fs2diff_coords_aparc+aseg_5TT.nii"\
        -term_number 2M -nthreads ${threads}
    fi

    end_time=$(date +%s)
    duration=$((end_time - start_time))
    
    if [ $duration -ge 3600 ]; then
        echo -e "${BLUE}Subject ${s} processing time: $(($duration / 3600)) hours, $((($duration % 3600) / 60)) minutes, and $(($duration % 60)) seconds.${NC}"
    elif [ $duration -ge 60 ]; then
        echo -e "${BLUE}Subject ${s} processing time: $(($duration / 60)) minutes and $(($duration % 60)) seconds.${NC}"
    else
        echo -e "${BLUE}Subject ${s} processing time: $duration seconds.${NC}"
    fi
done
