#!/bin/bash
# Author: Saül Pascual-Diaz
# Version: 1.2
# Date: September 19th, 2024

# Variables
git_dir="/Users/spascual/git/saulpascualdiaz/neuroimaging_pipelines"
source ${git_dir}/dependences/functions/common_bash_functions.sh
bidsDerivatives="/Volumes/working_disk_blue/SPRINT_MPS/bids_derivatives"
MNI_TEMPLATE="${FSLDIR}/data/standard/MNI152_T1_2mm_brain.nii.gz"
ATLAS="${git_dir}/dependences/atlas/BN_Atlas_246_2mm.nii.gz"
DTI_dir="/Volumes/working_disk_blue/SPRINT_MPS/bids_derivatives/DWI_DTI-derived_maps"

for s in $(ls ${bidsDerivatives}/DWI_postprocessed); do
    # Subject paths
    ses="baseline"
    wd_dwi="${bidsDerivatives}/DWI_postprocessed/${s}/ses-${ses}/${s}_ses-${ses}_dir-AP_dwi_corr"
    wd_dti="${bidsDerivatives}/DWI_DTI-derived_maps/${s}/ses-${ses}/${s}_ses-${ses}_dir-AP_dwi_corr"
    wd_trk="${bidsDerivatives}/DWI_tractograms/${s}/ses-${ses}/${s}_ses-${ses}_dir-AP_dwi_tractogram"

    # Subject files
    MEAN_BRAIN_DWI="${wd_dwi}_mean_brain.nii.gz"  # Mean b0 brain from DWI
    TRANSFORMED_ATLAS="${wd_dwi}_brainnetome.nii.gz"

    if ! file_exists ${wd_dwi}.nii.gz; then
        printf "Corrected dwi volumes not found for subject ${s}\n"
        continue
    fi

    if ! file_exists ${wd_trk}_SIFT_1M.tck; then
        printf "Tractogram not found for subject ${s}\n"
        continue
    fi

    if file_exists ${wd_trk}_SIFT_1M_connectome_FA.csv; then
        printf "Connectomes already calculated for for subject ${s}\n"
        continue
    fi

    if ! file_exists ${TRANSFORMED_ATLAS}; then
        # Step 1: Perform a linear registration from MNI to DWI using flirt
        echo "Step 1: Linear registration DWI -> MNI"
        run_command flirt \
            -in "${MEAN_BRAIN_DWI}" \
            -ref "${MNI_TEMPLATE}" \
            -omat "${wd_dwi}_diff2MNI.mat" \
            -out ${wd_dwi}_diff2MNI.nii.gz \
            -dof 12

        run_command convert_xfm -omat "${wd_dwi}_MNI2diff.mat" -inverse "${wd_dwi}_diff2MNI.mat"

        flirt -in ${ATLAS} \
            -ref ${MEAN_BRAIN_DWI} \
            -applyxfm -init ${wd_dwi}_MNI2diff.mat \
            -out ${TRANSFORMED_ATLAS} \
            -interp nearestneighbour

    fi

    if ! file_exists ${wd_trk}_SIFT_1M_connectome_streamcount.csv; then
        run_command tck2connectome ${wd_trk}_SIFT_1M.tck \
            ${TRANSFORMED_ATLAS} \
            ${wd_trk}_SIFT_1M_connectome_streamcount.csv \
            -symmetric \
            -zero_diagonal
    fi

    if ! file_exists "${wd_trk}_SIFT_1M_connectome_FA.csv"; then
        run_command tcksample ${wd_trk}_SIFT_1M.tck \
            ${wd_dti}_FA.nii.gz \
            ${wd_dti}_FA.csv \
            -stat_tck mean

        run_command tck2connectome ${wd_trk}_SIFT_1M.tck \
            ${TRANSFORMED_ATLAS} \
            ${wd_trk}_SIFT_1M_connectome_FA.csv \
            -scale_file ${wd_dti}_FA.csv \
            -stat_edge mean \
            -symmetric -zero_diagonal
    fi

    for f in ${wd_dti}_FA.csv; do
        if file_exists $f; then run_command rm $f; fi
    done
done

