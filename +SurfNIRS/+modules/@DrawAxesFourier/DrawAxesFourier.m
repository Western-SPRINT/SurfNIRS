classdef DrawAxesFourier < SurfNIRS.modules.DrawAxesTemplate
    % Handles drawing of the temporal autocorr axes
    
    properties ( GetAccess = public, SetAccess = private )
        frequency_limits = [0.05 inf];
        normalize = false;
    end
    
    methods
        function obj = DrawAxesFourier(draw)
            obj@SurfNIRS.modules.DrawAxesTemplate(draw);
        end
    end

    methods ( Access = protected )
        function InitAxes(obj)
            obj.Axes = obj.Draw.SessionInfo.app.UIAxes_Freq;
        end

        function SetLineData(obj, line, channel, line_index)
            xs = [];
            ys = [];
            colour_inds = [];
            for dt = obj.DataToDraw.datatypes_count : -1 : 1
                xs = [xs obj.DataToDraw.fourier_frequencies nan;];
                d = obj.DataToDraw.channels.fourier{channel}(:,dt)';
                if obj.normalize
                    d = d / std(d);
                end
                ys = [ys d nan];
                colour_inds = [colour_inds ones(1,length(obj.DataToDraw.fourier_frequencies)+1)*dt];
            end
            set(line,XData=xs,YData=ys,CData=colour_inds,EdgeAlpha=(1/(obj.DataToDraw.datatypes_count)));% * obj.DataToDraw.channels_count / 5)));
        end

        function PostDraw(obj)
            xlabel(obj.Axes, "Frequency (Hz)")
            ylabel(obj.Axes, "Magnitude")
            title(obj.Axes, "Fourier Transform")
            xticks(obj.Axes,"auto")
            yticks(obj.Axes,"auto")
        end

        function [xl,yl] = GetLimits(obj)
            xl = obj.frequency_limits;
            if isempty(obj.Lines)
                yl = [0 1];
            else
                y = [obj.Lines.YData];
                y = y(obj.GetFreqSelection(), :);
                yl = [0 nanmax(y(:))];
            end
        end

        function inds = GetFreqSelection(obj)
            inds = find( (obj.DataToDraw.fourier_frequencies >= obj.frequency_limits(1)) & (obj.DataToDraw.fourier_frequencies <= obj.frequency_limits(2)) ); 
        end
    end
end

