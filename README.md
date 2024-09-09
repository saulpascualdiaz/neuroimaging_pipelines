# Neuroimaging Pipelines

Welcome to the `neuroimaging_pipelines` repository! This repository contains scripts and tools for processing and analyzing neuroimaging data, with a focus on diffusion-weighted imaging (DWI) pipelines.

## Contents

1. [Preprocessing Pipeline](#preprocessing-pipeline)
2. [Tractography and Segmentation](#tractography-and-segmentation)
3. [DTI Metrics Calculation](#dti-metrics-calculation)
4. [Usage](#usage)
5. [Dependencies](#dependencies)

## Preprocessing Pipeline

The `dwi_preprocessing_appa_pipeline.sh` script is used for preprocessing diffusion-weighted imaging (DWI) data. This script assumes the data is in BIDS format and performs the following steps:

- **Correction**: Applies corrections for diffusion data.
- **Output**: Generates preprocessed DWI images and associated files in BIDS format.

### Script Usage

```bash
./dwi_preprocessing_appa_pipeline.sh
```

**Input**: Raw DWI data in BIDS format.

**Output**: Preprocessed DWI images with filenames ending in `_dir-AP_dwi_corr.nii.gz`.

## Tractography and Segmentation

The `tractseg_pipeline.sh` script handles tractography and tract segmentation. It uses TractSeg to segment tracts and compute tract profiles. The script processes each subject's data as follows:

1. **Tract Segmentation**: Segments the tracts using TractSeg.
2. **Endings Segmentation**: Segments tract endings.

### Script Usage

```bash
./tractseg_pipeline.sh
```

**Input**: Preprocessed DWI images and associated files.

**Output**: Tract segmentation and endings segmentation results in the `DWI_tractseg` directory.

## DTI Metrics Calculation

The `dti_metrics_calculation.sh` script computes DTI-derived maps from preprocessed DWI data. It calculates the following metrics:

- **Fractional Anisotropy (FA)**
- **Mean Diffusivity (MD)**
- **Axial Diffusivity (AD)**
- **Radial Diffusivity (RD)**

The script calculates the brain mask using MRtrix3’s `dwi2mask` tool.

### Script Usage

```bash
./dti_metrics_calculation.sh
```

**Input**: Preprocessed DWI images and associated files.

**Output**: DTI-derived maps stored in the `DWI_DTI-derived_maps` directory.

## Usage

To use these scripts, clone this repository and ensure you have the necessary dependencies installed. Each script assumes a certain directory structure and file naming convention, so please adjust paths and filenames as needed.

```bash
git clone https://github.com/saulpascualdiaz/neuroimaging_pipelines.git
cd neuroimaging_pipelines
```

Run the scripts as described in the sections above.

## Dependencies

Ensure you have the following software installed:

- [MRtrix3](https://mrtrix.readthedocs.io/en/latest/)
- [TractSeg](https://github.com/Neuroanatomy/TractSeg)
- [FSL](https://fsl.fmrib.ox.ac.uk/fsl/fslwiki/FSL)
- [Python packages](https://github.com/Neuroanatomy/TractSeg#dependencies) for TractSeg

