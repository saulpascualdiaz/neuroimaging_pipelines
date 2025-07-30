# ADNI3 DWI Preprocessing Pipeline

A comprehensive preprocessing pipeline for diffusion-## Output Structure

Processed data is saved to the derivatives directory:

```
derivatives/dwi_preprocessing/
├── sub-{subject}/
│   └── baseline/
│       ├── sub-{subject}_dwi_corr.nii.gz     # Corrected DWI data
│       ├── sub-{subject}_dwi_corr.bval       # B-values
│       ├── sub-{subject}_dwi_corr.bvec       # B-vectors (eddy-corrected)
│       ├── sub-{subject}_dwi_corr.json       # Processing metadata
│       └── sub-{subject}_dwi_corr.log        # Processing log
├── sub-{subject}_batch.log                   # Batch processing log (if using batch)
```

## Key Features

### Early Bias Correction
Bias field correction is applied before motion correction to improve registration contrast and accuracy.

### ADNI-Specific Fieldmap Processing
The pipeline includes proper phase scaling for ADNI dual-echo GRE fieldmaps (0-4095 scale to -π to +π radians).

### Conservative Registration
Uses rigid (6 DOF) registration to T1w images to preserve DWI signal characteristics while achieving anatomical alignment.

### Data Type Preservation
Automatically detects and preserves the original data type to maintain file sizes and avoid unnecessary precision inflation.

### Resumption Capability
The pipeline can resume processing from the registration step if eddy correction has already been completed.

## Configuration Options

### Parallel Processing
Adjust `MAX_PARALLEL_JOBS` in the batch script based on your system capabilities:
- Consider available CPU cores and memory
- Each job requires significant memory during eddy processing
- Typical values: 2-4 for standard workstations

### Processing Parameters
Key parameters are automatically extracted from JSON files:
- Phase encoding direction
- Total readout time
- Echo times for fieldmap processing

## Troubleshooting

### Common Issues

1. **Missing Dependencies**: Ensure all required software is installed and in your PATH
2. **Memory Issues**: Reduce MAX_PARALLEL_JOBS if you encounter out-of-memory errors
3. **Missing Files**: Check that all required BIDS files are present before processing
4. **Permission Errors**: Ensure scripts are executable (`chmod +x *.sh`)

### Log Files
Each subject generates detailed logs:
- Individual processing logs: `{subject}_dwi_corr.log`
- Batch processing logs: `{subject}_batch.log`
- Check these files for detailed error information

## Performance Notes

### Processing Time
- Single subject: ~2-6 hours depending on data size and system specifications
- Eddy correction is the most time-consuming step
- Fieldmap processing adds ~30-60 minutes per subject

### File Sizes
- Original DWI data type is preserved to maintain reasonable file sizes
- Typical processed file sizes: 300-400MB (compared to 1GB+ with float64)

## Technical Details

### Fieldmap Processing
- Dual-echo GRE fieldmaps are processed with proper ADNI phase scaling
- Fieldmaps are registered to DWI space using 12 DOF affine registration
- Smoothing is applied to reduce noise and spikes

### Motion Correction
- FSL eddy with fieldmap-based susceptibility distortion correction
- Outlier replacement enabled
- Data assumed to be single-shell (data_is_shelled option)

### Registration
- B0 volumes extracted for registration reference
- Rigid (6 DOF) transformation to preserve DWI characteristics
- Gradient directions preserved (not affected by rigid transforms)

## References

If you use this pipeline, please cite the relevant software packages:
- MRtrix3: Tournier et al. (2019) NeuroImage 202:116137
- FSL: Jenkinson et al. (2012) NeuroImage 62:782-90
- ANTs: Avants et al. (2011) NeuroImage 54:2033-44

## Contact

Author: Saül Pascual-Diaz  
Date: 2025/07/29ging (DWI) data from the ADNI3 dataset. The pipeline uses MRtrix3 and FSL tools to perform denoising, Gibbs ringing removal, bias field correction, fieldmap-based distortion correction, and anatomical registration.

## Overview

The pipeline consists of two main components:

- **`ADNI3_dwi_preprocessing_job.sh`**: Single-subject processing script that performs the complete preprocessing pipeline
- **`ADNI3_dwi_preprocessing_batch.sh`**: Batch manager that handles configuration and parallel execution of multiple subjects

## Processing Steps

