#!/usr/bin/env python3
# -*- coding: utf-8 -*-
__author__ = "Saül Pascual-Diaz"
__institution__ = "University of Barcelona"
__date__ = "2025/05/23"
__version__ = "1"
__status__ = "Stable"

import numpy as np
import nibabel as nib
from nilearn import plotting, surface, datasets
import matplotlib.pyplot as plt
from matplotlib import gridspec
import matplotlib as mpl   # <- needed for colour-map creation

# --------------------------------------------------------------------------
# 1.  Helper – blue-white-red diverging cmap (white at 0)
# --------------------------------------------------------------------------
def make_blue_white_red():
    """Return a diverging colormap (256 steps) with pure-white midpoint."""
    colors = ["#0B4B9B", "#62A5FF", "#FFFFFF", "#FF7A73", "#AA0011"]
    return mpl.colors.LinearSegmentedColormap.from_list(
        "blue_white_red", colors, N=256
    )

# --------------------------------------------------------------------------
# 2.  Main plotting function  (NO self-call inside!)
# --------------------------------------------------------------------------
def plot_brain_values(labels, values, atlas_path, lut_path,
                      deep_range=(211, 999),
                      cmap=None, title='ICCI'):
    if cmap is None:
        cmap = make_blue_white_red()          # default if none provided

    # ---------------------------------------------------------------
    # load atlas + LUT
    # ---------------------------------------------------------------
    atlas_img  = nib.load(atlas_path)
    atlas_data = atlas_img.get_fdata()
    name2id    = {}
    with open(lut_path) as f:
        for ln in f:
            parts = ln.split()
            if parts and parts[0].isdigit():
                name2id[parts[1]] = int(parts[0])

    # ---------------------------------------------------------------
    # build value volume
    # ---------------------------------------------------------------
    stat = np.zeros_like(atlas_data, dtype='float32')
    for n, v in zip(labels, values):
        rid = name2id.get(n)
        if rid is None:
            print(f'⚠  “{n}” not found in LUT – skipped.')
            continue
        stat[atlas_data == rid] = v
    stat_img = nib.Nifti1Image(stat, atlas_img.affine, atlas_img.header)

    vmin, vmax = np.nanmin(values), np.nanmax(values)

    # ---------------------------------------------------------------
    # figure layout
    # ---------------------------------------------------------------
    fig = plt.figure(figsize=(11, 10), constrained_layout=False)
    gs  = gridspec.GridSpec(2, 1, height_ratios=[3, 2], figure=fig)

    # reserve strip on left for colour-bar
    cax = fig.add_axes([0.02, 0.23, 0.02, 0.54])

    # ---------- TOP : cortical surface mosaic ----------------------
    gs_top = gridspec.GridSpecFromSubplotSpec(2, 2, subplot_spec=gs[0],
                                              wspace=0.02, hspace=0.02)
    fsavg  = datasets.fetch_surf_fsaverage('fsaverage5')
    tex_l  = surface.vol_to_surf(stat_img, fsavg.pial_left)
    tex_r  = surface.vol_to_surf(stat_img, fsavg.pial_right)

    views = [('left',  'lateral'),
             ('left',  'medial'),
             ('right', 'lateral'),
             ('right', 'medial')]
    for k, (hemi, view) in enumerate(views):
        ax  = fig.add_subplot(gs_top[k // 2, k % 2], projection='3d')
        msh = fsavg.infl_left if hemi == 'left' else fsavg.infl_right
        tex = tex_l            if hemi == 'left' else tex_r
        plotting.plot_surf_stat_map(msh, tex, hemi=hemi, view=view,
                                    cmap=cmap, vmin=vmin, vmax=vmax,
                                    colorbar=False, axes=ax)
        ax.set_title(f'{hemi.capitalize()} hemisphere ({view})',
                     fontsize=9, pad=4)
    fig.text(0.5, 0.92, 'Cortical surface', ha='center',
             fontsize=14, weight='bold')

    # ---------- BOTTOM : sub-cortical slices -----------------------
    deep_mask = (atlas_data >= deep_range[0]) & (atlas_data <= deep_range[1])
    deep_img  = nib.Nifti1Image(stat * deep_mask,
                                atlas_img.affine, atlas_img.header)
    ax_bottom = fig.add_subplot(gs[1])
    display   = plotting.plot_stat_map(deep_img, display_mode='z',
                                       cut_coords=6, draw_cross=False,
                                       cmap=cmap, vmin=vmin, vmax=vmax,
                                       axes=ax_bottom, annotate=True,
                                       colorbar=False)
    fig.text(0.5, 0.40, 'Sub-cortical axial slices', ha='center',
             fontsize=14, weight='bold')

    # ---------- shared colour-bar ----------------------------------
    sm = mpl.cm.ScalarMappable(cmap=cmap,
                               norm=mpl.colors.Normalize(vmin=vmin, vmax=vmax))
    sm.set_array([])
    cb = fig.colorbar(sm, cax=cax)
    cb.set_label(title, rotation=90, labelpad=8, fontsize=11)

    plt.tight_layout(rect=[0.06, 0, 1, 0.95])
    plt.show()

cmap = make_blue_white_red()
labels = ["A8m_L","A8m_R","A8dl_L",...]
values = [0.00422735,0.00358085,0.00401588,0.00204617,...]
atlas_path = "BN_Atlas_246_1mm.nii"
lut_path = "BN_Atlas_246_LUT.txt"
plot_brain_values(labels, values, atlas_path, lut_path)
