clc
clear

% Define project variables
git_dir = '/Users/spascual/git/saulpascualdiaz/neuroimaging_pipelines';
bidsFolder = '/Volumes/working_disk_blue/SPRINT_MPS/bids_data';
bidsDerivativesFolder = '/Volumes/working_disk_blue/SPRINT_MPS/bids_derivatives/MST_CONN_data'; % New derivatives folder
projectFolder = '/Volumes/working_disk_blue/SPRINT_MPS/bids_derivatives/MST_CONN_proj'; % Path for the CONN project
subjects = {'1002'}; % List of subject identifiers
task = 'multisensory'; % Task name according to the provided paths
TR = 1.5;
smoothing = 8;
addpath([git_dir '/dependences/functions']);

% Call the function with the new bidsDerivativesFolder argument
fMRI_rest_preprocessing_CONN_noanat(bidsFolder, bidsDerivativesFolder, ...
    projectFolder, subjects, task, TR, smoothing);
