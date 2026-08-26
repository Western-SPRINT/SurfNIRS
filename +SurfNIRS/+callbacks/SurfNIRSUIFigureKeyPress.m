function SurfNIRSUIFigureKeyPress(app, event)
    switch event.Key
        case "leftarrow"
            app.SessionInfo.Navigation.NavigateLeft();
        case "rightarrow"
            app.SessionInfo.Navigation.NavigateRight();
        case "uparrow"
            app.SessionInfo.Navigation.NavigateUp();
        case "downarrow"
            app.SessionInfo.Navigation.NavigateDown();
    end
end