# Load necessary libraries
library(oro.nifti)
library(dplyr)
library(readr)
library(ggseg)
library(ggplot2)
library(ggseg3d)
library(ggsegBrainnetome)

# Define paths
git_dir <- '/Users/spascual/git/saulpascualdiaz/neuroimaging_pipelines'
t_map_path <- '/Volumes/working_disk_blue/SPRINT_MPS/bids_derivatives/SPM_firstlevels/sub-1003/ses-baseline/spmT_0001.nii'
atlas_path <- paste(git_dir, '/dependences/atlas/BN_Atlas_246_2mm.nii.gz', sep='')
labels_path <- paste(git_dir, '/dependences/dataframes/brainnetome_annot.csv', sep='')

# Load the atlas
atlas <- readNIfTI(atlas_path)

# Load the ROI labels from the CSV file
roi_labels <- read_csv(labels_path)

# Load the T map (or other brain measure)
t_map <- readNIfTI(t_map_path)

# Initialize a dataframe to store the results
results <- data.frame()

# Loop through each ROI defined in the ROI labels
for (roi in roi_labels$roi) {
  # Convert ROI to numeric for comparison if necessary
  roi_numeric <- as.numeric(roi)
  
  roi_mask <- atlas == roi_numeric
  roi_values <- t_map[roi_mask]
  
  # Calculate the mean value for this ROI
  roi_mean <- if (length(roi_values) > 0) mean(roi_values, na.rm = TRUE) else NA
  
  # Append the result to the results dataframe
  results <- rbind(results, data.frame(
    roi = roi,
    label = roi_labels$annot[roi_labels$roi == roi],
    measure = roi_mean
  ))
}

# Convert results to tibble and merge with brainnetome data
in_data <- tibble(
  annot = results$label,
  measure = results$measure
)

merged_data <- brainnetome$data %>%
  as_tibble() %>%
  left_join(in_data, by = "annot")

# Plot the results
ggplot(merged_data) +
  geom_brain(atlas = brainnetome, mapping = aes(fill = measure)) +
  scale_fill_gradient(low = "blue", high = "red", limits = c(-20, 25)) +
  ggtitle("Brain Regions with Calculated Measures (Brainnetome)")
