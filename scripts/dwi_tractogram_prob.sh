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
MATLAB_PATH=/Applications/MATLAB_R2022a.app/bin/matlab

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

    # Step 1: Calculate brain mask from DWI data using the gradient table
    if [ ! -f ${wd}_brainmask.nii.gz ]; then
        dwi2mask ${in_dwi_file}.nii.gz -fslgrad ${in_dwi_file}.bvec ${in_dwi_file}.bval - | mrconvert - ${wd}_brainmask.nii.gz
    fi

    # Step 2: Estimate response function
    if [ ! -f ${wd}_response.txt ]; then
        dwi2response tournier ${in_dwi_file}.nii.gz ${wd}_response.txt -fslgrad ${in_dwi_file}.bvec ${in_dwi_file}.bval -mask ${wd}_brainmask.nii.gz
    fi

    # Step 3: Perform constrained spherical deconvolution (CSD) to estimate FODs
    if [ ! -f ${wd}_fod.mif ]; then
        dwi2fod csd ${in_dwi_file}.nii.gz ${wd}_response.txt ${wd}_fod.mif -fslgrad ${in_dwi_file}.bvec ${in_dwi_file}.bval -mask ${wd}_brainmask.nii.gz
    fi

    # Step 4: Generate tractogram with 5 million streamlines
    if [ ! -f ${wd}_tractogram_5M.tck ]; then
        tckgen ${wd}_fod.mif ${wd}_tractogram_5M.tck -seed_dynamic ${wd}_fod.mif -select 2M -mask ${wd}_brainmask.nii.gz -maxlength 250
    fi

    # Step 5: SIFT to reduce the tractogram to 1 million streamlines
    if [ ! -f ${wd}_tractogram_SIFT_1M.tck ]; then
        tcksift ${wd}_tractogram_5M.tck ${wd}_fod.mif ${wd}_tractogram_SIFT_1M.tck -term_number 1M
    fi

    # Step 6: Convert Brainnetome atlas to diffusion space
    if [ ! -f ${wd}_labels.nii.gz ]; then
        cp ${FSLDIR}/data/standard/MNI152_T1_2mm.nii.gz ${wd}_MNI2diff.nii.gz
        cp ${git_dir}/dependences/atlas/BN_Atlas_246_2mm.nii.gz ${wd}_labels.nii.gz
        cp ${DTI_dir}/${s}/ses-${ses}/${s}_ses-${ses}_dir-AP_dwi_corr_FA.nii.gz ${wd}_FAreff.nii.gz
        gzip -d ${wd}_MNI2diff.nii.gz
        gzip -d ${wd}_FAreff.nii.gz
        gzip -d ${wd}_labels.nii.gz
        $MATLAB_PATH -nodisplay -nosplash -nodesktop -r "addpath('${git_dir}/dependences/functions'); spm_coregister_parcellation('${wd}_FAreff.nii', '${wd}_MNI2diff.nii', '${wd}_labels.nii'); exit;"
        rm ${wd}_FAreff.nii
        gzip ${wd}_labels.nii
        gzip ${wd}_MNI2diff.nii
   fi

    # Step 7: Generate streamlines connectome using SIFTed tractogram (stream count)
    if [ ! -f ${wd}_connectome_streamcount.csv ]; then
        tck2connectome ${wd}_tractogram_SIFT_1M.tck ${wd}_labels.nii.gz ${wd}_connectome_streamcount.csv -symmetric -zero_diagonal
    fi

    # Step 8: Generate FA-weighted connectome using SIFTed tractogram (Assumes DTI maps have been generated)
    if [ ! -f ${wd}_connectome_fa.csv ]; then
        tcksample ${wd}_tractogram_SIFT_1M.tck ${DTI_dir}/${s}/ses-${ses}/${s}_ses-${ses}_dir-AP_dwi_corr_FA.nii.gz ${wd}_fa_samples.csv -stat_tck mean
        tck2connectome ${wd}_tractogram_SIFT_1M.tck ${wd}_labels.nii.gz ${wd}_connectome_fa.csv -scale_file ${wd}_fa_samples.csv -stat_edge mean -symmetric -zero_diagonal
    fi

    # Break after processing one subject (for testing purposes)
    break
done
