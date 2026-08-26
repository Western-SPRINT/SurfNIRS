function Import_dotnirs_BIDS(app, ~)
    folder = uigetdir(app.SessionInfo.LastImportFolder, "Import .nirs Folder: sub-*_ses-*_task-*_run-*_*.nirs");
    focus(app.SurfNIRSUIFigure);
    if ~isnumeric(folder)
        app.SessionInfo.SetLastImportFolder(folder);
        count = app.SessionInfo.Data.ImportBIDS_dotnirs(folder);
        if ~count
            errordlg("No new valid files were found","Import Failed");
        else
            app.SessionInfo.Navigation.Refresh;
        end
    end
end