1. **Data Conversion**: Convert DWI data to MRtrix format with gradient information
2. **MP-PCA Denoising**: Remove thermal noise using dwidenoise
3. **Gibbs Ringing Removal**: Correct Gibbs ringing artifacts using mrdegibbs
4. **Bias Field Correction**: Apply ANTs N4 bias field correction before motion correction
5. **Fieldmap Preparation**: Process dual-echo GRE fieldmaps with ADNI-specific phase scaling
6. **Motion and Distortion Correction**: FSL eddy with fieldmap-based susceptibility distortion correction
7. **Anatomical Registration**: Rigid (6 DOF) registration to T1w structural image
8. **Final Export**: Export corrected DWI data with preserved original data type

## Prerequisites

### Required Software

- **MRtrix3** (version 3.0 or later)
- **FSL** (version 6.0 or later) 
- **ANTs** (for N4BiasFieldCorrection)
- **Python 3** with json support
- **bc** calculator (for mathematical operations)

### BIDS Dataset Structure

The pipeline expects ADNI3 data in BIDS format:

```
BIDS/
├── sub-{subject}/
│   └── baseline/
│       ├── dwi/
│       │   ├── sub-{subject}_dwi.nii.gz
│       │   ├── sub-{subject}_dwi.bval
│       │   ├── sub-{subject}_dwi.bvec
│       │   └── sub-{subject}_dwi.json
│       ├── fmap/
│       │   ├── sub-{subject}_fmap_e1.nii
│       │   ├── sub-{subject}_fmap_e1.json
│       │   ├── sub-{subject}_fmap_e2.nii
│       │   ├── sub-{subject}_fmap_e2.json
│       │   └── sub-{subject}_fmap_e2_ph.nii.gz
│       └── anat/
│           └── sub-{subject}_T1w.nii.gz
```

## Usage

### Single Subject Processing

To process a single subject directly:

```bash
./ADNI3_dwi_preprocessing_job.sh sub-001 /path/to/bids baseline /path/to/derivatives
```

### Batch Processing (Recommended)

For processing multiple subjects in parallel:

1. **Configure the batch script**: Edit the configuration section in `ADNI3_dwi_preprocessing_batch.sh`:

```bash
BIDS_DIR="/path/to/your/BIDS/directory"
SESSION="baseline"
DERIVATIVES_DIR="${BIDS_DIR}/derivatives/dwi_preprocessing"
MAX_PARALLEL_JOBS=3  # Adjust based on your system
```

2. **Run the batch processing**:

```bash
./ADNI3_dwi_preprocessing_batch.sh
```

The batch script will:
- Automatically find all subjects in the BIDS directory
- Process them in parallel (up to MAX_PARALLEL_JOBS concurrent jobs)
- Handle error logging and progress tracking
- Provide a comprehensive summary upon completion
│       │   ├── sub-002_S_1261_dwi.bval
│       │   ├── sub-002_S_1261_dwi.bvec
│       │   └── sub-002_S_1261_dwi.json
│       ├── fmap/
│       │   ├── sub-002_S_1261_fmap_e1.nii.gz      # First echo magnitude
│       │   ├── sub-002_S_1261_fmap_e1.json
│       │   ├── sub-002_S_1261_fmap_e2.nii.gz      # Second echo magnitude
│       │   ├── sub-002_S_1261_fmap_e2.json
│       │   ├── sub-002_S_1261_fmap_e2_ph.nii.gz   # Phase difference
│       │   └── sub-002_S_1261_fmap_e2_ph.json
│       └── anat/
│           ├── sub-002_S_1261_T1w.nii.gz
│           └── sub-002_S_1261_T1w.json
└── code/
    ├── dwi_preprocessing_pipeline.sh
    ├── process_fieldmap.py
    ├── qc_report.py
    └── preprocessing_config.sh
```

## Usage

### Quick Start

1. **Make the script executable**:
   ```bash
   chmod +x /Users/spascual/Downloads/BIDS/code/dwi_preprocessing_pipeline.sh
   ```

2. **Run the pipeline**:
   ```bash
   cd /Users/spascual/Downloads/BIDS/code
   ./dwi_preprocessing_pipeline.sh
   ```

### Customization

1. **Edit configuration** (optional):
   ```bash
   nano preprocessing_config.sh
   ```
   
   Modify subject ID, session, or processing parameters as needed.

2. **Source configuration and run**:
   ```bash
   source preprocessing_config.sh
   ./dwi_preprocessing_pipeline.sh
   ```

### Processing Multiple Subjects

Create a batch script:
```bash
#!/bin/bash
subjects=("sub-002_S_1261" "sub-003_S_1262" "sub-004_S_1263")

