function spm_coregister_parcellation(reference, moving_img, parcellation)
    % Display the inputs for debugging
    disp('Inputs:');
    disp(reference);
    disp(moving_img);
    disp(parcellation);

    % Initialize SPM
    spm('Defaults','FMRI');
    spm_jobman('initcfg');
    matlabbatch{1}.spm.spatial.coreg.estimate.ref = {reference};
    matlabbatch{1}.spm.spatial.coreg.estimate.source = {moving_img};
    matlabbatch{1}.spm.spatial.coreg.estimate.other = {parcellation};
    matlabbatch{1}.spm.spatial.coreg.estimate.eoptions.cost_fun = 'nmi';
    matlabbatch{1}.spm.spatial.coreg.estimate.eoptions.sep = [4 2];
    matlabbatch{1}.spm.spatial.coreg.estimate.eoptions.tol = [0.02 0.02 0.02 0.001 0.001 0.001 0.01 0.01 0.01 0.001 0.001 0.001];
    matlabbatch{1}.spm.spatial.coreg.estimate.eoptions.fwhm = [7 7];
    % Execute the batch job
    spm_jobman('run', matlabbatch);
    disp('SPM Coregister Function Completed');
end
