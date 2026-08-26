classdef Draw < handle
    % Manages figures/plots
    
    properties (SetAccess = private, GetAccess = public)
        ChannelsToHide = table(Size=[0 2],VariableNames=["source" "detector"],VariableTypes=["double" "double"])
        Submodules
        DatatypeColours = [0 0 0]
        SessionInfo
        Interaction = true
        HighlightedChannel = nan;
    end

    properties ( Dependent )
        DataToDraw
        ChannelsToDraw
    end
    
    methods
        function obj = Draw(session)
            arguments
                session (1,1) SurfNIRS.SessionInfo
            end
            obj.SessionInfo = session;
            obj.Submodules = [SurfNIRS.modules.DrawAxesMain(obj);
                                SurfNIRS.modules.DrawAxesMontage(obj);
                                SurfNIRS.modules.DrawAxesAutocorr(obj);
                                SurfNIRS.modules.DrawAxesFourier(obj);
                                SurfNIRS.modules.DrawAxesCorrMat(obj)]';
            for sm = obj.Submodules
                disableDefaultInteractivity(sm.Axes);
            end
            set(obj.SessionInfo.app.SurfNIRSUIFigure, WindowButtonMotionFcn=@obj.CursorMovement);
            set(obj.SessionInfo.app.SurfNIRSUIFigure, WindowButtonDownFcn=@obj.CursorClick);
        end

        function Update_DataHasChanged(obj)
            % nothing will be highlighted yet
            obj.HighlightedChannel = nan;

            if ~isempty(obj.SessionInfo.Data.SelectedData)
                % displaying data...

                % title
                obj.SessionInfo.app.LabelTitle.Text = obj.SessionInfo.Data.SelectedData.label;
                obj.SessionInfo.app.LabelTitle.Position(3) = obj.SessionInfo.app.UIAxes_Main.Position(3);

                % update datatype colours
                obj.UpdateDatatypeColours();

                % update all submodules
                for sm = obj.Submodules
                    sm.DataHasChanged();
                end
                
            else
                % no data displayed...

                % title
                obj.SessionInfo.app.LabelTitle.Text = "No dataset loaded...";

                % clear all submodules
                for sm = obj.Submodules
                    sm.Clear;
                end
            end
        end

        function Update_ChannelsHaveChanged(obj)
            if ~isempty(obj.SessionInfo.Data.SelectedData)
                % update all submodules
                for sm = obj.Submodules
                    sm.ChannelsHaveChanged();
                end
            end
        end

        function CursorMovement(obj,fig,~)
            if obj.SessionInfo.app.InteractiveHighlightMenu.Checked %obj.Interaction
                cursor_element = hittest(fig);
                for sm = obj.Submodules
                    if isempty(sm.Lines)
                        continue
                    end

                    if cursor_element == sm.Axes
                        pos = get(sm.Axes, 'CurrentPoint');
                        x = pos(1,1);
                        y = pos(1,2);

                        if cursor_element == obj.SessionInfo.app.UIAxes_Montage
                            % use more precise check for montage
                            xs = [sm.Lines.XData];
                            xs = [xs; mean(xs,1)];
                            ys = [sm.Lines.YData];
                            ys = [ys; mean(ys,1)];
                            
                            dx = abs(xs - x);
                            dy = abs(ys - y);
                            d = sqrt( dx.^2 + dy.^2 );
                            d = min(d,[],1);
                        else
                            % find x match
                            [~,ind] = min(abs(sm.XData - x));
                            inds = find(sm.XData == sm.XData(ind));
    
                            % find closest y
                            d = abs(sm.YData(inds,:) - y);
                            d = min(d,[],1);
                        end

                        % select closest line
                        [md,line_ind] = min(d);
                        if md > range(sm.Axes.YLim)*0.1
                            for sm = obj.Submodules
                                sm.RemoveHighlight(obj.HighlightedChannel);
                            end
                            return
                        end

                        % found a line?
                        if ~isempty(line_ind)
                            % which channel?
                            channel = sm.ChannelsToDraw(line_ind);

                            % already highlighted?
                            if channel == obj.HighlightedChannel
                                return
                            end
                            
                            % set highlights
                            for sm = obj.Submodules
                                sm.RemoveHighlight(obj.HighlightedChannel);
                                sm.ApplyHighlight(channel);
                            end

                            % store current highlight
                            obj.HighlightedChannel = channel;

                            % done
                            return
                        end
                    end
                end
                for sm = obj.Submodules
                    sm.RemoveHighlight(obj.HighlightedChannel);
                end
            end
        end

        function CursorClick(obj, ~, evt)
            if ~isnan(obj.HighlightedChannel) && strcmp(obj.SessionInfo.app.SurfNIRSUIFigure.SelectionType, "alt") %&& hittest(fig) == obj.Axes

                SD = obj.DataToDraw.channels(obj.HighlightedChannel, ["source" "detector"]);

                % toggle this channel
                if any( (SD.source == obj.ChannelsToHide.source) & (SD.detector == obj.ChannelsToHide.detector) )
                    % re-enable
                    obj.EnableChannels(SD);
                else
                    % disable
                    obj.DisableChannels(SD);
                end
            end
        end

        function data = get.DataToDraw(obj)
            data = obj.SessionInfo.Data.SelectedData;
        end
        function inds = get.ChannelsToDraw(obj)
            inds = find(arrayfun(@(s,d) ~any(obj.ChannelsToHide.source==s & obj.ChannelsToHide.detector==d), obj.SessionInfo.Data.SelectedData.channels.source, obj.SessionInfo.Data.SelectedData.channels.detector));
        end

        function EnableChannels(obj, SD_pairs)
            obj.ChannelsToHide = setdiff(obj.ChannelsToHide, SD_pairs);
            obj.Update_ChannelsHaveChanged();
        end

        function DisableChannels(obj, SD_pairs)
            obj.ChannelsToHide = unique(union(obj.ChannelsToHide, SD_pairs), "rows");
            obj.Update_ChannelsHaveChanged();
        end
        
    end

    methods ( Access = private )
        function UpdateDatatypeColours(obj)
            obj.DatatypeColours = lines(obj.DataToDraw.datatypes_count);
            for dt = ["HbO" "HbR" "HbT"]
                ind = find(strcmpi(obj.DataToDraw.datatypes,dt));
                if ~isempty(ind)
                    switch dt
                        case "HbO"
                            obj.DatatypeColours(ind, :) = [0.8500    0.3250    0.0980];
                        case "HbR"
                            obj.DatatypeColours(ind, :) = [0    0.4470    0.7410];
                        case "HbT"
                            obj.DatatypeColours(ind, :) = [0 0.5 0];
                        otherwise
                            error
                    end
                end
            end
        end
    end
end

