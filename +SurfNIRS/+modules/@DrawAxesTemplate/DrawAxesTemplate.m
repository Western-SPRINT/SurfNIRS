classdef (Abstract) DrawAxesTemplate < handle & matlab.mixin.Heterogeneous
    % Abstract template for drawing submodules
    
    properties ( SetAccess = protected, GetAccess = public )
        Draw
        Axes

        Lines = [];
        LinesChannel = [];

        xlim_current = nan(1,2);
        ylim_current = nan(1,2);

        line_width_default = 1;
        line_width_highlight = 2;

        XData = []
        YData = []

        prior_transparency = 1;
    end

    properties ( Dependent, Access = public )
        DataToDraw
        ChannelsToDraw
    end
    
    methods
        function obj = DrawAxesTemplate(draw)
            obj.Draw = draw;
            obj.InitAxes();
        end
        
        function Clear(obj)
            if ~isempty(obj.Lines)
                % remove line data
                set(obj.Lines, XData=nan, YData=nan, CData=nan, LineWidth=obj.line_width_default);
    
                % set lines as available for reuse (must still have unique IDs)
                obj.LinesChannel(:) = -length(obj.LinesChannel):-1;

                % clera background
                obj.ClearBackground();

                % disable axis
                set(obj.Axes, xtick=[], ytick=[])

                % clear xy data
                obj.XData = [];
                obj.YData = [];
            end
        end

        function DataHasChanged(obj)
            % clear
            obj.Clear();

            % set colours
            obj.SetColormap();

            % draw background
            obj.DrawBackground();

            % update lines
            obj.UpdateLines();

            % set limits
            obj.UpdateLimits();

            % any post drawing (labels etc.)
            obj.PostDraw();

            % update xy data
            obj.UpdateXYData();
        end

        function ChannelsHaveChanged(obj)
            
            % clear
            obj.Clear();

            % draw background
            obj.DrawBackground();

            % update lines
            obj.UpdateLines();

            % reset default zoom
            obj.UpdateLimits();

            % any post drawing (labels etc.)
            obj.PostDraw();

            % update xy data
            obj.UpdateXYData();
        end

        function RemoveHighlight(obj, channel)
            obj.SetChannelWidth(channel, obj.line_width_default, false);
        end

        function ApplyHighlight(obj, channel)
            obj.SetChannelWidth(channel, obj.line_width_highlight, true);
        end

        function SetColormap(obj)
            colormap(obj.Axes, obj.Draw.DatatypeColours);
        end

        function data = get.DataToDraw(obj)
            data = obj.Draw.DataToDraw;
        end
        function inds = get.ChannelsToDraw(obj)
            inds = obj.GetChannelsToDraw();
        end
    end

    methods ( Abstract, Access = protected )
        InitAxes(obj) % set the Axes property and do any setup
        SetLineData(obj, line, channel, line_index) % set XData, YData, CData, and anything else
        PostDraw(obj) % labels, etc.
        [xl,yl] = GetLimits(obj)
    end

    methods ( Access = protected )
        function SetChannelWidth(obj, channel, width, bold)
            ind = find(obj.LinesChannel == channel);
            if ~isempty(ind)
                obj.Lines(ind).LineWidth = width;
                if bold
                    obj.prior_transparency = obj.Lines(ind).EdgeAlpha;
                    obj.Lines(ind).EdgeAlpha = 1;
                else
                    obj.Lines(ind).EdgeAlpha = obj.prior_transparency;
                end
            end
        end

        function UpdateLines(obj)
            % check which lines are no longer needed - will use first before making new
            channel_Lines_available = setdiff(obj.LinesChannel, obj.ChannelsToDraw);
            ind_Lines_available = arrayfun(@(c) find(obj.LinesChannel==c), channel_Lines_available);
            
            % % check which channels are new
            % ind_ChannelsToDraw_new = setdiff(ChannelsToDraw, LinesChannel);
            
            % initialize at new size, copy over
            Lines_new = gobjects(length(obj.ChannelsToDraw), 1);
            
            % loop through channels to draw...
            for cind = 1:length(obj.ChannelsToDraw)
                channel = obj.ChannelsToDraw(cind);
            
                % already drawn?
                ind = find(obj.LinesChannel == channel);
                switch length(ind)
                    case 0 % need to draw
                        % reuse existing lines first...
                        if ~isempty(ind_Lines_available)
                            Lines_new(cind) = obj.Lines(ind_Lines_available(1));
                            ind_Lines_available(1) = [];
                        else
                            % none available, need new line
                            Lines_new(cind) = patch(obj.Axes);
                        end

                        % default the width
                        Lines_new(cind).LineWidth = obj.line_width_default;

                        % use colormap
                        Lines_new(cind).EdgeColor = "flat";

                        % turn of hit tests to slightly increase speed
                        Lines_new(cind).HitTest = "off";
            
                        % do drawing
                        obj.SetLineData(Lines_new(cind), channel, cind)                    
            
                    case 1 % already drawn
                        Lines_new(cind) = obj.Lines(ind);
                        Lines_new(cind).YData = Lines_new(cind).YData - ind + cind; %update offset
                    otherwise
                        error
                end
            end
            
            %% delete any unused lines
            delete(obj.Lines(ind_Lines_available))
            
            %% keep new
            obj.Lines = Lines_new;
            obj.LinesChannel = obj.ChannelsToDraw;
        end

        function UpdateLimits(obj)
            [xl,yl] = obj.GetLimits();
            xl = xl(:)';
            yl = yl(:)';

            if length(xl)<2 || xl(1)>xl(2)
                return
            end
            if length(yl)<2 || yl(1)>yl(2)
                return
            end

            do_reset = false;

            if any(xl ~= obj.xlim_current) && range(xl) && ~any(isnan(xl))
                xlim(obj.Axes, xl)
                obj.xlim_current = xl;
                do_reset = true;
            end

            if any(yl ~= obj.ylim_current) && range(yl) && ~any(isnan(yl))
                ylim(obj.Axes, yl)
                obj.ylim_current = yl;
                do_reset = true;
            end

            if do_reset
                zoom(obj.Axes, 'reset');
            end
        end

        function inds = GetChannelsToDraw(obj)
            inds = obj.Draw.ChannelsToDraw;
        end

        function UpdateXYData(obj)
            if ~isempty(obj.Lines)
                obj.XData = obj.Lines(1).XData;
                obj.YData = [obj.Lines.YData];
            end
        end

        function ClearBackground(obj) end
        function DrawBackground(obj) end
    end

end

