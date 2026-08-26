classdef DrawAxesMain < SurfNIRS.modules.DrawAxesTemplate
    % Draw the main axes (currently only a stacked plot)

    properties (SetAccess = private, GetAccess = public)
        center = true
        normalize = true
        scale = 0.1
    end
    
    methods
        function obj = DrawAxesMain(draw)
            obj@SurfNIRS.modules.DrawAxesTemplate(draw);
            grid(obj.Axes, "on");
        end

    end

    methods ( Access = protected )
        function InitAxes(obj)
            obj.Axes = obj.Draw.SessionInfo.app.UIAxes_Main;
        end

        function SetLineData(obj, line, channel, line_index)
            xs = [];
            ys = [];
            colour_inds = [];
            for dt = obj.DataToDraw.datatypes_count : -1 : 1
                xs = [xs obj.DataToDraw.sample_times' nan;];
                d = obj.DataToDraw.channels.data{channel}(:,dt)';
                if obj.center || obj.normalize
                    d = d - mean(d);
                end
                if obj.normalize
                    d = d / std(d);
                end
                d = d * obj.scale;
                ys = [ys d nan];
                colour_inds = [colour_inds ones(1,obj.DataToDraw.samples+1)*dt];
            end
            ys = ys + line_index; %stack
            set(line,XData=xs,YData=ys,CData=colour_inds,EdgeAlpha=(1/(obj.DataToDraw.datatypes_count / 2)));
        end

        function PostDraw(obj)
            % labels
            set(obj.Axes, FontSize=12, ytick=1:length(obj.ChannelsToDraw), ...
            YTickLabel=arrayfun(@(s,d) sprintf("S%d-D%d", s, d), obj.DataToDraw.channels.source(obj.ChannelsToDraw), obj.DataToDraw.channels.detector(obj.ChannelsToDraw)));
            xlabel(obj.Axes, "Time (sec)")
            xticks(obj.Axes,"auto")
        end

        function [xl,yl] = GetLimits(obj)
            xl = obj.DataToDraw.sample_times([1 end]);

            number_channels_drawn = length(obj.ChannelsToDraw);
            buffer = ceil(number_channels_drawn / 25);
            yl = [1 number_channels_drawn] + [-buffer +buffer];
        end
    end
end

