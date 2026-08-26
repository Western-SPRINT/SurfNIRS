classdef DrawAxesCorrMat < SurfNIRS.modules.DrawAxesTemplate
    % Handles drawing of the correlation matrix

    methods
        function obj = DrawAxesCorrMat(draw)
            obj@SurfNIRS.modules.DrawAxesTemplate(draw);

            % colormap
            cp = [0.8 0.1 0.1];
            c0 = [0.5 0.5 0.5];
            cn = [0.1 0.1 0.8];
            n = 50;
            cmap = [cell2mat(arrayfun(@(a,b) linspace(a,b,n)', cn, c0, 'UniformOutput', false));
                            cell2mat(arrayfun(@(a,b) linspace(a,b,n)', c0, cp, 'UniformOutput', false))];
            colormap(obj.Axes, cmap)
        end

        function DataHasChanged(obj)
            obj.DrawMatrix();
        end

        function ChannelsHaveChanged(obj)
            obj.DrawMatrix();
        end

        function Clear(obj)
            cla(obj.Axes);
            set(obj.Axes, xtick=[], ytick=[]);
        end
    end

    methods ( Access = protected )
        function InitAxes(obj)
            obj.Axes = obj.Draw.SessionInfo.app.UIAxes_CorrMat;
        end

        function SetLineData(obj, line, channel, line_index)
        end

        function PostDraw(obj)
        end

        function [xl,yl] = GetLimits(obj)
            xl = nan(1,2);
            yl = nan(1,2);
        end

        function DrawMatrix(obj)
            select = arrayfun(@(c) any(c == obj.ChannelsToDraw), obj.DataToDraw.corrmat_channels);
            count = sum(select);

            if ~count
                cla(obj.Axes)
                return
            end

            rowcol_datatypes = obj.DataToDraw.corrmat_datatypes(select);
            mat = obj.DataToDraw.corrmat_values(select,select);

            lims = [0 count] + 0.5;
            dt_first = arrayfun(@(dt) find(rowcol_datatypes==dt,1,"first"), 1:obj.DataToDraw.datatypes_count);
            
            imagesc(obj.Axes, mat);
            hold(obj.Axes, "on")
                for dt = 1:obj.DataToDraw.datatypes_count
                    plot(obj.Axes, lims, dt_first([dt dt])-0.5, "k-")
                    plot(obj.Axes, dt_first([dt dt])-0.5, lims, "k-")
                end
            hold(obj.Axes, "off")

            clim(obj.Axes, [-1 +1])
            colorbar(obj.Axes)

            set(obj.Axes, XTick=dt_first, XTickLabels=obj.DataToDraw.datatypes, YTick=dt_first, YTickLabels=obj.DataToDraw.datatypes, XAxisLocation="top")

            axis(obj.Axes, "square")

            xlim(obj.Axes, lims)
            ylim(obj.Axes, lims)

            title(obj.Axes, "Correlations")
        end
    end


end