function DisableAllButtonPushed(app)
    app.SessionInfo.Draw.DisableChannels(app.SessionInfo.Data.SelectedData.channels(:,["source" "detector"]));
end