for subject in "${subjects[@]}"; do
    echo "Processing $subject..."
    
    # Update subject in config
    sed -i "s/SUBJECT=.*/SUBJECT=\"$subject\"/" preprocessing_config.sh
    
    # Run pipeline
    source preprocessing_config.sh
    ./dwi_preprocessing_pipeline.sh
    
    echo "Completed $subject"
done
```

## Output Structure

```
derivatives/mrtrix/sub-002_S_1261/baseline/
├── dwi_preprocessed.mif              # Final preprocessed DWI
├── brain_mask.mif                    # Brain mask
├── bias_field.mif                    # Bias field map
├── noise_map.mif                     # Noise map from denoising
├── response_wm.txt                   # White matter response function
├── response_gm.txt                   # Gray matter response function
├── response_csf.txt                  # CSF response function
├── qc/                               # Quality control outputs
│   ├── qc_report.html               # Comprehensive QC report
│   ├── mean_b0.nii.gz               # Mean b=0 image
│   ├── mean_dwi.nii.gz              # Mean DWI image
│   ├── signal_comparison.png         # Signal comparison plots
│   ├── motion_parameters.png         # Motion parameter plots
│   ├── fieldmap_qc.png              # Fieldmap quality assessment
│   └── *_mosaic.png                 # Mosaic images for each step
└── work/                            # Intermediate files (optional cleanup)
```

## Quality Control

### Automated QC Report

The pipeline generates a comprehensive HTML QC report including:
- Signal comparisons across processing steps
- Motion parameter plots
- Fieldmap quality assessment
- Mosaic images for visual inspection

Open the QC report:
```bash
open derivatives/mrtrix/sub-002_S_1261/baseline/qc/qc_report.html
```

### Manual QC Checklist

1. **Motion Parameters**: Check for excessive head movement
   - Translation: < 3mm recommended
   - Rotation: < 3 degrees recommended

2. **Fieldmap Quality**: 
   - Smooth spatial variation expected
   - Range typically -200 to +200 Hz
   - No obvious unwrapping errors

3. **Denoising Results**:
   - Signal preservation in anatomical structures
   - Noise reduction in background

4. **Final Data Quality**:
   - No obvious artifacts
   - Good brain extraction
   - Consistent signal across volumes

## Troubleshooting

### Common Issues

1. **"Command not found" errors**:
   - Ensure MRtrix3, FSL, and ANTs are installed and in PATH
   - Check software versions

2. **Phase unwrapping failures**:
   - The pipeline will fall back to scipy unwrapping if FSL PRELUDE fails
   - Check fieldmap data quality

3. **Memory issues**:
   - Reduce number of threads in config
   - Increase swap space if needed

4. **Missing files**:
   - Verify BIDS structure
   - Check file naming conventions

### Performance Optimization

1. **Parallel processing**:
   - Set `NTHREADS` in config to number of available cores
   - Monitor memory usage

2. **Storage**:
   - Use fast SSD storage for working directory
   - Consider cleanup of intermediate files

## Advanced Usage

### Custom Processing Parameters

Edit `preprocessing_config.sh` for:
- Different denoising algorithms
- Modified eddy parameters
- Alternative bias correction methods
- Custom brain extraction parameters

### Integration with Other Pipelines

The preprocessed data is compatible with:
- **Tractography**: Use response functions for CSD
- **Connectome analysis**: Import to MRtrix3 or other tools
- **DTI analysis**: Convert to FSL format if needed

### Converting to Other Formats

```bash
# Convert to NIfTI format
mrconvert dwi_preprocessed.mif dwi_preprocessed.nii.gz -export_grad_fsl bvecs bvals

# Convert to FSL format
mrconvert dwi_preprocessed.mif dwi_preprocessed.nii.gz -fslgrad bvecs bvals
```

## References

1. Tournier, J.-D., et al. (2019). MRtrix3: A fast, flexible and open software framework for medical image processing and visualisation. NeuroImage, 202, 116137.

2. Andersson, J. L., & Sotiropoulos, S. N. (2016). An integrated approach to correction for off-resonance effects and subject movement in diffusion MR imaging. NeuroImage, 125, 1063-1078.

3. Veraart, J., et al. (2016). Denoising of diffusion MRI using random matrix theory. NeuroImage, 142, 394-406.

4. Kellner, E., et al. (2016). Gibbs-ringing artifact removal based on local subvoxel-shifts. Magnetic Resonance in Medicine, 76(5), 1574-1581.

## Support

For issues specific to this pipeline, check:
1. Log files in the work directory
2. QC report for data quality issues
3. MRtrix3 documentation: https://mrtrix.readthedocs.io/
4. FSL documentation: https://fsl.fmrib.ox.ac.uk/fsl/fslwiki/
