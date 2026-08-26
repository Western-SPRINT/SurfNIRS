function ButtonLeftPushed(app, ~)
    app.SessionInfo.Navigation.NavigateLeft();
    focus(app.SurfNIRSUIFigure);
end