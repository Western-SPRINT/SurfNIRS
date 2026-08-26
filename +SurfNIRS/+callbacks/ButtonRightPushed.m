function ButtonRightPushed(app, ~)
    app.SessionInfo.Navigation.NavigateRight();
    focus(app.SurfNIRSUIFigure);
end