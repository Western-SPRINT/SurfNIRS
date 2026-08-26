function Import_AnalyzIR_mat(app, event)
    % select files
    [file,folder] = uigetfile(["*.mat", "MATLAB Data"], "Import AnalyzIR File(s)", app.SessionInfo.LastImportFolder,  MultiSelect="off");

    
    % set latest folder
    app.SessionInfo.SetLastImportFolder(folder);

    % stop if no files
    if isnumeric(folder)
        return
    end

    % convert to string
    filepaths = arrayfun(@(f) folder + f, string(file));

    % load
    count = app.SessionInfo.Data.ImportMulti_AnalyzIR_nirs_core_Data(filepaths);
    if ~count
        errordlg("No new valid files were found","Import Failed");
    else
        app.SessionInfo.Navigation.Refresh;
    end
end