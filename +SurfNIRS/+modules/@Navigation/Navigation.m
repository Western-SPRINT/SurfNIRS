classdef Navigation < handle
    % Updates navigation panel and handles navigating
    
    properties
        
    end

    properties ( Access = private )
        SessionInfo
        Nodes
    end

    properties ( Dependent, Access = private )
        Data
        Panel
    end
    
    methods
        function obj = Navigation(session)
            arguments
                session (1,1) SurfNIRS.SessionInfo
            end
            obj.SessionInfo = session;
        end

        function data = get.Data(obj)
            data = obj.SessionInfo.Data;
        end

        function panel = get.Panel(obj)
            panel = obj.SessionInfo.app.Tree;
        end

        function NavigateLeft(obj)
            % prior file with same processing step
            ind_current = find(obj.Data.List.ID_full == obj.Data.SelectedID);
            options = find( obj.Data.List.step == obj.Data.List.step(ind_current) );
            ind_select = options(find(options<ind_current, 1, "last"));
            if isempty(ind_select)
                ind_select = options(end);
            end
            obj.NavigateToID(obj.Data.List.ID_full(ind_select));
        end
        function NavigateRight(obj)
            % next file with same processing step
            ind_current = find(obj.Data.List.ID_full == obj.Data.SelectedID);
            options = find( obj.Data.List.step == obj.Data.List.step(ind_current) );
            ind_select = options(find(options>ind_current, 1, "first"));
            if isempty(ind_select)
                ind_select = options(1);
            end
            obj.NavigateToID(obj.Data.List.ID_full(ind_select));
        end
        function NavigateUp(obj)
            % prior in run
            ind_current = find(obj.Data.List.ID_full == obj.Data.SelectedID);
            options = find( obj.Data.List.ID_acquisition == obj.Data.List.ID_acquisition(ind_current) );
            ind_select = options(find(options<ind_current, 1, "last"));
            if isempty(ind_select)
                ind_select = options(end);
            end
            obj.NavigateToID(obj.Data.List.ID_full(ind_select));
        end
        function NavigateDown(obj)
            % next in run
            ind_current = find(obj.Data.List.ID_full == obj.Data.SelectedID);
            options = find( obj.Data.List.ID_acquisition == obj.Data.List.ID_acquisition(ind_current) );
            ind_select = options(find(options>ind_current, 1, "first"));
            if isempty(ind_select)
                ind_select = options(1);
            end
            obj.NavigateToID(obj.Data.List.ID_full(ind_select));
        end

        function NavigateToID(obj, ID_full)
            % Attempts to navigate to the specified ID
            arguments
                obj (1,1) SurfNIRS.modules.Navigation
                ID_full (1,:) string {mustBeNonzeroLengthText}
            end

            % attempt to select
            [success, removed] = obj.Data.SelectByID(ID_full);

            if removed
                % if failed to load, refresh the entries
                obj.Refresh;
            elseif success
                % if success, set visuals
                obj.SetActiveNodeByID(ID_full);
                obj.SessionInfo.Draw.Update_DataHasChanged();
            end

        end

        function Refresh(obj)
            % clear
            delete(obj.Panel.Children);

            % make a selection if there isn't currently one
            if isempty(obj.Data.SelectedID)
                obj.Data.SelectFirst;
                % exhausted options?
                if isempty(obj.Data.SelectedID)
                    return
                end
                obj.SessionInfo.Draw.Update_DataHasChanged();
            end

            % which heads to show
            show_sub = length(unique(obj.Data.List.sub))~=1;
            show_task = length(unique(obj.Data.List.task))~=1;
            show_ses = length(unique(obj.Data.List.ses))~=1;
            show_run = length(unique(obj.Data.List.run))~=1;

            % populate
            node_run = obj.Panel;
            node_sub = obj.Panel;
            node_ses = obj.Panel;
            sub = "";  task = ""; ses = ""; run = "";
            obj.Nodes = gobjects([height(obj.Data.List) 1]);
            for r = 1:height(obj.Data.List)
                % add sub?
                if show_sub && obj.Data.List.sub(r) ~= sub
                    sub = obj.Data.List.sub(r);
                    node_sub = uitreenode(obj.Panel, Text=sub);
                    task = ""; ses = ""; run = "";
                    node_task=node_sub; node_ses=node_sub; node_run=node_sub;
                end

                % add task?
                if show_task && obj.Data.List.task(r) ~= task
                    task = obj.Data.List.task(r);
                    node_task = uitreenode(node_sub, Text=task);
                    ses = ""; run = "";
                    node_ses=node_task; node_run=node_task;
                end
                
                % add ses?
                if show_ses && obj.Data.List.ses(r) ~= ses
                    ses = obj.Data.List.ses(r);
                    node_ses = uitreenode(node_task, Text=ses);
                    run = "";
                    node_run=node_ses;
                end

                % add run?
                if show_run && obj.Data.List.run(r) ~= run
                    run = obj.Data.List.run(r);
                    node_run = uitreenode(node_ses, Text=run);
                end

                % add acquisition-step
                obj.Nodes(r) = uitreenode(node_run, Text=obj.Data.List.step(r), NodeData=obj.Data.List.ID_full(r));
            end

            % expand all
            expand(obj.Panel, "all")

            % apply selection
            obj.SetActiveNodeByID(obj.Data.SelectedID);
        end

    end

    methods ( Access = private ) 
        function success = SetActiveNodeByID(obj, ID_full)
            % Sets the Tree selection (visual only)
            arguments
                obj (1,1) SurfNIRS.modules.Navigation
                ID_full (1,:) string {mustBeNonzeroLengthText}
            end

            % default to fail
            success = false;

            % find
            ind = find(obj.Data.List.ID_full == ID_full);
            if length(ind) ~= 1
                return
            end
            
            % select
            obj.Panel.SelectedNodes = obj.Nodes(ind);

            % success
            success = true;
        end
    end
end

