function ClickModeToggleButtonValueChanged(app, value)
    if value
        app.ClickModeToggleButton.Text = "Click Mode: Zoom";
        zoom(app.SurfNIRSUIFigure, "on")
        focus(app.SurfNIRSUIFigure);
    else
        app.ClickModeToggleButton.Text = "Click Mode: Toggle";
        zoom(app.SurfNIRSUIFigure, "off")
        for sm = app.SessionInfo.Draw.Submodules
            disableDefaultInteractivity(sm.Axes);
        end
        focus(app.SurfNIRSUIFigure);
    end
end