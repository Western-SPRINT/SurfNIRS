function EnableAllButtonPushed(app)
    app.SessionInfo.Draw.EnableChannels(app.SessionInfo.Data.SelectedData.channels(:,["source" "detector"]));
end