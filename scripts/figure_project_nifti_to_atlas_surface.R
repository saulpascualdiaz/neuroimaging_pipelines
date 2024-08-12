# Load necessary libraries
# oro.nifti: For handling NIfTI file formats.
# dplyr: For data manipulation.
# readr: For reading CSV files.
# ggseg, ggplot2, ggseg3d: For visualizing brain atlas data.
# ggsegBrainnetome: For working with the Brainnetome atlas in ggseg.

library(oro.nifti)
library(dplyr)
library(readr)
library(ggseg)
library(ggplot2)
library(ggseg3d)
library(ggsegBrainnetome)

# Define paths
# git_dir: Base directory where your neuroimaging pipeline and related data are stored.
# t_map_path: Path to the T-map or other brain measure in NIfTI format.
# atlas_path: Path to the Brainnetome atlas file in NIfTI format.
# labels_path: Path to the CSV file containing ROI labels.

git_dir <- '/Users/spascual/git/saulpascualdiaz/neuroimaging_pipelines'
t_map_path <- '/Volumes/working_disk_blue/SPRINT_MPS/bids_derivatives/SPM_firstlevels/sub-1002/ses-baseline/spmT_0001.nii'
atlas_path <- paste(git_dir, '/dependences/atlas/BN_Atlas_246_2mm.nii.gz', sep='')
labels_path <- paste(git_dir, '/dependences/dataframes/brainnetome_labels.csv', sep='')

# Load the Brainnetome atlas in NIfTI format.
atlas <- readNIfTI(atlas_path)

# Load the ROI labels from the CSV file.
roi_labels <- read_csv(labels_path)

# Load the T-map (or another brain measure) in NIfTI format.
t_map <- readNIfTI(t_map_path)

# Initialize an empty dataframe to store the results of the analysis.
results <- data.frame()

# Loop through each ROI defined in the ROI labels.
# For each ROI, identify the corresponding region in the atlas,
# extract the values from the T-map, and calculate the mean value for that region.
for (roi in roi_labels$idx) {
  
  # Create a mask for the current ROI in the atlas.
  roi_mask <- atlas == roi
  
  # Extract the values from the T-map that correspond to the current ROI.
  roi_values <- t_map[roi_mask]
  
  # Calculate the mean value of the T-map within the ROI.
  # If there are no values, assign NA.
  if (length(roi_values) == 0) {
    roi_mean <- NA
  } else {
    roi_mean <- mean(roi_values, na.rm = TRUE)
  }
  
  # Append the result (ROI index, label, and mean measure) to the results dataframe.
  results <- rbind(results, data.frame(
    idx = roi,
    label = roi_labels$feature[roi_labels$idx == roi],
    measure = roi_mean
  ))
}

# Create a tibble (dataframe) for visualization.
# The 'annot' column contains ROI labels, and 'measure' contains the corresponding mean values.
in_data = tibble(
  annot = c(results$label),
  measure = c(results$measure),
)

# Join the in_data with the brainnetome atlas information.
# This step links the computed measures with the brain regions in the atlas.
brainnetome %>% 
  as_tibble() %>% 
  left_join(in_data)

# Plot the brain regions using ggplot2.
# geom_brain is used to visualize the brain atlas data, colored by the computed measures.
# The color scale ranges from blue (low values) to red (high values).
ggplot(in_data) + 
  geom_brain(atlas = brainnetome, mapping = aes(fill = measure)) + 
  scale_fill_gradient(low = "blue", high = "red", limits = c(-20, 25))
