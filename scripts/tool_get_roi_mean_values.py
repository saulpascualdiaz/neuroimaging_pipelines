#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Compute mean voxel values inside ROI masks for a cohort.

Edit the **User Config** section, hit *Run* in Spyder, and you’ll get a
`DataFrame` (and optionally an Excel workbook) with one column per ROI.
"""

__author__ = "Saül Pascual-Diaz"
__institution__ = "University of Barcelona"
__date__ = "2025/06/12"
__version__ = "1.1"  # added robust Excel export
__status__ = "Stable"

# ################################ User Config ################################
# 1) ROI mask(s) ----------------------------------------------------------------
rois_path = [
    "/Users/spascual/data/SPRINT/bids_derivatives/PedsQL_analyses/ComBat_whole_sample/SPM_second_levels_mulreg_PedsQL_physical/peak_rACC.nii",
    "/Users/spascual/data/SPRINT/bids_derivatives/PedsQL_analyses/ComBat_whole_sample/SPM_second_levels_mulreg_PedsQL_physical/peak_dmPFC.nii",
]

# 2) Subject images -------------------------------------------------------------
# Provide your own dictionary ⇒ {SubjID: path_to_spmT_0001.nii}
# ----------------------------------------------------------------------------
# Example layout (copy‑paste and adapt):
# f_list = {
#     "1001": "/proj/sub-1001/spmT_0001.nii",
#     "1002": "/proj/sub-1002/spmT_0001.nii",
#     "1003": "/proj/sub-1003/spmT_0001.nii",
# }
# ------------------------------------------------------------------------------

# Example case
import os
proj_dir = "/Users/spascual/data/SPRINT/bids_derivatives/PedsQL_analyses/ComBat_whole_sample/SPM_firstlevels"
f_list = {
    s[4:]: os.path.join(proj_dir, s, "spmT_0001.nii")
    for s in sorted(os.listdir(proj_dir))
    if os.path.isfile(os.path.join(proj_dir, s, "spmT_0001.nii"))
}

# 3) Optional Excel output path (comment out or set to None to skip file export)
#    ⚠️  Choose a writable location (e.g. "~/roi_means.xlsx")
output_path = "~/roi_means.xlsx"

####################### DO NOT MODIFY BEYOND THIS POINT #######################

from pathlib import Path
from typing import Mapping, Sequence, Union
import nibabel as nib
import numpy as np
import pandas as pd

PathLike = Union[str, Path]

# -----------------------------------------------------------------------------
# Core helper
# -----------------------------------------------------------------------------

def create_mean_df(
    f_list: Mapping[str, PathLike],
    rois_path: Sequence[PathLike],
    output_path: PathLike | None = None,
    *,
    threshold: float = 0.0,
) -> pd.DataFrame:
    """Return a DataFrame with one column per ROI containing masked means.

    Parameters
    ----------
    f_list
        Mapping ``{SubjID: nifti_path}``.
    rois_path
        Iterable of ROI paths.  Each mask is binarised **once** with
        ``data > threshold``.
    output_path
        If provided, results are written to this Excel file. If the directory
        cannot be created (e.g. due to permissions), the file will be written
        to the current working directory instead, and a warning is printed.
    threshold
        Binarisation value (*default = 0*: include all positive voxels).
    """

    # 1) Pre‑load ROI masks once ➜ {name: bool_mask}
    roi_masks = {
        Path(p).stem: (nib.load(str(p)).get_fdata() > threshold)
        for p in rois_path
    }

    # 2) Compute mean per ROI for each subject
    records: list[dict[str, float]] = []
    for subj, img_path in f_list.items():
        print(f"Working on subject {subj}…")
        data = nib.load(str(img_path)).get_fdata()
        row = {"SubjID": subj}
        for name, mask in roi_masks.items():
            row[name] = float(data[mask].mean())
        records.append(row)

    df = pd.DataFrame.from_records(records).set_index("SubjID").sort_index()

    # 3) Optional Excel export with graceful fallback
    if output_path:
        out = Path(output_path).expanduser()
        try:
            out.parent.mkdir(parents=True, exist_ok=True)
            df.to_excel(out)
            print(f"✔ Results saved → {out}")
        except OSError as exc:
            print(
                f"⚠️  Could not write to {out.parent} ({exc}). "
                "Saving Excel to current directory instead."
            )
            fallback = Path.cwd() / out.name
            df.to_excel(fallback)
            print(f"✔ Results saved → {fallback}")

    return df

# -----------------------------------------------------------------------------
# Execute when running the file in Spyder
# -----------------------------------------------------------------------------

df_results = create_mean_df(f_list, rois_path, output_path)
print("\nPreview:\n", df_results.head())
