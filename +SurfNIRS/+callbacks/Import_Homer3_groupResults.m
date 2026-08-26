function Import_Homer3_groupResults(app, ~)
    % select file
    [file,folder] = uigetfile(["groupResults.mat", "MATLAB Data"], "Import Homer3 groupResults", app.SessionInfo.LastImportFolder,  MultiSelect="off");
    focus(app.SurfNIRSUIFigure);

    % stop if no files
    if isnumeric(folder)
        return
    end

    % set latest folder
    app.SessionInfo.SetLastImportFolder(folder);

    % load
    count = app.SessionInfo.Data.ImportProject_Homer3_groupResults([folder file]);
    if ~count
        errordlg("No new valid files were found","Import Failed");
    else
        app.SessionInfo.Navigation.Refresh;
    end
end