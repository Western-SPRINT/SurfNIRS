classdef DrawAxesMontage < SurfNIRS.modules.DrawAxesTemplate
    % Handling drawing of the montage axes
    
    properties ( Access = private)
        SD_lines = [];
        SD_text = [];
        marker_size = 4;
        draw_labels = true;
        font_size = 10;
    end
    
    methods
        function obj = DrawAxesMontage(draw)
            obj@SurfNIRS.modules.DrawAxesTemplate(draw);
            obj.line_width_default = 2;
            obj.line_width_highlight = 5;
            obj.Axes.Color = draw.SessionInfo.app.SurfNIRSUIFigure.Color;
            obj.Axes.XAxis.Color = draw.SessionInfo.app.SurfNIRSUIFigure.Color;
            obj.Axes.YAxis.Color = draw.SessionInfo.app.SurfNIRSUIFigure.Color;
        end
    end
    
    
    methods ( Access = protected )
        function InitAxes(obj)
            obj.Axes = obj.Draw.SessionInfo.app.UIAxes_Montage;
        end

        function SetLineData(obj, line, channel, line_index)
            source = obj.DataToDraw.channels.source(channel);
            detector = obj.DataToDraw.channels.detector(channel);

            line.XData = [obj.DataToDraw.sources.x(source) obj.DataToDraw.detectors.x(detector)];
            line.YData = [obj.DataToDraw.sources.y(source) obj.DataToDraw.detectors.y(detector)];

            SD = obj.DataToDraw.channels(channel, ["source" "detector"]);
            if any( (SD.source == obj.Draw.ChannelsToHide.source) & (SD.detector == obj.Draw.ChannelsToHide.detector) )
                line.EdgeColor = [0.8 0.8 0.8];
            else
                line.EdgeColor = [0 0 0];
            end
        end

        function PostDraw(obj)
            axis(obj.Axes, "equal")
            set(obj.Axes, XTick=[],YTick=[])
%             axis(obj.Axes, "off")
        end

        function [xl,yl] = GetLimits(obj)
            xl = [min(obj.DataToDraw.sources.x) max(obj.DataToDraw.sources.x)] + ( [-1 +1] * range(obj.DataToDraw.sources.x) * .1);
            yl = [min(obj.DataToDraw.sources.y) max(obj.DataToDraw.sources.y)] + ( [-1 +1] * range(obj.DataToDraw.sources.y) * .1);
        end

        function DrawBackground(obj)
            hold(obj.Axes, "on")

            [xl,yl] = GetLimits(obj);
            offset = max([xl yl]) * 0.03;

            % draw sources
            colour = [0.7 0.1 0.1];
            obj.SD_lines(1) = plot(obj.Axes, obj.DataToDraw.sources.x, obj.DataToDraw.sources.y, 'o', MarkerEdgeColor=colour, MarkerFaceColor=colour, MarkerSize=obj.marker_size);
            % draw detectors
            colour = [0.1 0.1 0.8];
            obj.SD_lines(2) = plot(obj.Axes, obj.DataToDraw.detectors.x, obj.DataToDraw.detectors.y, 'o', MarkerEdgeColor=colour, MarkerFaceColor=colour, MarkerSize=obj.marker_size);

            % draw labels?
            if obj.draw_labels
                source_labels = gobjects(1, height(obj.DataToDraw.sources));
                for s = 1:height(obj.DataToDraw.sources)
                    source_labels(s) = text(obj.Axes, obj.DataToDraw.sources.x(s)+offset, obj.DataToDraw.sources.y(s)+offset, obj.DataToDraw.sources.label(s), Color=colour, FontSize=obj.font_size);
                end
                
                detector_labels = gobjects(1, height(obj.DataToDraw.detectors));
                for d = 1:height(obj.DataToDraw.detectors)
                    detector_labels(d) = text(obj.Axes, obj.DataToDraw.detectors.x(d)+offset, obj.DataToDraw.detectors.y(d)+offset, obj.DataToDraw.detectors.label(d), Color=colour, FontSize=obj.font_size);
                end

                obj.SD_text = [source_labels detector_labels];
            end

            hold(obj.Axes, "off")
        end

        function ClearBackground(obj)
            delete(obj.SD_lines)
            obj.SD_lines = [];

            delete(obj.SD_text)
            obj.SD_text = [];
        end

        function inds = GetChannelsToDraw(obj)
            % always draw all channels
            inds = 1:height(obj.DataToDraw.channels);
        end
    end
end

