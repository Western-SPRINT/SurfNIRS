function ButtonUpPushed(app, ~)
    app.SessionInfo.Navigation.NavigateUp();
    focus(app.SurfNIRSUIFigure);
end