classdef DrawAxesAutocorr < SurfNIRS.modules.DrawAxesTemplate
    % Handles drawing of the temporal autocorr axes
    
    properties ( Access = private )
        zero_line = [];
    end
    
    methods
        function obj = DrawAxesAutocorr(draw)
            obj@SurfNIRS.modules.DrawAxesTemplate(draw);
        end
    end

    methods ( Access = protected )
        function InitAxes(obj)
            obj.Axes = obj.Draw.SessionInfo.app.UIAxes_Autocorr;
        end

        function SetLineData(obj, line, channel, line_index)
            xs = [];
            ys = [];
            colour_inds = [];
            for dt = obj.DataToDraw.datatypes_count : -1 : 1
                xs = [xs obj.DataToDraw.autocorr_lag_times nan;];
                ys = [ys obj.DataToDraw.channels.autocorr{channel}(:,dt)' nan];
                colour_inds = [colour_inds ones(1,length(obj.DataToDraw.autocorr_lag_times)+1)*dt];
            end
            set(line,XData=xs,YData=ys,CData=colour_inds,EdgeAlpha=(1/(obj.DataToDraw.datatypes_count)));% * obj.DataToDraw.channels_count / 10)));
        end

        function PostDraw(obj)
            xlabel(obj.Axes, "Lag (sec)")
%             ylabel(obj.Axes, "Correlation")
            title(obj.Axes, "Temporal Autocorrelation")
            xticks(obj.Axes,"auto")
            set(obj.Axes, YTick=(-1 : 0.2 : +1));
        end

        function [xl,yl] = GetLimits(obj)
            xl = [0 ceil(obj.DataToDraw.autocorr_lag_times(end))];
            yl = [min(cellfun(@(xc) min(xc(:)), obj.DataToDraw.channels.autocorr)) 1];
        end

        function DrawBackground(obj)
            [xl,~] = GetLimits(obj);
            hold(obj.Axes, "on")
            obj.zero_line = plot(obj.Axes, xl, [0 0], "k-");
            hold(obj.Axes, "off")
        end

        function ClearBackground(obj)
            delete(obj.zero_line)
            obj.zero_line = [];
        end
    end
end

