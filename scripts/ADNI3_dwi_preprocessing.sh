#!/bin/bash

# ADNI3 DWI Preprocessing Job Script
# Single subject processing job - called by batch script
# Features: denoising, Gibbs ringing removal, bias correction, fieldmap-based distortion correction, and anatomical registration
# Author: Saül Pascual-Diaz
# Date: 2025/07/29

set -e  # Exit on any error

# =============================================================================
# PARAMETER VALIDATION
# =============================================================================

# Check if required parameters are provided
if [[ $# -ne 4 ]]; then
    echo "ERROR: Invalid number of arguments"
    echo "Usage: $0 <SUBJECT> <BIDS_DIR> <SESSION> <DERIVATIVES_DIR>"
    echo "Example: $0 sub-001 /path/to/bids baseline /path/to/derivatives"
    exit 1
fi

# Parse input parameters
SUBJECT="$1"
BIDS_DIR="$2"
SESSION="$3"
DERIVATIVES_DIR="$4"

echo "==================================================================="
echo "ADNI3 - DWI Preprocessing Job"
echo "==================================================================="
echo "Subject: ${SUBJECT}"
echo "BIDS Directory: ${BIDS_DIR}"
echo "Session: ${SESSION}"
echo "Derivatives: ${DERIVATIVES_DIR}"
echo "Started: $(date)"
echo "==================================================================="

# =============================================================================
# PROCESSING PIPELINE
# =============================================================================

# Define paths
DWI_DIR="${BIDS_DIR}/${SUBJECT}/${SESSION}/dwi"
FMAP_DIR="${BIDS_DIR}/${SUBJECT}/${SESSION}/fmap"
ANAT_DIR="${BIDS_DIR}/${SUBJECT}/${SESSION}/anat"
OUTPUT_DIR="${DERIVATIVES_DIR}/${SUBJECT}/${SESSION}"
WORK_DIR="${OUTPUT_DIR}/work"

# Required files - ADNI3 BIDS structure
DWI_NII="${DWI_DIR}/${SUBJECT}_dwi.nii.gz"
DWI_BVAL="${DWI_DIR}/${SUBJECT}_dwi.bval"
DWI_BVEC="${DWI_DIR}/${SUBJECT}_dwi.bvec"
DWI_JSON="${DWI_DIR}/${SUBJECT}_dwi.json"
T1_NII="${ANAT_DIR}/${SUBJECT}_T1w.nii.gz"

# Fieldmap files - dual-echo GRE structure
FMAP_E1="${FMAP_DIR}/${SUBJECT}_fmap_e1.nii"
FMAP_E2="${FMAP_DIR}/${SUBJECT}_fmap_e2.nii"

# Check for phase difference file
PHASE_FILE=""
for ext in ".nii.gz" ".nii"; do
    if [[ -f "${FMAP_DIR}/${SUBJECT}_fmap_e2_ph${ext}" ]]; then
        PHASE_FILE="${FMAP_DIR}/${SUBJECT}_fmap_e2_ph${ext}"
        break
    fi
done

# Check if required files exist (including phase file and T1)
MISSING_FILES=()
for file in "${DWI_NII}" "${DWI_BVAL}" "${DWI_BVEC}" "${DWI_JSON}" "${FMAP_E1}" "${FMAP_E2}" "${T1_NII}"; do
    if [[ ! -f "$file" ]]; then
        MISSING_FILES+=("$file")
    fi
done

# Check for phase file
if [[ -z "$PHASE_FILE" ]]; then
    MISSING_FILES+=("${FMAP_DIR}/${SUBJECT}_fmap_e2_ph.nii or .nii.gz")
fi

if [[ ${#MISSING_FILES[@]} -gt 0 ]]; then
    echo "ERROR: Missing required files for ${SUBJECT}:"
    printf '  - %s\n' "${MISSING_FILES[@]}"
    echo "✗ ${SUBJECT} failed - missing files"
    exit 1
fi

# Create directories
mkdir -p "${OUTPUT_DIR}" "${WORK_DIR}"

echo "Processing ${SUBJECT}..."

# Create log file for this subject
LOG_FILE="${OUTPUT_DIR}/${SUBJECT}_dwi_corr.log"
echo "==================================================================" > "${LOG_FILE}"
echo "ADNI3 DWI Preprocessing Log for ${SUBJECT}" >> "${LOG_FILE}"
echo "Started: $(date)" >> "${LOG_FILE}"
echo "==================================================================" >> "${LOG_FILE}"
echo "" >> "${LOG_FILE}"

# Check if already processed
if [[ -f "${OUTPUT_DIR}/${SUBJECT}_dwi_corr.nii.gz" ]]; then
    echo "Subject ${SUBJECT} already processed. Skipping..."
    exit 0
fi

# Check if eddy correction is already completed
EDDY_COMPLETED=false
if [[ -f "${WORK_DIR}/dwi_eddy.nii.gz" ]] && [[ -f "${WORK_DIR}/dwi_eddy.eddy_rotated_bvecs" ]]; then
    echo "Eddy correction already completed for ${SUBJECT}. Resuming from registration step..." >> "${LOG_FILE}"
    EDDY_COMPLETED=true
fi

# Get processing parameters
PE_DIR=$(python3 -c "import json; print(json.load(open('${DWI_JSON}'))['PhaseEncodingDirection'])" 2>>"${LOG_FILE}")
READOUT_TIME=$(python3 -c "import json; print(json.load(open('${DWI_JSON}'))['TotalReadoutTime'])" 2>>"${LOG_FILE}")

echo "Phase encoding: ${PE_DIR}, Readout time: ${READOUT_TIME}s" >> "${LOG_FILE}"
    
    # Run preprocessing pipeline if not already completed
    if [[ "$EDDY_COMPLETED" == false ]]; then
        echo "Running full preprocessing pipeline..." >> "${LOG_FILE}"
        
        # Fieldmap information
        echo "Dual-echo GRE fieldmap files found:" >> "${LOG_FILE}"
        echo "  Echo 1: ${FMAP_E1}" >> "${LOG_FILE}"
        echo "  Echo 2: ${FMAP_E2}" >> "${LOG_FILE}"
        echo "Will prepare fieldmap for distortion correction" >> "${LOG_FILE}"
        
        # Start processing pipeline
        echo "Step 1: Converting to MRtrix format..." >> "${LOG_FILE}"
        if ! mrconvert "${DWI_NII}" "${WORK_DIR}/dwi_raw.mif" \
            -fslgrad "${DWI_BVEC}" "${DWI_BVAL}" \
            -json_import "${DWI_JSON}" \
            -force >> "${LOG_FILE}" 2>&1; then
            echo "ERROR: mrconvert failed for ${SUBJECT}" >> "${LOG_FILE}"
            echo "✗ ${SUBJECT} failed - mrconvert error"
            exit 1
        fi
        
        echo "Step 2: MP-PCA denoising..." >> "${LOG_FILE}"
        if ! dwidenoise "${WORK_DIR}/dwi_raw.mif" "${WORK_DIR}/dwi_denoised.mif" \
            -noise "${WORK_DIR}/noise_map.mif" \
            -force >> "${LOG_FILE}" 2>&1; then
            echo "ERROR: dwidenoise failed for ${SUBJECT}" >> "${LOG_FILE}"
            echo "✗ ${SUBJECT} failed - dwidenoise error"
            exit 1
        fi
        
        if [[ ! -f "${WORK_DIR}/dwi_denoised.mif" ]]; then
            echo "ERROR: dwidenoise did not create expected output file for ${SUBJECT}" >> "${LOG_FILE}"
            echo "✗ ${SUBJECT} failed - dwidenoise output missing"
            exit 1
        fi
        
        echo "Step 3: Gibbs ringing removal..." >> "${LOG_FILE}"
        if ! mrdegibbs "${WORK_DIR}/dwi_denoised.mif" "${WORK_DIR}/dwi_degibbs.mif" \
            -force >> "${LOG_FILE}" 2>&1; then
            echo "ERROR: mrdegibbs failed for ${SUBJECT}" >> "${LOG_FILE}"
            echo "✗ ${SUBJECT} failed - mrdegibbs error"
            exit 1
        fi
        
        if [[ ! -f "${WORK_DIR}/dwi_degibbs.mif" ]]; then
            echo "ERROR: mrdegibbs did not create expected output file for ${SUBJECT}" >> "${LOG_FILE}"
            echo "✗ ${SUBJECT} failed - mrdegibbs output missing"
            exit 1
        fi
        
        # Step 4: Bias field correction
        echo "Step 4: Bias field correction..." >> "${LOG_FILE}"
        echo "Creating brain mask for bias correction..." >> "${LOG_FILE}"
        if ! dwi2mask "${WORK_DIR}/dwi_degibbs.mif" "${WORK_DIR}/brain_mask.mif" -force >> "${LOG_FILE}" 2>&1; then
            echo "ERROR: dwi2mask failed for ${SUBJECT}" >> "${LOG_FILE}"
            echo "✗ ${SUBJECT} failed - dwi2mask error"
            exit 1
        fi
        
        if ! mrconvert "${WORK_DIR}/brain_mask.mif" "${WORK_DIR}/brain_mask.nii.gz" -force >> "${LOG_FILE}" 2>&1; then
            echo "ERROR: mrconvert brain_mask failed for ${SUBJECT}" >> "${LOG_FILE}"
            echo "✗ ${SUBJECT} failed - mrconvert brain_mask error"
            exit 1
        fi
        
        echo "Applying bias field correction..." >> "${LOG_FILE}"
        if ! dwibiascorrect ants \
            -mask "${WORK_DIR}/brain_mask.nii.gz" \
            "${WORK_DIR}/dwi_degibbs.mif" \
            "${WORK_DIR}/dwi_biascorrected_preeddy.mif" \
            -bias "${WORK_DIR}/bias_field_early.mif" \
            -force >> "${LOG_FILE}" 2>&1; then
            echo "ERROR: Early bias correction failed for ${SUBJECT}" >> "${LOG_FILE}"
            echo "✗ ${SUBJECT} failed - early bias correction error"
            exit 1
        fi
        
        echo "✓ Bias field correction completed" >> "${LOG_FILE}"
        
        echo "Step 5: Motion and distortion correction..." >> "${LOG_FILE}"
        echo "Step 5a: Preparing fieldmap for distortion correction..." >> "${LOG_FILE}"
        
        echo "Phase difference file found: ${PHASE_FILE}" >> "${LOG_FILE}"
        echo "Using fieldmap-based distortion correction" >> "${LOG_FILE}"
        
        # Extract echo times from JSON files
        TE1=$(python3 -c "import json; print(json.load(open('${FMAP_DIR}/${SUBJECT}_fmap_e1.json'))['EchoTime'])" 2>>"${LOG_FILE}")
        TE2=$(python3 -c "import json; print(json.load(open('${FMAP_DIR}/${SUBJECT}_fmap_e2.json'))['EchoTime'])" 2>>"${LOG_FILE}")
        DELTA_TE=$(echo "1000 * (${TE2} - ${TE1})" | bc -l)
        
        echo "Echo times: TE1=${TE1}s, TE2=${TE2}s, ΔTE=${DELTA_TE}ms" >> "${LOG_FILE}"
        
        # Extract b=0 volumes for fieldmap registration
        if ! dwiextract "${WORK_DIR}/dwi_biascorrected_preeddy.mif" "${WORK_DIR}/b0.mif" -bzero -force >> "${LOG_FILE}" 2>&1; then
            echo "ERROR: dwiextract failed for ${SUBJECT}" >> "${LOG_FILE}"
            echo "✗ ${SUBJECT} failed - dwiextract error"
            exit 1
        fi
        
        if ! mrconvert "${WORK_DIR}/b0.mif" "${WORK_DIR}/b0.nii.gz" -force >> "${LOG_FILE}" 2>&1; then
            echo "ERROR: mrconvert b0 failed for ${SUBJECT}" >> "${LOG_FILE}"
            echo "✗ ${SUBJECT} failed - mrconvert b0 error"
            exit 1
        fi
        
        # Prepare fieldmap using FSL tools
        echo "Creating fieldmap using fsl_prepare_fieldmap..." >> "${LOG_FILE}"
        echo "Applying ADNI-specific phase scaling..." >> "${LOG_FILE}"
        
        # Scale phase data for ADNI format
        if ! fslmaths "${PHASE_FILE}" -sub 2047.5 -mul 0.00153398 "${WORK_DIR}/phase_scaled" >> "${LOG_FILE}" 2>&1; then
            echo "ERROR: Phase scaling failed for ${SUBJECT}" >> "${LOG_FILE}"
            echo "✗ ${SUBJECT} failed - phase scaling error"
            exit 1
        fi
        
        if ! fsl_prepare_fieldmap SIEMENS \
            "${WORK_DIR}/phase_scaled" \
            "${FMAP_E1}" \
            "${WORK_DIR}/fieldmap_rads" \
            "${DELTA_TE}" \
            --nocheck >> "${LOG_FILE}" 2>&1; then
            echo "ERROR: fsl_prepare_fieldmap failed for ${SUBJECT}" >> "${LOG_FILE}"
            echo "✗ ${SUBJECT} failed - fsl_prepare_fieldmap error"
            exit 1
        fi
        
        # Convert fieldmap from rad/s to Hz for eddy
        if ! fslmaths "${WORK_DIR}/fieldmap_rads" -div 6.28318530718 "${WORK_DIR}/fieldmap_hz" >> "${LOG_FILE}" 2>&1; then
            echo "ERROR: Fieldmap Hz conversion failed for ${SUBJECT}" >> "${LOG_FILE}"
            echo "✗ ${SUBJECT} failed - fieldmap conversion error"
            exit 1
        fi
        
        # Create brain mask from fieldmap magnitude
        if ! bet "${FMAP_E1}" "${WORK_DIR}/fmap_mag_brain" -m -f 0.3 >> "${LOG_FILE}" 2>&1; then
            echo "ERROR: BET on fieldmap magnitude failed for ${SUBJECT}" >> "${LOG_FILE}"
            echo "✗ ${SUBJECT} failed - BET error"
            exit 1
        fi
        
        # Register fieldmap to DWI space
        echo "Registering fieldmap to DWI space..." >> "${LOG_FILE}"
        if ! flirt -in "${WORK_DIR}/fmap_mag_brain.nii.gz" -ref "${WORK_DIR}/b0.nii.gz" \
              -out "${WORK_DIR}/fmap_to_b0.nii.gz" -omat "${WORK_DIR}/fmap_to_b0.mat" -dof 12 -interp spline >> "${LOG_FILE}" 2>&1; then
            echo "ERROR: FLIRT registration failed for ${SUBJECT}" >> "${LOG_FILE}"
            echo "✗ ${SUBJECT} failed - FLIRT error"
            exit 1
        fi
        
        if ! flirt -in "${WORK_DIR}/fieldmap_hz.nii.gz" -ref "${WORK_DIR}/b0.nii.gz" \
              -applyxfm -init "${WORK_DIR}/fmap_to_b0.mat" -out "${WORK_DIR}/fmap_hz_reg.nii.gz" -interp spline >> "${LOG_FILE}" 2>&1; then
            echo "ERROR: FLIRT apply transform failed for ${SUBJECT}" >> "${LOG_FILE}"
            echo "✗ ${SUBJECT} failed - FLIRT apply error"
            exit 1
        fi
        
        # Smooth the fieldmap to reduce noise and spikes
        echo "Smoothing fieldmap to reduce noise and spikes..." >> "${LOG_FILE}"
        if ! fslmaths "${WORK_DIR}/fmap_hz_reg.nii.gz" -s 2.0 "${WORK_DIR}/fmap_hz_smooth.nii.gz" >> "${LOG_FILE}" 2>&1; then
            echo "ERROR: Fieldmap smoothing failed for ${SUBJECT}" >> "${LOG_FILE}"
            echo "✗ ${SUBJECT} failed - smoothing error"
            exit 1
        fi
        
        # Ensure consistent spatial orientation
        echo "Setting consistent spatial orientation..." >> "${LOG_FILE}"
        SFORM_CODE=$(fslorient -getsformcode "${WORK_DIR}/b0.nii.gz")
        if ! fslorient -setsformcode ${SFORM_CODE} "${WORK_DIR}/fmap_hz_smooth.nii.gz" >> "${LOG_FILE}" 2>&1; then
            echo "ERROR: Setting sform failed for ${SUBJECT}" >> "${LOG_FILE}"
            echo "✗ ${SUBJECT} failed - sform error"
            exit 1
        fi
        
        echo "✓ Proper fieldmap prepared successfully" >> "${LOG_FILE}"
        
        # Create acquisition parameters file for eddy
        if [[ "${PE_DIR}" == "j-" ]]; then
            echo "0 -1 0 ${READOUT_TIME}" > "${WORK_DIR}/acqparams.txt"
        elif [[ "${PE_DIR}" == "j" ]]; then
            echo "0 1 0 ${READOUT_TIME}" > "${WORK_DIR}/acqparams.txt"
        elif [[ "${PE_DIR}" == "i-" ]]; then
            echo "-1 0 0 ${READOUT_TIME}" > "${WORK_DIR}/acqparams.txt"
        elif [[ "${PE_DIR}" == "i" ]]; then
            echo "1 0 0 ${READOUT_TIME}" > "${WORK_DIR}/acqparams.txt"
        else
            echo "ERROR: Unknown phase encoding direction: ${PE_DIR}" >> "${LOG_FILE}"
            echo "✗ ${SUBJECT} failed - unknown PE direction"
            exit 1
        fi
        
        # Create index file
        NVOLS=$(mrinfo "${WORK_DIR}/dwi_biascorrected_preeddy.mif" -size | awk '{print $4}')
        seq 1 ${NVOLS} | awk '{print "1"}' > "${WORK_DIR}/index.txt"
        
        # Export data for FSL eddy
        if ! mrconvert "${WORK_DIR}/dwi_biascorrected_preeddy.mif" "${WORK_DIR}/dwi_for_eddy.nii.gz" -export_grad_fsl "${WORK_DIR}/bvecs" "${WORK_DIR}/bvals" -force >> "${LOG_FILE}" 2>&1; then
            echo "ERROR: mrconvert for eddy export failed for ${SUBJECT}" >> "${LOG_FILE}"
            echo "✗ ${SUBJECT} failed - mrconvert export error"
            exit 1
        fi
        
        # Run FSL eddy with fieldmap-based distortion correction
        export OMP_NUM_THREADS=1
        
        echo "Running eddy with fieldmap correction..." >> "${LOG_FILE}"
        if ! eddy --imain="${WORK_DIR}/dwi_for_eddy.nii.gz" \
                 --mask="${WORK_DIR}/brain_mask.nii.gz" \
                 --acqp="${WORK_DIR}/acqparams.txt" \
                 --index="${WORK_DIR}/index.txt" \
                 --bvecs="${WORK_DIR}/bvecs" \
                 --bvals="${WORK_DIR}/bvals" \
                 --field="${WORK_DIR}/fmap_hz_smooth" \
                 --slm=linear \
                 --repol \
                 --data_is_shelled \
                 --out="${WORK_DIR}/dwi_eddy" \
                 --verbose >> "${LOG_FILE}" 2>&1; then
            echo "ERROR: FSL eddy with fieldmap failed for ${SUBJECT}" >> "${LOG_FILE}"
            echo "✗ ${SUBJECT} failed - eddy error"
            exit 1
        fi
        echo "✓ Fieldmap-based distortion correction completed" >> "${LOG_FILE}"
        
        # Verify eddy outputs
        if [[ ! -f "${WORK_DIR}/dwi_eddy.nii.gz" ]] || [[ ! -f "${WORK_DIR}/dwi_eddy.eddy_rotated_bvecs" ]]; then
            echo "ERROR: Expected eddy output files not found for ${SUBJECT}" >> "${LOG_FILE}"
            echo "✗ ${SUBJECT} failed - eddy outputs missing"
            exit 1
        fi
    else
        echo "Skipping preprocessing steps - eddy outputs already exist" >> "${LOG_FILE}"
        echo "Proceeding directly to registration and final export..." >> "${LOG_FILE}"
    fi
    
    # DWI-to-T1 rigid registration
    echo "Step 5b: DWI-to-T1 rigid registration..." >> "${LOG_FILE}"
    echo "Using 6 DOF rigid registration (no deformation) for anatomical alignment..." >> "${LOG_FILE}"
    
    # Extract mean b=0 for registration (single volume) - use FSL tools for NIfTI files
    echo "Extracting b=0 volumes for registration..." >> "${LOG_FILE}"
    
    # Read bvals file to find b=0 indices
    BVAL_FILE="${WORK_DIR}/bvals"
    if [[ "$EDDY_COMPLETED" == false ]]; then
        BVAL_FILE="${WORK_DIR}/bvals"
    else
        # If eddy was already completed, use original bvals file
        BVAL_FILE="${DWI_BVAL}"
    fi
    
    # Find b=0 volumes using awk
    BZERO_INDICES=$(awk '{for(i=1;i<=NF;i++) if($i<=50) printf "%d,",(i-1)}' "${BVAL_FILE}" | sed 's/,$//')
    
    if [[ -z "$BZERO_INDICES" ]]; then
        echo "ERROR: No b=0 volumes found for ${SUBJECT}" >> "${LOG_FILE}"
        echo "✗ ${SUBJECT} failed - no b=0 volumes"
        exit 1
    fi
    
    echo "Found b=0 indices: ${BZERO_INDICES}" >> "${LOG_FILE}"
    
    # Extract b=0 volumes using fslroi (first b=0 volume)
    FIRST_BZERO=$(echo ${BZERO_INDICES} | cut -d',' -f1)
    if ! fslroi "${WORK_DIR}/dwi_eddy.nii.gz" "${WORK_DIR}/b0_mean.nii.gz" ${FIRST_BZERO} 1 >> "${LOG_FILE}" 2>&1; then
        echo "ERROR: b0 extraction for registration failed for ${SUBJECT}" >> "${LOG_FILE}"
        echo "✗ ${SUBJECT} failed - b0 extraction error"
        exit 1
    fi
    
    # Calculate transformation matrix using b=0
    if ! flirt \
        -in "${WORK_DIR}/b0_mean.nii.gz" \
        -ref "${T1_NII}" \
        -omat "${WORK_DIR}/dwi2t1_affine.mat" \
        -dof 6 \
        -interp spline >> "${LOG_FILE}" 2>&1; then
        echo "ERROR: FLIRT rigid registration failed for ${SUBJECT}" >> "${LOG_FILE}"
        echo "✗ ${SUBJECT} failed - FLIRT rigid registration error"
        exit 1
    fi
    
    # Apply transformation to full 4D DWI dataset
    if ! flirt \
        -in "${WORK_DIR}/dwi_eddy.nii.gz" \
        -ref "${T1_NII}" \
        -applyxfm \
        -init "${WORK_DIR}/dwi2t1_affine.mat" \
        -out "${WORK_DIR}/dwi_final.nii.gz" \
        -interp spline >> "${LOG_FILE}" 2>&1; then
        echo "ERROR: FLIRT transform application failed for ${SUBJECT}" >> "${LOG_FILE}"
        echo "✗ ${SUBJECT} failed - FLIRT transform application error"
        exit 1
    fi
    
    echo "✓ Rigid registration completed!" >> "${LOG_FILE}"
    
    echo "Preserving eddy-corrected gradient directions (not affected by rigid transform)" >> "${LOG_FILE}"
    
    # Convert back to MRtrix format - use the correct gradient files
    BVEC_FILE="${WORK_DIR}/dwi_eddy.eddy_rotated_bvecs"
    if [[ "$EDDY_COMPLETED" == false ]]; then
        BVALS_FILE="${WORK_DIR}/bvals"
    else
        BVALS_FILE="${DWI_BVAL}"
    fi
    
    if ! mrconvert "${WORK_DIR}/dwi_final.nii.gz" "${WORK_DIR}/dwi_final.mif" \
        -fslgrad "${BVEC_FILE}" "${BVALS_FILE}" \
        -json_import "${DWI_JSON}" \
        -force >> "${LOG_FILE}" 2>&1; then
        echo "ERROR: mrconvert to mif failed for ${SUBJECT}" >> "${LOG_FILE}"
        echo "✗ ${SUBJECT} failed - mrconvert to mif error"
        exit 1
    fi
    
    echo "✓ Rigid registration completed successfully!" >> "${LOG_FILE}"
    echo "✓ Bias field correction was applied early in pipeline!" >> "${LOG_FILE}"
    
    echo "Step 6: Exporting final corrected files..." >> "${LOG_FILE}"
    
    # Get original data type to preserve file size
    ORIGINAL_DATATYPE=$(fslinfo "${DWI_NII}" | grep "^datatype" | awk '{print $2}')
    echo "Original datatype: ${ORIGINAL_DATATYPE}" >> "${LOG_FILE}"
    
    # Convert datatype code to mrconvert format
    case ${ORIGINAL_DATATYPE} in
        2) MRCONVERT_DTYPE="uint8" ;;
        4) MRCONVERT_DTYPE="int16" ;;
        8) MRCONVERT_DTYPE="int32" ;;
        16) MRCONVERT_DTYPE="float32" ;;
        64) MRCONVERT_DTYPE="float64" ;;
        256) MRCONVERT_DTYPE="int8" ;;
        512) MRCONVERT_DTYPE="uint16" ;;
        768) MRCONVERT_DTYPE="uint32" ;;
        *) MRCONVERT_DTYPE="int16" ;; # Default fallback
    esac
    
    echo "Using datatype: ${MRCONVERT_DTYPE} for final export" >> "${LOG_FILE}"
    
    if ! mrconvert "${WORK_DIR}/dwi_final.mif" "${OUTPUT_DIR}/${SUBJECT}_dwi_corr.nii.gz" \
        -export_grad_fsl "${OUTPUT_DIR}/${SUBJECT}_dwi_corr.bvec" "${OUTPUT_DIR}/${SUBJECT}_dwi_corr.bval" \
        -datatype "${MRCONVERT_DTYPE}" \
        -force >> "${LOG_FILE}" 2>&1; then
        echo "ERROR: Final export failed for ${SUBJECT}" >> "${LOG_FILE}"
        echo "✗ ${SUBJECT} failed - final export error"
        exit 1
    fi
    
    # Log file sizes for comparison
    ORIGINAL_SIZE=$(du -h "${DWI_NII}" | cut -f1)
    FINAL_SIZE=$(du -h "${OUTPUT_DIR}/${SUBJECT}_dwi_corr.nii.gz" | cut -f1)
    echo "File size comparison - Original: ${ORIGINAL_SIZE}, Processed: ${FINAL_SIZE}" >> "${LOG_FILE}"
    
    # Create JSON with processing info
    cat > "${OUTPUT_DIR}/${SUBJECT}_dwi_corr.json" << EOF
{
    "ProcessingPipeline": "MRtrix3 + FSL DWI Preprocessing with Early Bias Correction",
    "ProcessingSteps": [
        "Denoising (dwidenoise)",
        "Gibbs ringing removal (mrdegibbs)", 
        "Bias field correction (dwibiascorrect with ANTs N4) - before motion correction",
        "Dual-echo GRE fieldmap preparation with ADNI phase scaling",
        "Fieldmap registration (12 DOF affine, spline interpolation, smoothing)",
        "Enhanced motion and susceptibility distortion correction on bias-corrected data (FSL eddy with fieldmap, outlier replacement, data_is_shelled)",
        "DWI-to-T1 rigid registration (FLIRT 6 DOF)"
    ],
    "ProcessingDate": "$(date -Iseconds)",
    "Subject": "${SUBJECT}",
    "Session": "${SESSION}",
    "PhaseEncodingDirection": "${PE_DIR}",
    "TotalReadoutTime": ${READOUT_TIME},
    "BiasCorrection": "Applied early in pipeline (before motion correction)",
    "RegistrationApproach": "Rigid registration (6 DOF)"
}
EOF
    
    # Clean up work directory to save space ONLY after successful completion
    echo "Cleaning up temporary files..." >> "${LOG_FILE}"
    rm -rf "${WORK_DIR}"
    
echo "✓ ${SUBJECT} completed successfully" >> "${LOG_FILE}"
echo "Completed: $(date)" >> "${LOG_FILE}"
echo "✓ ${SUBJECT} completed successfully"

exit 0
