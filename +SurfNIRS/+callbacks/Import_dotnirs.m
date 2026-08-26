function Import_dotnirs(app, ~)
    % select files
    [file,folder] = uigetfile(["*.nirs", ".nirs"], "Import .nirs File(s)", app.SessionInfo.LastImportFolder,  MultiSelect="off");
    focus(app.SurfNIRSUIFigure);

    % stop if no files
    if isnumeric(folder)
        return
    end

    % set latest folder
    app.SessionInfo.SetLastImportFolder(folder);

    % convert to string
    filepaths = arrayfun(@(f) folder + f, string(file));

    % load
    count = app.SessionInfo.Data.ImportMulti_dotnirs(filepaths);
    if ~count
        errordlg("No new valid files were found","Import Failed");
    else
        app.SessionInfo.Navigation.Refresh;
    end
end