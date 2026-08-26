function startup(app)
    %% Start app?
    if ~nargin
        SurfNIRS
        return
    end

    %% Check Toolboxes
    if ~SurfNIRS.misc.check_AnalyzIR
        app.AnalyzIRMenu.Enable = "off";
        app.AnalyzIRMenu.Tooltip = "AnalyzIR was not found on the path";
        warning("AnalyzIR is not currently on the path. Importing AnalyzIR data will be disabled.")
    end

    if ~SurfNIRS.misc.check_Homer3
        app.Homer3Menu.Enable = "off";
        app.Homer3Menu.Tooltip = "Homer3 was not found on the path";
        warning("Homer3 is not currently on the path. Importing Homer3 data will be disabled.")
    end

    %app.SurfNIRSUIFigure.Position = app.SurfNIRSUIFigure.Position - [1920 0 0 0];

    %% Clear Persistent groupResults
    clear Load_Homer3_groupResults

    %% Change Theme For New MATLAB
    if isprop(app.SurfNIRSUIFigure, "Theme")
        app.SurfNIRSUIFigure.Theme = "light";
        app.UIAxes_Montage.Color = [1 1 1];
    end

    %% Fix Sizing on Smaller Screens
    sz = get(0,'ScreenSize');
    if sz(3)<app.SurfNIRSUIFigure.Position(3) || sz(4)<app.SurfNIRSUIFigure.Position(4)
        drawnow %needs to draw at native size first for resize to work
        app.FullscreenModeMenu.Checked = "on";
        app.SurfNIRSUIFigure.WindowState = "fullscreen";
    end
    drawnow

    %% First Draw
    app.SessionInfo.Draw.Update_DataHasChanged();

    %% Display Version
    app.SurfNIRSUIFigure.Name = sprintf("SurfNIRS version %.1f", app.Version);

    %% Debug / Testing
    if app.Debug
        % share app object to workspace
        assignin("base","app",app)
        
        % display debug reminder
        uilabel(app.SurfNIRSUIFigure, Text="DEBUG ENABLED", FontSize=40, FontColor="r", Position=[700 850 400 100], HorizontalAlignment="center");

        % load test data
        app.SessionInfo.Data.ImportBIDS_AnalyzIR_nirs_core_Data("D:\OneDrive\OneDrive - The University of Western Ontario\Brian\Data\CONTROL BIDS")
        % app.SessionInfo.Data.ImportBIDS_AnalyzIR_nirs_core_Data(string(pwd) + filesep + "Data_AnalyzIR");
        app.SessionInfo.Navigation.Refresh;
%         app.SessionInfo.Draw.DisableChannels(app.SessionInfo.Data.SelectedData.channels(:,["source" "detector"]));
%         SD = [13 14; 12 14; 12 13; 11 11; 10 11; 10 10; 9 8; 8 8; 8 7];
%         SD = array2table(SD,VariableNames=["source" "detector"]);
%         app.SessionInfo.Draw.EnableChannels(SD);

        % move to secondary monitor
%         app.SurfNIRSUIFigure.Position = app.SurfNIRSUIFigure.Position - [1920 0 0 0];
    end

% app.SessionInfo.Data.ImportBIDS_AnalyzIR_nirs_core_Data("H:\OneDrive - The University of Western Ontario\Brian\March_2025\2025-04-01_TDDR\BIDS");
% app.SessionInfo.Navigation.Refresh;

end