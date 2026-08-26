function TreeSelectionChanged(app, event)
    focus(app.SurfNIRSUIFigure);
    % if interactable node...
    if ~isempty(event.SelectedNodes.NodeData)
        % try to select by the ID_full
        app.SessionInfo.Navigation.NavigateToID(event.SelectedNodes.NodeData);
    else
        event.Source.SelectedNodes = event.PreviousSelectedNodes;
    end
end