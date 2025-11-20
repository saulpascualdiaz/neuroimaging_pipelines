# Structure-Function Coupling in Adolescent Chronic Pain

[![Python 3.8+](https://img.shields.io/badge/python-3.8+-blue.svg)](https://www.python.org/downloads/)

**Comprehensive SC-FC coupling analysis integrating 34 communication models for clinical prediction in the SPRINT study**

## Overview

This repository implements a state-of-the-art pipeline for quantifying structure-function coupling in the adolescent brain using diffusion MRI (structural connectivity) and functional MRI (resting-state and task-based connectivity). Our approach integrates 34 distinct communication models to predict clinical outcomes in adolescents with chronic pain.

### Key Innovation

Rather than selecting a single "best" communication model, we **integrate all 34 models** using PCA-based dimensionality reduction. This captures complementary information across different neural communication mechanisms (direct anatomical pathways, polysynaptic routing, diffusion dynamics, navigation efficiency, etc.).

### Pipeline Summary

```
Structural Connectivity (dMRI) + Distance Matrix
    ↓
34 Communication Models (Esfahlani et al. 2022 benchmark)
    ↓
Local Coupling: Correlate each model with REST/TASK FC
    ↓
PCA Dimensionality Reduction: 34 models → 3 PCs per ROI
    ↓
Elastic Net Prediction: 738 features → Clinical Outcomes
    ↓
Brain Maps + Model Interpretation + Longitudinal Prediction
```

## Scientific Background

### Communication Models Framework

Brain regions communicate through structural pathways, but the relationship between anatomical connectivity and functional connectivity is complex. Different models capture different aspects:

- **Direct models** (adjacency, distance): Monosynaptic connections
- **Path-based models** (shortest path, search information): Polysynaptic routing
- **Diffusion models** (communicability): Spreading activation dynamics
- **Navigation models**: Spatial embedding and greedy routing
- **Flow models**: Dynamic information flow over time

**Key References:**
- Esfahlani et al. (2022). *A comprehensive benchmark of network communication models*. Nature Communications, 13, 1970.
- Vázquez-Rodríguez et al. (2019). *Gradients of structure-function tethering across neocortex*. PNAS, 116(42), 21219-21227.
- Xu et al. (2024). *Reconfiguration of structural and functional connectivity coupling*. JAMA Network Open, 7(3), e241933.

### Clinical Application

**Dataset:** DATASET (n=XXX adolescents with chronic pain)
- **Imaging:** SC (dMRI streamline tractography), REST FC, TASK FC
- **Atlas:** Brainnetome 246 ROIs
- **Clinical Measures:** VAR1, VAR2, VAR3
- **Longitudinal:** X timepoints over 12 months

**Goal:** Predict treatment outcomes and identify brain-based biomarkers of pain chronicity and treatment response.

## Installation

```bash
# Clone repository
git clone https://github.com/yourusername/SPRINT_coupling.git
cd SPRINT_coupling/code

# Create virtual environment
python3 -m venv venv
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt
```

## Quick Start

### Complete Pipeline (Single Command)

```bash
python run_full_pipeline.py \
    --sc-dir /Volumes/MEGADRIVE/DATASETS/SPRINT/derivatives/DWI_SCFCcoupling/mat_str \
    --rest-dir /Volumes/MEGADRIVE/DATASETS/SPRINT/derivatives/DWI_SCFCcoupling/mat_rst \
    --task-dir /Volumes/MEGADRIVE/DATASETS/SPRINT/derivatives/DWI_SCFCcoupling/mat_mst \
    --dist-file /Volumes/MEGADRIVE/DATASETS/SPRINT/derivatives/DWI_SCFCcoupling/mat_dst/distance.csv \
    --clinical-file /Volumes/MEGADRIVE/DATASETS/SPRINT/resources/dataframes/SelfReports_WideForm.sav \
    --atlas /Volumes/MEGADRIVE/DATASETS/SPRINT/resources/ROIs_atlas/BN_Atlas_246_2mm.nii \
    --n-jobs -1
```

Estimated runtime: 4-6 hours for full analysis (227 subjects)

### Step-by-Step

```bash
# 1. Compute all 34 communication models
python scripts/compute_all_34_models.py --sc-dir <path> --dist-file <path>

# 2. Calculate SC-FC coupling
python scripts/compute_coupling_all_models.py --models-dir outputs/models

# 3. PCA dimensionality reduction
python scripts/pca_per_roi.py --coupling-rest outputs/coupling/rest_coupling_all_models.npy

# 4. Clinical prediction
python scripts/clinical_prediction.py --pca-features outputs/pca/rest_pca_features.npy

# 5. Generate brain maps
python scripts/plot_brain_maps_predictive.py --coefficients outputs/prediction/coefficients_FDI.npy
```

## The 34 Communication Models

1. **Distance** - Euclidean distance (control)
2-8. **Binary models** - Path length, communicability, search info, etc.
9-20. **Weighted with gamma sweep** - Path metrics with varying costs (γ=0.25-2.0)
21-24. **Weighted single** - Communicability, MFPT, matching, cosine
25-26. **Navigation** - Greedy routing efficiency
27-34. **Flow graphs** - Time-dependent propagation (t=1-10)

See full descriptions in `COMPLETE_PIPELINE_AND_TIMELINE.txt`

## Output Structure

```
outputs/
├── models/              # 34 predictor matrices per subject
├── coupling/            # SC-FC coupling (227 × 8364)
├── pca/                 # Reduced features (227 × 246 × 3)
├── prediction/          # Models & performance metrics
└── bootstrap/           # Stability analysis

figures/
├── qa_preanalysis/      # Data quality control
├── pca/                 # Variance explained, loadings
├── brainmaps/           # Surface plots
├── prediction/          # Performance plots
└── longitudinal/        # Treatment response
```

## Documentation

- **README.md** (this file) - Quick start and overview
- **COMPLETE_PIPELINE_AND_TIMELINE.txt** - Detailed 10-week implementation plan
- **MODEL_INTEGRATION_STRATEGY.txt** - PCA methodology and justification
- **STATISTICAL_METHODS_RATIONALE.txt** - Why elastic net over PLS/RF
- **RESEARCH_SYNTHESIS_AND_ANALYSIS_PLAN.txt** - Literature review

## Expected Performance

| Outcome | Expected r | Expected R² |
|---------|-----------|-------------|
| VAR1 | 0.30-0.40 | 0.09-0.16 |
| VAR2 | 0.25-0.35 | 0.06-0.12 |
| VAR3 | 0.65-0.75 | - |

## Citation

```bibtex
@article{esfahlani2022comprehensive,
  title={A comprehensive benchmark of network communication models},
  author={Esfahlani, Farnaz S and others},
  journal={Nature Communications},
  volume={13},
  pages={1970},
  year={2022}
}

@article{xu2024reconfiguration,
  title={Reconfiguration of structural and functional connectivity coupling},
  author={Xu, Ming and others},
  journal={JAMA Network Open},
  volume={7},
  number={3},
  pages={e241933},
  year={2024}
}
```

**Version 2.0** | Last Updated: November 20, 2025
