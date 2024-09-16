function fMRI_rest_preprocessing_CONN_noanat(bidsFolder, bidsDerivativesFolder, projectFolder, subjects, task, TR, smoothing)
    % Author: Saül Pascual-Diaz, Pain and Emotion Neuroscience Laboratory (PENLab), University of Barcelona
    % Version: 1.1
    % Date: 2024/07/16
    % This script assumes the BIDS (Brain Imaging Data Structure) format for organizing data.
    % For more information about BIDS, please refer to the BIDS documentation:
    % https://bids-specification.readthedocs.io/en/stable/
    % 
    % Example BIDS directory structure:
    % /Users/spascual/data/SPRINT/bids_data/
    % ├── sub-1001/
    % │   └── func/
    % │       └── sub-1001_ses-baseline_task-multisensory_bold.nii
    % ├── sub-1002/
    % │   └── func/
    % │       └── sub-1002_ses-baseline_task-multisensory_bold.nii
    % └── sub-1003/
    %     └── func/
    %         └── sub-1003_ses-baseline_task-multisensory_bold.nii
    %
    % The script preprocesses resting-state fMRI data using the CONN toolbox. 
    % It outputs the processed data to a specified derivatives folder while creating
    % symbolic links to the original functional data to avoid moving files.
    % The processed files are stored in the derivatives folder, and the original data is left untouched.

    % Initialize variables
    conn_project = fullfile(projectFolder, 'conn_project.mat'); % Save the project in the derivatives folder
    batch.filename = conn_project;
    batch.Setup.isnew = 1; % New project
    batch.Setup.nsubjects = numel(subjects);
    batch.Setup.RT = TR; % Repetition time (TR) in seconds

    % Define functional data for each subject
    for i = 1:numel(subjects)
        subjectID = subjects{i};
        subjectFolder = fullfile(bidsFolder, ['sub-', subjectID]);
        outputFolder = fullfile(bidsDerivativesFolder, ['sub-', subjectID], 'ses-baseline'); % Output folder within bids_derivatives

        if ~exist(outputFolder, 'dir')
            mkdir(outputFolder); % Create the folder if it doesn't exist
        end

        % Define functional data
        funcFiles = spm_select('FPList', fullfile(subjectFolder, 'ses-baseline', 'func'), ['^sub-', subjectID, '_ses-baseline_task-', task, '_bold\.nii$']);
        if isempty(funcFiles)
            error(['No functional data found for subject ', subjectID]);
        end

        % Create symbolic link in the output folder to the original data
        linkedFile = fullfile(outputFolder, ['sub-', subjectID, '_ses-baseline_task-', task, '_bold.nii']);
        if ~exist(linkedFile, 'file')
            % Create a symbolic link
            system(['ln -s ', funcFiles, ' ', linkedFile]);
        end

        % Use the linked file for CONN preprocessing
        batch.Setup.functionals{i}{1} = {linkedFile};
    end

    % Setup conditions (resting-state)
    batch.Setup.conditions.names = {'rest'};
    for i = 1:numel(subjects)
        batch.Setup.conditions.onsets{1}{i}{1} = 0; % start at 0 sec
        batch.Setup.conditions.durations{1}{i}{1} = inf; % last for the entire session
    end

    % Setup preprocessing steps excluding structural steps and slice timing correction
    batch.Setup.preprocessing.steps = {...
        'functional_label_as_original', ...
        'functional_realign&unwarp', ...
        'functional_center', ...
        'functional_art', ...
        'functional_segment&normalize_direct', ...
        'functional_label_as_mnispace', ...
        'functional_smooth', ...
        'functional_label_as_smoothed'};
    batch.Setup.preprocessing.fwhm = smoothing; % Smoothing kernel size

    % Log the start of preprocessing
    disp('Starting CONN preprocessing...');
    
    % Run the setup and handle errors
    try
        conn_batch(batch);
        % Save and exit
        conn save conn_project;
        disp('CONN preprocessing completed successfully.');
    catch ME
        disp('An error occurred during preprocessing:');
        disp(ME.message);
        for k = 1:length(ME.stack)
            disp(['In ', ME.stack(k).file, ' at line ', num2str(ME.stack(k).line)]);
        end
    end
end
