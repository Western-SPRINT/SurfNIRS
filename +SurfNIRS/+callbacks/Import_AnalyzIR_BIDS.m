function Import_AnalyzIR_BIDS(app, ~)
    folder = uigetdir(app.SessionInfo.LastImportFolder, "Import AnalyzIR Folder: sub-*_ses-*_task-*_run-*_*.mat");
    focus(app.SurfNIRSUIFigure);
    if ~isnumeric(folder)
        app.SessionInfo.SetLastImportFolder(folder);
        count = app.SessionInfo.Data.ImportBIDS_AnalyzIR_nirs_core_Data(folder);
        if ~count
            errordlg("No new valid files were found","Import Failed");
        else
            app.SessionInfo.Navigation.Refresh;
        end
    end
end