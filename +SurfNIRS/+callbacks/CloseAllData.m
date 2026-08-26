function CloseAllData(app, event)
    app.SessionInfo.Data.Initialize();
    app.SessionInfo.Navigation.Refresh();
    app.SessionInfo.Draw.Update_DataHasChanged();
end