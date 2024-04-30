classdef SurfNIRS_exported < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        SurfNIRSUIFigure               matlab.ui.Figure
        FileMenu                       matlab.ui.container.Menu
        SaveSessionTODOMenu            matlab.ui.container.Menu
        LoadSessionTODOMenu            matlab.ui.container.Menu
        LoadDataMenu                   matlab.ui.container.Menu
        BIDSstylematContainingAnalyzIRMenu  matlab.ui.container.Menu
        ExitMenu                       matlab.ui.container.Menu
        TimeseriesMenu                 matlab.ui.container.Menu
        ViewModeMenu                   matlab.ui.container.Menu
        RawTODOMenu                    matlab.ui.container.Menu
        CenteredTODOMenu               matlab.ui.container.Menu
        StackedTODOMenu                matlab.ui.container.Menu
        MatrixTODOMenu                 matlab.ui.container.Menu
        EnableNormalizationTODOMenu    matlab.ui.container.Menu
        EnableEventDrawingTODOMenu     matlab.ui.container.Menu
        SetEventNamesTODOMenu          matlab.ui.container.Menu
        SetEventColoursTODOMenu        matlab.ui.container.Menu
        FrequencyMenu                  matlab.ui.container.Menu
        EnableNormalizationTODOMenu_2  matlab.ui.container.Menu
        SetDisplayRangeTODOMenu        matlab.ui.container.Menu
        MontageMenu                    matlab.ui.container.Menu
        ActivateAllTODOMenu            matlab.ui.container.Menu
        DeactivateAllTODOMenu          matlab.ui.container.Menu
        EnableSCIColourCodingTODOMenu  matlab.ui.container.Menu
        ApplySCIThresholdTODOMenu      matlab.ui.container.Menu
        SettingsMenu                   matlab.ui.container.Menu
        EnableHoverInteractionsTODOMenu  matlab.ui.container.Menu
        SelectDatatypestoDisplayTODOMenu  matlab.ui.container.Menu
        SetDatatypeColoursTODOMenu     matlab.ui.container.Menu
        EnableAlwaysReloadingDataTODOMenu  matlab.ui.container.Menu
        Image                          matlab.ui.control.Image
        ButtonDown                     matlab.ui.control.Button
        ButtonUp                       matlab.ui.control.Button
        ButtonRight                    matlab.ui.control.Button
        ButtonLeft                     matlab.ui.control.Button
        NavigateacrossandwithinrunsLabel  matlab.ui.control.Label
        Slider_2Label                  matlab.ui.control.Label
        DatasetsLabel                  matlab.ui.control.Label
        SurfNIRSLabel                  matlab.ui.control.Label
        Tree                           matlab.ui.container.Tree
        UIAxes_Montage                 matlab.ui.control.UIAxes
        UIAxes_Freq                    matlab.ui.control.UIAxes
        UIAxes_CorrMat                 matlab.ui.control.UIAxes
        UIAxes_Autocorr                matlab.ui.control.UIAxes
        UIAxes_Main                    matlab.ui.control.UIAxes
    end

    
    properties %(Access = private)
        DEBUG = false;

        load_recent_folder = 'D:\OneDrive - The University of Western Ontario\sfNIRS_2024\Abstract\Analyses\GRATO\BIDS'; % latest folder loaded from
        load_function = [];
        dataset_info = []; %info about the selected dataset, no actual data
        dataset_data = []; %loaded/processed data
        channel_highlighted = 0;

        BASE_STRUCT_ACQ_STEP_INFO = struct(sub=nan, ses=nan, run=nan, task="", acq=nan, step=nan, step_name="", filename="", filepath="", tree_node=nan);
        BASE_STRUCT_LOADED_DATA = struct(loaded=false, ...
                                            Fs=nan, ...
                                            time=[], ...
                                            number_samples=nan, ...
                                            source_pos=[], ...
                                            detector_pos=[], ...
                                            channels=[], ...
                                            channels_count=nan, ...
                                            datatypes=[], ...
                                            datatypes_colours=[], ...
                                            datatypes_count=nan, ...
                                            channel_datatype_signals=[], ...
                                            conditions=[], ...
                                            conditions_count=nan, ...
                                            optode_pos_min=[], ...
                                            optode_pos_max=[], ...
                                            optode_pos_range=[], ...
                                            fig_montage=[], ...
                                            fig_main=[], ...
                                            fig_autocorr=[], ...
                                            fig_freq=[]);
    end
    
    methods (Access = private)
        
        %% Defaults

        function ApplyDefaults(app)
            app.dataset_info.exclude_SD = array2table(nan(0,2),VariableNames=["source" "detector"]);
        end

        %% Loading Datasets

        function Load_fNIRSTools(app, folder_to_load)
            % select folder if not provided
            if ~exist('folder_to_load','var') || ~exist(folder_to_load,'dir')
                folder_to_load = uigetdir(app.load_recent_folder,'Select folder containing fNIRS_Tools datasets');
                if isnumeric(folder_to_load)
                    return;
                end
            end

            % find .mat files
            list = dir(fullfile(folder_to_load, '**', 'sub-*_ses-*_task-*_run-*_*.mat'));
            if isempty(list)
                errordlg('No valid datasets located: %s', folder_to_load)
                return
            end
            
            % parse BIDS info
            file_info = arrayfun(@(x) regexp(x.name, 'sub-(?<sub>\w+)_ses-(?<ses>\d+)_task-(?<task>[a-zA-Z0-9-]+)_run-(?<run>\d+)_fNIRS_(?<step>.+).mat', 'names'), list);
            file_info = struct2table(file_info);
            file_info.sub = cellfun(@str2num, file_info.sub);
            file_info.ses = cellfun(@str2num, file_info.ses);
            file_info.run = cellfun(@str2num, file_info.run);
            file_info.task = cellfun(@string, file_info.task);
            file_info.step = cellfun(@string, file_info.step);
            
            % multiple tasks is not currently supported
            if length(unique(file_info.task))>1
                error('Folders with more than one task are not currently supported')
            end
            
            % check which suffixes contain valid data, remove those that don't
            for step = unique(file_info.step)'
                % find a file with the suffix
                ind = find(file_info.step == step, 1);
            
                % load the file
                md = load([list(ind).folder filesep list(ind).name]);
            
                % find valid data field: is nirs.core.Data and numel=1
                field_is_valid_data = cellfun(@(f) isa(md.(f), 'nirs.core.Data') & numel(md.(f))==1, fields(md));
            
                % if no valid field, remove this suffix
                if ~any(field_is_valid_data)
                    ind_rm = (file_info.step == step);
                    list(ind_rm) = [];
                    file_info(ind_rm, :) = [];
                end
            end
            
            % determine order of suffix
            step_names = sort(unique(file_info.step)); %alphabetic is reasonable
            step_count = length(step_names);
            
            % sort acquisition info
            acq_info = unique(file_info(:,["sub" "ses" "run"]), 'rows');
            acq_count = height(acq_info);
            
            % populate run-step info
            acq_step_has_data = false(acq_count, step_count);
            acq_step_info = repmat(app.BASE_STRUCT_ACQ_STEP_INFO, [acq_count step_count]);
            for acq = 1:acq_count
                is_acq = ~any(~cell2mat(cellfun(@(f) file_info.(f)==acq_info.(f)(acq),acq_info.Properties.VariableNames, UniformOutput=false)),2);
                for step = 1:step_count
                    ind = find(is_acq & file_info.step==step_names(step));
                    if length(ind)>1
                        error('Unexpected duplicate found in file_info')
                    elseif isempty(ind)
                        continue
                    else
                        % add info
                        acq_step_has_data(acq,step) = true;
                        for f = ["sub" "ses" "task" "run"]
                            acq_step_info(acq,step).(f) = file_info.(f)(ind);
                        end
                        acq_step_info(acq,step).acq = acq;
                        acq_step_info(acq,step).step = step;
                        acq_step_info(acq,step).step_name = step_names(step);
                        acq_step_info(acq,step).filename = list(ind).name(1:find(list(ind).name=='.',1,'last')-1);
                        acq_step_info(acq,step).filepath = [list(ind).folder filesep list(ind).name];
                    end
                end
            end

            % success, set defaults
            app.ApplyDefaults;
            
            % success, store values
            app.dataset_info.step_names = step_names;
            app.dataset_info.step_count = step_count;
            app.dataset_info.acq_step_info = acq_step_info;
            app.dataset_info.acq_count = acq_count;
            app.dataset_info.acq_step_has_data = acq_step_has_data;
            app.InitializeDatasetData;    

            % store latest folder and the loading function to use
            app.load_recent_folder = folder_to_load;
            app.load_function = @app.Load_fNIRSTools_Dataset;

            % populate dataset tree
            app.PopulateDatasetTree
        end
        function [success] = Load_fNIRSTools_Dataset(app, acq, step)
            % default to fail
            success = false;

            % get the nirs.core.Data
            md = load(app.dataset_info.acq_step_info(acq,step).filepath);
            fs = fields(md);
            ind_data = find(cellfun(@(f) isa(md.(f), 'nirs.core.Data') & numel(md.(f))==1, fs));
            if numel(ind_data)~=1
                return
            end
            data = md.(fs{ind_data});
            clear md;

            % use regular AnalyzIR nirs.core.Data loading
            success = app.Load_Core_AnalyzIR_NIRSCoreData(acq, step, data);
        end
        
        function [success] = Load_Core_AnalyzIR_NIRSCoreData(app, acq, step, data)
            % default to fail
            success = false;

            % debug
            if app.DEBUG
                assignin('base','data',data)
            end

            % init
            app.dataset_data(acq, step) = app.BASE_STRUCT_LOADED_DATA;

            % SD positions
            app.dataset_data(acq, step).source_pos = data.probe.srcPos(:,1:2);
            app.dataset_data(acq, step).detector_pos = data.probe.detPos(:,1:2);

            % channel SD (sorted, order is used in stacked timeseries and correlation matrix)
            app.dataset_data(acq, step).channels = unique(data.probe.link(:, ["source" "detector"]), "rows");
            app.dataset_data(acq, step).channels_count = height(app.dataset_data(acq, step).channels);

            % datatypes
            app.dataset_data(acq, step).datatypes = string(data.probe.types);
            app.dataset_data(acq, step).datatypes_count = length(app.dataset_data(acq, step).datatypes);

            % timing
            app.dataset_data(acq, step).Fs = data.Fs;
            app.dataset_data(acq, step).time = data.time;
            app.dataset_data(acq, step).number_samples = length(app.dataset_data(acq, step).time);

            % organize channel-datatype signals
            app.dataset_data(acq, step).channel_datatype_signals = nan(app.dataset_data(acq, step).number_samples, ...
                                                                    app.dataset_data(acq, step).channels_count, ...
                                                                    app.dataset_data(acq, step).datatypes_count);
            type_string = string(data.probe.link.type);
            for c = 1:app.dataset_data(acq, step).channels_count
                is_channel = (data.probe.link.source==app.dataset_data(acq, step).channels.source(c)) & ...
                                (data.probe.link.detector==app.dataset_data(acq, step).channels.detector(c));
                for d = 1:app.dataset_data(acq, step).datatypes_count
                    select = is_channel & (type_string==app.dataset_data(acq, step).datatypes(d));
                    app.dataset_data(acq, step).channel_datatype_signals(:, c, d) = data.data(:, select);
                end
            end

            % events
            app.dataset_data(acq, step).conditions = table(repmat(string, [data.stimulus.count 1]), cell([data.stimulus.count 1]), cell([data.stimulus.count 1]), VariableNames=["Name" "Onsets" "Durations"]);
            app.dataset_data(acq, step).conditions_count = height(app.dataset_data(acq, step).conditions);
            for c = 1:app.dataset_data(acq, step).conditions_count
                se = data.stimulus.values{c};
                app.dataset_data(acq, step).conditions.Name(c) = se.name;
                app.dataset_data(acq, step).conditions.Onsets{c} = se.onset;
                app.dataset_data(acq, step).conditions.Durations{c} = se.dur;
            end
            colours = bone(ceil(app.dataset_data(acq, step).conditions_count*1.5));
            colours(:,4) = 0.2;
            app.dataset_data(acq, step).conditions.Colour = colours(1:app.dataset_data(acq, step).conditions_count,:);

            % success
            app.dataset_data(acq, step).loaded = true;
            success = true;
        end

        function PopulateDatasetTree(app)            
            % clear tree
            app.Tree.Children.delete;

            % skip session header to free up horizontal space?
            skip_ses = false; %~range([app.dataset_info.acq_step_info.ses]);

            % add nodes
            first_dataset = [];
            cur_sub = nan;
            cur_ses = nan;
            cur_run = nan;
            for acq = 1:app.dataset_info.acq_count
                for step = 1:app.dataset_info.step_count
                    % skip if no data
                    if ~app.dataset_info.acq_step_has_data(acq,step)
                        continue
                    end
                    
                    % add sub/ses/run
                    if cur_sub ~= app.dataset_info.acq_step_info(acq,step).sub
                        cur_sub = app.dataset_info.acq_step_info(acq,step).sub;
                        node_sub = uitreenode(app.Tree,Text=sprintf('sub-%02d',cur_sub));
                        cur_ses = nan;
                        cur_run = nan;
                    end
                    if ~skip_ses
                        if cur_ses ~= app.dataset_info.acq_step_info(acq,step).ses
                            cur_ses = app.dataset_info.acq_step_info(acq,step).ses;
                            node_ses = uitreenode(node_sub,Text=sprintf('ses-%02d',cur_ses));
                            expand(node_sub)
                            cur_run = nan;
                        end
                    end
                    if cur_run ~= app.dataset_info.acq_step_info(acq,step).run
                        if skip_ses
                            node_parent = node_sub;
                        else
                            node_parent = node_ses;
                        end

                        cur_run = app.dataset_info.acq_step_info(acq,step).run;
                        node_run = uitreenode(node_parent,Text=sprintf('run-%02d',cur_run));
                        expand(node_parent)
                    end

                    % add step
                    app.dataset_info.acq_step_info(acq, step).tree_node = uitreenode(node_run, ...
                                                                            Text=app.dataset_info.acq_step_info(acq,step).step_name, ...
                                                                            NodeData=struct(acq=acq, step=step));

                    % first?
                    if isempty(first_dataset)
                        first_dataset = app.dataset_info.acq_step_info(acq, step).tree_node;
                    end

                end
                expand(node_run)
            end

            % select first
            app.Tree.SelectedNodes = first_dataset;
            app.SelectDataset(first_dataset.NodeData.acq, first_dataset.NodeData.step);
        end
        
        function InitializeDatasetData(app)
            app.dataset_data = repmat(app.BASE_STRUCT_LOADED_DATA, [app.dataset_info.acq_count app.dataset_info.step_count]);
        end
        function [success] = Load_Dataset(app, acq, step)
            % default to fail
            success = false;

            % load
            if ~app.load_function(acq, step)
                return
            end

            % process
            if ~app.ProcessDataset(acq, step)
                return
            end

            % success
            success = true;
        end


        %% Processing Loaded Data
        
        function [success] = ProcessDataset(app, acq, step)
            % default to fail
            success = false;

            % channel names
            app.dataset_data(acq, step).fig_main.channel_names = arrayfun(@(s,d) sprintf("S%d-D%d", s,d), app.dataset_data(acq, step).channels.source, app.dataset_data(acq, step).channels.detector);

            % calculate XY limits of optodes
            app.dataset_data(acq, step).optode_pos_min = nanmin([app.dataset_data(acq, step).source_pos; app.dataset_data(acq, step).detector_pos], [], 1);
            app.dataset_data(acq, step).optode_pos_max = nanmax([app.dataset_data(acq, step).source_pos; app.dataset_data(acq, step).detector_pos], [], 1);
            app.dataset_data(acq, step).optode_pos_range = app.dataset_data(acq, step).optode_pos_max - app.dataset_data(acq, step).optode_pos_min;

            %autocorr
            app.dataset_data(acq,step).fig_autocorr.num_lags = ceil(20 * app.dataset_data(acq,step).Fs); %20sec
            app.dataset_data(acq,step).fig_autocorr.times = (0:app.dataset_data(acq,step).fig_autocorr.num_lags) * (1/app.dataset_data(acq,step).Fs);
            app.dataset_data(acq,step).fig_autocorr.corrs = nan(app.dataset_data(acq,step).fig_autocorr.num_lags + 1, app.dataset_data(acq,step).channels_count, app.dataset_data(acq,step).datatypes_count);
            for c = 1:app.dataset_data(acq,step).channels_count
                for d = 1:app.dataset_data(acq,step).datatypes_count
                    app.dataset_data(acq,step).fig_autocorr.corrs(:,c,d) = autocorr(app.dataset_data(acq,step).channel_datatype_signals(:,c,d), app.dataset_data(acq,step).fig_autocorr.num_lags);
                end
            end

            %fourier
            app.dataset_data(acq,step).fig_freq.freq_limits = [0.1 (app.dataset_data(acq,step).Fs/2)];
            for c = 1:app.dataset_data(acq,step).channels_count
                for d = 1:app.dataset_data(acq,step).datatypes_count
                    [app.dataset_data(acq,step).fig_freq.Fourier_mag(:,c,d), app.dataset_data(acq,step).fig_freq.Fourier_freq] = app.CalcFourier(app.dataset_data(acq,step).channel_datatype_signals(:,c,d), ...
                                                                                                                                    app.dataset_data(acq,step).time, ...
                                                                                                                                    app.dataset_data(acq,step).Fs, ...
                                                                                                                                    app.dataset_data(acq,step).fig_freq.freq_limits);
                end
            end

            %datatype colours
            app.dataset_data(acq, step).datatypes_colours = lines(app.dataset_data(acq, step).datatypes_count);
            app.dataset_data(acq, step).datatypes
            if any(app.dataset_data(acq, step).datatypes=="hbo")
                app.dataset_data(acq, step).datatypes_colours(app.dataset_data(acq, step).datatypes=="hbo",:) = [0.8500    0.3250    0.0980];
            end
            if any(app.dataset_data(acq, step).datatypes=="hbr")
                app.dataset_data(acq, step).datatypes_colours(app.dataset_data(acq, step).datatypes=="hbr",:) = [0    0.4470    0.7410];
            end
            
            % success
            success = true;
        end


        %% Navigation

        function [success] = SelectDataset(app, acq, step)
            % default to fail
            success = false;

            % return if acq-step pair doesn't have data
            if ~app.dataset_info.acq_step_has_data(acq, step)
                return
            end
            
            % load if needed
            if ~app.dataset_data(acq, step).loaded
                if ~app.Load_Dataset(acq, step)
                    return
                end
            end

            % set tree node
            if acq == 1
                app.Tree.scroll(app.Tree.Children(1));
            else
                app.Tree.scroll(app.dataset_info.acq_step_info(acq, step).tree_node);
            end
            app.Tree.SelectedNodes = app.dataset_info.acq_step_info(acq, step).tree_node;

            % update displays
            app.DrawAll;

            % success
            success = true;
        end

        function [acq] = GetAcq(app)
            acq = app.Tree.SelectedNodes.NodeData.acq;
        end
        function [step] = GetStep(app)
            step = app.Tree.SelectedNodes.NodeData.step;
        end

        function NavigateRunPrevious(app)
            % get acq with step
            has_data = app.dataset_info.acq_step_has_data(:, app.GetStep);

            % get prior acq
            acq = find(has_data(1:(app.GetAcq-1)), 1, "last");

            % if no prior, loop around
            if isempty(acq)
                acq = app.GetAcq + find(has_data((app.GetAcq+1):end), 1, "last");
            end

            % if found, then seelct
            if ~isempty(acq)
                app.SelectDataset(acq, app.GetStep);
            end
        end
        function NavigateRunNext(app)
            % get acq with step
            has_data = app.dataset_info.acq_step_has_data(:, app.GetStep);

            % get prior acq
            acq = app.GetAcq + find(has_data((app.GetAcq+1):end), 1, "first");

            % if no prior, loop around
            if isempty(acq)
                acq = find(has_data(1:(app.GetAcq-1)), 1, "first");
            end

            % if found, then seelct
            if ~isempty(acq)
                app.SelectDataset(acq, app.GetStep);
            end
        end

        function NavigateStepPrevious(app)
            % get acq with step
            has_data = app.dataset_info.acq_step_has_data(app.GetAcq, :);

            % get prior acq
            step = find(has_data(1:(app.GetStep-1)), 1, "last");

            % if no prior, loop around
            if isempty(step)
                step = app.GetStep + find(has_data((app.GetStep+1):end), 1, "last");
            end

            % if found, then seelct
            if ~isempty(step)
                app.SelectDataset(app.GetAcq, step);
            end
        end
        function NavigateStepNext(app)
            % get acq with step
            has_data = app.dataset_info.acq_step_has_data(app.GetAcq, :);

            % get prior acq
            step = app.GetStep + find(has_data((app.GetStep+1):end), 1, "first");

            % if no prior, loop around
            if isempty(step)
                step = find(has_data(1:(app.GetStep-1)), 1, "first");
            end

            % if found, then seelct
            if ~isempty(step)
                app.SelectDataset(app.GetAcq, step);
            end
        end

        function DrawAll(app)
            % get acq/setp
            acq = app.GetAcq;
            step = app.GetStep;

            % montage
            app.MontageDraw(acq, step)
            disableDefaultInteractivity(app.UIAxes_Montage)
            app.TimeseriesDraw(acq, step)
            disableDefaultInteractivity(app.UIAxes_Main)
            app.CorrDraw(acq, step)
            disableDefaultInteractivity(app.UIAxes_CorrMat)
            app.AutocorrDraw(acq, step)
            disableDefaultInteractivity(app.UIAxes_Autocorr)
            app.FourierAutocorr(acq, step)
            disableDefaultInteractivity(app.UIAxes_Freq)

            % enabel interactions
            iptPointerManager(app.SurfNIRSUIFigure,"enable");

            % set axes toolbars
            axtoolbar(app.UIAxes_Main, ["pan" "zoomin" "zoomout" "restoreview"]);
            axtoolbar(app.UIAxes_CorrMat, ["pan" "zoomin" "zoomout" "restoreview"]);
            axtoolbar(app.UIAxes_Autocorr, ["pan" "zoomin" "zoomout" "restoreview"]);
            axtoolbar(app.UIAxes_Freq, ["pan" "zoomin" "zoomout" "restoreview"]);
            axtoolbar(app.UIAxes_Montage, ["pan" "zoomin" "zoomout" "restoreview"]);

            % default to no highlight
            app.HighlightApply(acq, step)
        end

        %% Interactive Highlighting

        function HighlightStart(app, acq, step, channel_index)
            if app.channel_highlighted ~= channel_index
                app.channel_highlighted = channel_index;
                app.HighlightApply(acq, step);
            end
        end
        function HighlightEnd(app, acq, step)
            if app.channel_highlighted
                app.channel_highlighted = 0;
                app.HighlightApply(acq, step);
            end
        end

        function HighlightApply(app, acq, step)
            app.HighlightApply_Montage(acq, step);
            app.HighlightApply_Main(acq, step);
            app.HighlightApply_Autocorr(acq, step);
            app.HighlightApply_Fourier(acq, step);
        end
        function HighlightApply_Montage(app, acq, step)
            for channel_index = 1:app.dataset_data(acq, step).channels_count
                if app.channel_highlighted == channel_index
                    line_width = app.dataset_data(acq, step).fig_montage.base_line_width * 2;
                    colour = [0 1 0];
                else
                    line_width = app.dataset_data(acq, step).fig_montage.base_line_width;
                    colour = [.5 .5 .5];
                end

                style = '-';
                if ~app.GetChannelActive(acq, step, channel_index)
                    line_width = line_width / 3;
                    style = ':';
                end

                set(app.dataset_data(acq, step).fig_montage.lines(channel_index), LineWidth=line_width, Color=colour, LineStyle=style);
            end
        end
        function HighlightApply_Main(app, acq, step)
            for channel_index = find(app.GetChannelsActive(acq, step))
                if app.channel_highlighted == channel_index
                    line_width = 2;
                else
                    line_width = 0.5;
                end

                set(app.dataset_data(acq, step).fig_main.lines(channel_index,:), LineWidth=line_width);
            end
        end
        function HighlightApply_Autocorr(app, acq, step)
            for channel_index = find(app.GetChannelsActive(acq, step))
                if app.channel_highlighted == channel_index
                    line_width = 2;
                    alpha = 1;
                else
                    line_width = 1;
                    alpha = 0.5;
                end

                set(app.dataset_data(acq, step).fig_autocorr.lines(channel_index,:), LineWidth=line_width);
                for L = app.dataset_data(acq, step).fig_autocorr.lines(channel_index,:)
                    colour = get(L, "Color");
                    set(L, Color=[colour alpha])
                end
            end
        end
        function HighlightApply_Fourier(app, acq, step)
            for channel_index = find(app.GetChannelsActive(acq, step))
                if app.channel_highlighted == channel_index
                    line_width = 2;
                    alpha = 1;
                else
                    line_width = 1;
                    alpha = 0.3;
                end

                set(app.dataset_data(acq, step).fig_freq.lines(channel_index,:), LineWidth=line_width);
                for L = app.dataset_data(acq, step).fig_freq.lines(channel_index,:)
                    colour = get(L, "Color");
                    set(L, Color=[colour alpha])
                end
            end
        end

        
        %% Montage

        function MontageDraw(app, acq, step)
            cla(app.UIAxes_Montage)

            % settings
            app.dataset_data(acq, step).fig_montage.base_line_width = round(max(app.dataset_data(acq, step).optode_pos_range) * 2);

            % draw
            hold(app.UIAxes_Montage, "on")
            app.MontageDraw_Optodes(acq, step)
            app.MontageDraw_Channels(acq, step)
            hold(app.UIAxes_Montage, "off")

            % set axis
            xlim(app.UIAxes_Montage, [app.dataset_data(acq, step).optode_pos_min(1) app.dataset_data(acq, step).optode_pos_max(1)] + ([-1 +1] * app.dataset_data(acq, step).optode_pos_range(1) * 0.1))
            ylim(app.UIAxes_Montage, [app.dataset_data(acq, step).optode_pos_min(2) app.dataset_data(acq, step).optode_pos_max(2)] + ([-1 +1] * app.dataset_data(acq, step).optode_pos_range(2) * 0.1))
            axis(app.UIAxes_Montage,"equal")
            axis(app.UIAxes_Montage,"off")
        end

        function MontageDraw_Optodes(app, acq, step)
            font_size = round(max(app.dataset_data(acq, step).optode_pos_range) * 10);
            marker_size = round(max(app.dataset_data(acq, step).optode_pos_range) * 4);
            label_offset_x = app.dataset_data(acq, step).optode_pos_range(1) * .03;
            label_offset_y = app.dataset_data(acq, step).optode_pos_range(2) * .03;

            for mode = ["dots" "labels"]
                colour = [0.8 0 0];
                for s = 1:size(app.dataset_data(acq, step).source_pos,1)
                    switch mode
                        case "dots"
                            plot(app.UIAxes_Montage, app.dataset_data(acq, step).source_pos(s,1), app.dataset_data(acq, step).source_pos(s,2), 'o', MarkerFaceColor=colour, MarkerEdgeColor=colour, MarkerSize=marker_size)
                        case "labels"
                            text(app.UIAxes_Montage, app.dataset_data(acq, step).source_pos(s,1) + label_offset_x, app.dataset_data(acq, step).source_pos(s,2) + label_offset_y, sprintf("S%d", s), FontSize=font_size)
                        otherwise
                            error('undefined mode')
                    end
                end
                
                colour = [0 0 0.8];
                for d = 1:size(app.dataset_data(acq, step).detector_pos,1)
                    switch mode
                        case "dots"
                            plot(app.UIAxes_Montage, app.dataset_data(acq, step).detector_pos(d,1), app.dataset_data(acq, step).detector_pos(d,2), 'o', MarkerFaceColor=colour, MarkerEdgeColor=colour, MarkerSize=marker_size)
                        case "labels"
                            text(app.UIAxes_Montage, app.dataset_data(acq, step).detector_pos(d,1) + label_offset_x, app.dataset_data(acq, step).detector_pos(d,2) + label_offset_y, sprintf("D%d", d), FontSize=font_size)
                        otherwise
                            error('undefined mode')
                    end
                end
            end
        end
        function MontageDraw_Channels(app, acq, step)
            for channel_index = 1:app.dataset_data(acq, step).channels_count
                % draw line
                xs = [app.dataset_data(acq, step).source_pos(app.dataset_data(acq, step).channels.source(channel_index),1) app.dataset_data(acq, step).detector_pos(app.dataset_data(acq, step).channels.detector(channel_index),1)];
                ys = [app.dataset_data(acq, step).source_pos(app.dataset_data(acq, step).channels.source(channel_index),2) app.dataset_data(acq, step).detector_pos(app.dataset_data(acq, step).channels.detector(channel_index),2)];
                app.dataset_data(acq, step).fig_montage.lines(channel_index) = plot(app.UIAxes_Montage, xs, ys, '-');

                % setup interaction
                pointerBehavior.enterFcn    = @(~,~,~)app.HighlightStart(acq,step,channel_index);
                pointerBehavior.exitFcn     = @(~,~,~)app.HighlightEnd(acq,step);
                pointerBehavior.traverseFcn = [];
                iptSetPointerBehavior(app.dataset_data(acq, step).fig_montage.lines(channel_index), pointerBehavior);
                app.dataset_data(acq, step).fig_montage.lines(channel_index).ButtonDownFcn = @(~,~,~)app.ToggleActive(acq,step,channel_index);
            end
        end

        function ToggleActive(app, acq, step, channel_index)
            ind = app.dataset_info.exclude_SD.source==app.dataset_data(acq, step).channels.source(channel_index) & ...
                app.dataset_info.exclude_SD.detector==app.dataset_data(acq, step).channels.detector(channel_index);

            if any(ind)
                app.dataset_info.exclude_SD(ind,:) = [];
            else
                app.dataset_info.exclude_SD(end+1,:) = app.dataset_data(acq, step).channels(channel_index, :);
            end

            app.DrawAll
        end

        function [channels_active] = GetChannelsActive(app, acq, step)
            channels_active = arrayfun(@(s,d) ~any(app.dataset_info.exclude_SD.source==s & app.dataset_info.exclude_SD.detector==d), app.dataset_data(acq, step).channels.source, app.dataset_data(acq, step).channels.detector)';
        end
        function [is_active] = GetChannelActive(app, acq, step, channel_index)
            is_active = ~any(app.dataset_info.exclude_SD.source==app.dataset_data(acq, step).channels.source(channel_index) & ...
                app.dataset_info.exclude_SD.detector==app.dataset_data(acq, step).channels.detector(channel_index));
        end

        %% Timeseries
        
        function TimeseriesDraw(app, acq, step)
            cla(app.UIAxes_Main)

            xs = app.dataset_data(acq,step).time;

            all_y = app.dataset_data(acq,step).channel_datatype_signals;
            all_y = all_y - nanmean(all_y,1);
            all_y = all_y ./ std(all_y,1);

            channels_to_draw = find(app.GetChannelsActive(acq,step));
            channels_to_draw_count = length(channels_to_draw);

            stacked_y = (1:channels_to_draw_count) * 10;

            hold(app.UIAxes_Main,"on")

            rects = [];
            for c = 1:app.dataset_data(acq, step).conditions_count
                for t = 1:length(app.dataset_data(acq, step).conditions.Onsets{c})
                    rects(end+1) = rectangle(app.UIAxes_Main, Position=[app.dataset_data(acq, step).conditions.Onsets{c}(t) 0 app.dataset_data(acq, step).conditions.Durations{c}(t) 1], ...
                                    FaceColor=app.dataset_data(acq, step).conditions.Colour(c,:), EdgeColor=app.dataset_data(acq, step).conditions.Colour(c,:));
                end
            end

            for c = 1:channels_to_draw_count
                channel_index = channels_to_draw(c);

                % plot
                for dt = 1:app.dataset_data(acq, step).datatypes_count
                    ys = squeeze(all_y(:,channel_index,dt)) + stacked_y(c);
                    app.dataset_data(acq, step).fig_main.lines(channel_index,dt) = plot(app.UIAxes_Main, xs, ys, '-', Color=app.dataset_data(acq, step).datatypes_colours(dt,:));
                end

                % setup interaction
                pointerBehavior.enterFcn    = @(~,~,~)app.HighlightStart(acq,step,channel_index);
                pointerBehavior.exitFcn     = @(~,~,~)app.HighlightEnd(acq,step);
                pointerBehavior.traverseFcn = [];
                iptSetPointerBehavior(app.dataset_data(acq, step).fig_main.lines(channel_index,:), pointerBehavior);
            end
            hold(app.UIAxes_Main,"off")

            yl = [stacked_y(1) stacked_y(end)] + ([-1 +1] * range(stacked_y) * 0.1);
            ylim(app.UIAxes_Main, yl);
            for r = rects
                p = get(r, "Position");
                set(r, "Position", [p(1) yl(1) p(3) range(yl)]);
            end

            set(app.UIAxes_Main, YTick=stacked_y, YTickLabel=app.dataset_data(acq, step).fig_main.channel_names(channels_to_draw))
            xticks(app.UIAxes_Main, "auto")
            xlim(app.UIAxes_Main, app.dataset_data(acq, step).time([1 end]))
            xlabel(app.UIAxes_Main, "Time (sec)")
            title(app.UIAxes_Main, strrep(strrep(app.dataset_info.acq_step_info(acq, step).filename,'_','\_'),'GRATO','DEMO'))
        end

        %% Correlation Matrix
        
        function CorrDraw(app, acq, step)
            cla(app.UIAxes_CorrMat)
    
            active_channels = find(app.GetChannelsActive(acq,step));
            channel_inds = repmat(active_channels, [1 app.dataset_data(acq,step).datatypes_count]);
            datatypes = cell2mat(arrayfun(@(dt) ones(1,length(active_channels))*dt, 1:app.dataset_data(acq,step).datatypes_count, UniformOutput=false));

            corr_mat = corr(cell2mat(arrayfun(@(c,dt) app.dataset_data(acq,step).channel_datatype_signals(:,c,dt), channel_inds, datatypes, UniformOutput=false)));
            
            imagesc(app.UIAxes_CorrMat, corr_mat)
            axis(app.UIAxes_CorrMat, "image")
            
            clim(app.UIAxes_CorrMat,[-1 +1])
            colormap(app.UIAxes_CorrMat,app.make_cmap(3))
            cb = colorbar(app.UIAxes_CorrMat);

            %lines
            inds = find(diff(datatypes));
            row_count = length(datatypes);
            hold(app.UIAxes_CorrMat,"on")
                for i = inds
                    plot(app.UIAxes_CorrMat, [i i]+0.5,[0 row_count]+0.5,'k')
                    plot(app.UIAxes_CorrMat, [0 row_count]+0.5,[i i]+0.5,'k')
                end
            hold(app.UIAxes_CorrMat,"off")

            %labels
            set(app.UIAxes_CorrMat, xtick=[1 (inds+1)], xticklabels=app.dataset_data(acq,step).datatypes, ytick=[1 (inds+1)], yticklabels=app.dataset_data(acq,step).datatypes, XAxisLocation="top")
            title(app.UIAxes_CorrMat, 'Correlations')
        end

        function [cmap] = make_cmap(app, number_colours)
            arguments
                app
                number_colours {mustBeMember(number_colours,[2,3])} = 2
            end
            
            cp = [0.8 0.1 0.1];
            c0 = [0.5 0.5 0.5];
            cn = [0.1 0.1 0.8];
            n = 50;
            
            switch number_colours
                case 2
                    cmap = cell2mat(arrayfun(@(a,b) linspace(a,b,n*2)', c0, cp, 'UniformOutput', false));
                case 3
                    cmap = [cell2mat(arrayfun(@(a,b) linspace(a,b,n)', cn, c0, 'UniformOutput', false));
                            cell2mat(arrayfun(@(a,b) linspace(a,b,n)', c0, cp, 'UniformOutput', false))];
                otherwise
                    error
            end
        end

        %% Temporal Autocorrelation
        
        function AutocorrDraw(app, acq, step)
            cla(app.UIAxes_Autocorr)

            channels_to_draw = find(app.GetChannelsActive(acq,step));
            channels_to_draw_count = length(channels_to_draw);

            hold(app.UIAxes_Autocorr,"on")
            for c = 1:channels_to_draw_count
                channel_index = channels_to_draw(c);

                % plot
                for dt = 1:app.dataset_data(acq, step).datatypes_count
                    app.dataset_data(acq, step).fig_autocorr.lines(channel_index,dt) = plot(app.UIAxes_Autocorr, app.dataset_data(acq,step).fig_autocorr.times, app.dataset_data(acq,step).fig_autocorr.corrs(:,channel_index,dt), Color=app.dataset_data(acq, step).datatypes_colours(dt,:));
                end

                % setup interaction
                pointerBehavior.enterFcn    = @(~,~,~)app.HighlightStart(acq,step,channel_index);
                pointerBehavior.exitFcn     = @(~,~,~)app.HighlightEnd(acq,step);
                pointerBehavior.traverseFcn = [];
                iptSetPointerBehavior(app.dataset_data(acq, step).fig_autocorr.lines(channel_index,:), pointerBehavior);
            end
            hold(app.UIAxes_Autocorr,"off")

            xticks(app.UIAxes_Autocorr,"auto")
            yticks(app.UIAxes_Autocorr, "auto")
            xlim(app.UIAxes_Autocorr, app.dataset_data(acq,step).fig_autocorr.times([1 end]))
            xlabel(app.UIAxes_Autocorr, "Lags (sec)")
            ylabel(app.UIAxes_Autocorr, "Correlation")
            title(app.UIAxes_Autocorr, "Temporal Autocorrelation")
        end

        %% Fourier Transform

        function FourierAutocorr(app, acq, step)
            cla(app.UIAxes_Freq)
            
            channels_to_draw = find(app.GetChannelsActive(acq,step));
            channels_to_draw_count = length(channels_to_draw);

            hold(app.UIAxes_Freq,"on")
            for c = 1:channels_to_draw_count
                channel_index = channels_to_draw(c);

                % plot
                for dt = 1:app.dataset_data(acq, step).datatypes_count
                    ys = app.dataset_data(acq,step).fig_freq.Fourier_mag(:,channel_index,dt);
%                     ys = ys ./ std(ys, 1);
                    app.dataset_data(acq, step).fig_freq.lines(channel_index,dt) = plot(app.UIAxes_Freq, app.dataset_data(acq,step).fig_freq.Fourier_freq, ys, Color=app.dataset_data(acq, step).datatypes_colours(dt,:));
                end

                % setup interaction
                pointerBehavior.enterFcn    = @(~,~,~)app.HighlightStart(acq,step,channel_index);
                pointerBehavior.exitFcn     = @(~,~,~)app.HighlightEnd(acq,step);
                pointerBehavior.traverseFcn = [];
                iptSetPointerBehavior(app.dataset_data(acq, step).fig_freq.lines(channel_index,:), pointerBehavior);
            end
            hold(app.UIAxes_Freq,"off")

            xticks(app.UIAxes_Freq,"auto")
            yticks(app.UIAxes_Freq, "auto")
            xlim(app.UIAxes_Freq, app.dataset_data(acq,step).fig_freq.Fourier_freq([1 end]))
            xlabel(app.UIAxes_Freq, "Frequency (Hz)")
            ylabel(app.UIAxes_Freq, "Magnitude")
            title(app.UIAxes_Freq, "Fourier Transform")
        end
        
        function [power,freq] = CalcFourier(app, data, times, Fs, freq_range, time_start_end)
            %% Defaults
            
            freq_upper_limit = Fs/2;
            if ~exist('freq_range', 'var')
                freq_range = [0 freq_upper_limit];
            elseif freq_range(2) >= freq_upper_limit
                freq_range(2) = freq_upper_limit;
            end
            
            if ~exist('time_start_end', 'var')
                time_start_end = [-inf +inf];
            end
            
            %% Calculate
            
            %select samples
            samples_select = (times >= time_start_end(1)) & (times <= time_start_end(2));
            samples_select_count = sum(samples_select);
            
            %calc fourier
            y = fft(data(samples_select,:));  
            power = abs(y);
            
            %select frequencies
            freq = (0:samples_select_count-1)*Fs/samples_select_count;
            freq_select = (freq>=freq_range(1)) & (freq<=freq_range(2));
            
            %restrict frequencies
            power = power(freq_select, :);
            freq = freq(freq_select);
        end

    end
    

    % Callbacks that handle component events
    methods (Access = private)

        % Code that executes after component creation
        function startupFcn(app)
            app.Load_fNIRSTools("." + filesep + "TestData");
            if app.DEBUG
                assignin('base','app',app)
            end
        end

        % Selection changed function: Tree
        function TreeSelectionChanged(app, event)
            if isempty(event.SelectedNodes.NodeData)
                app.Tree.SelectedNodes = event.PreviousSelectedNodes;
            else
                selectedNodes = app.Tree.SelectedNodes;
                if ~isempty(selectedNodes.NodeData)
                    app.SelectDataset(selectedNodes.NodeData.acq, selectedNodes.NodeData.step);
                end
            end
        end

        % Menu selected function: BIDSstylematContainingAnalyzIRMenu
        function BIDSstylematContainingAnalyzIRMenuSelected(app, event)
            app.Load_fNIRSTools;
        end

        % Menu selected function: ExitMenu
        function ExitMenuSelected(app, event)
            delete(app)
        end

        % Button pushed function: ButtonLeft
        function ButtonLeftPushed(app, event)
            app.NavigateRunPrevious;
        end

        % Button pushed function: ButtonRight
        function ButtonRightPushed(app, event)
            app.NavigateRunNext;
        end

        % Button pushed function: ButtonUp
        function ButtonUpPushed(app, event)
            app.NavigateStepPrevious;
        end

        % Button pushed function: ButtonDown
        function ButtonDownPushed(app, event)
            app.NavigateStepNext;
        end

        % Key press function: SurfNIRSUIFigure
        function SurfNIRSUIFigureKeyPress(app, event)
            key = event.Key;
            switch key
                case "leftarrow"
                    app.NavigateRunPrevious;
                case "rightarrow"
                    app.NavigateRunNext;
                case "uparrow"
                    app.NavigateStepPrevious;
                case "downarrow"
                    app.NavigateStepNext;
            end
        end
    end

    % Component initialization
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Get the file path for locating images
            pathToMLAPP = fileparts(mfilename('fullpath'));

            % Create SurfNIRSUIFigure and hide until all components are created
            app.SurfNIRSUIFigure = uifigure('Visible', 'off');
            app.SurfNIRSUIFigure.Position = [-1920 40 1920 990];
            app.SurfNIRSUIFigure.Name = 'SurfNIRS';
            app.SurfNIRSUIFigure.Icon = fullfile(pathToMLAPP, 'logo_temp.png');
            app.SurfNIRSUIFigure.KeyPressFcn = createCallbackFcn(app, @SurfNIRSUIFigureKeyPress, true);
            app.SurfNIRSUIFigure.Scrollable = 'on';
            app.SurfNIRSUIFigure.WindowState = 'maximized';

            % Create FileMenu
            app.FileMenu = uimenu(app.SurfNIRSUIFigure);
            app.FileMenu.Text = 'File';

            % Create SaveSessionTODOMenu
            app.SaveSessionTODOMenu = uimenu(app.FileMenu);
            app.SaveSessionTODOMenu.Enable = 'off';
            app.SaveSessionTODOMenu.Text = 'Save Session [TODO]';

            % Create LoadSessionTODOMenu
            app.LoadSessionTODOMenu = uimenu(app.FileMenu);
            app.LoadSessionTODOMenu.Enable = 'off';
            app.LoadSessionTODOMenu.Text = 'Load Session [TODO]';

            % Create LoadDataMenu
            app.LoadDataMenu = uimenu(app.FileMenu);
            app.LoadDataMenu.Separator = 'on';
            app.LoadDataMenu.Text = 'Load Data';

            % Create BIDSstylematContainingAnalyzIRMenu
            app.BIDSstylematContainingAnalyzIRMenu = uimenu(app.LoadDataMenu);
            app.BIDSstylematContainingAnalyzIRMenu.MenuSelectedFcn = createCallbackFcn(app, @BIDSstylematContainingAnalyzIRMenuSelected, true);
            app.BIDSstylematContainingAnalyzIRMenu.Tooltip = {'BIDS-style.mat files (sub-*_ses-*_task-*_run-*_suffix) containing a single nirs.core.Data (e.g., fNIRSTools)'};
            app.BIDSstylematContainingAnalyzIRMenu.Text = 'BIDS-style .mat Containing AnalyzIR';

            % Create ExitMenu
            app.ExitMenu = uimenu(app.FileMenu);
            app.ExitMenu.MenuSelectedFcn = createCallbackFcn(app, @ExitMenuSelected, true);
            app.ExitMenu.Separator = 'on';
            app.ExitMenu.Text = 'Exit';

            % Create TimeseriesMenu
            app.TimeseriesMenu = uimenu(app.SurfNIRSUIFigure);
            app.TimeseriesMenu.Text = 'Timeseries';

            % Create ViewModeMenu
            app.ViewModeMenu = uimenu(app.TimeseriesMenu);
            app.ViewModeMenu.Text = 'View Mode';

            % Create RawTODOMenu
            app.RawTODOMenu = uimenu(app.ViewModeMenu);
            app.RawTODOMenu.Enable = 'off';
            app.RawTODOMenu.Text = 'Raw [TODO]';

            % Create CenteredTODOMenu
            app.CenteredTODOMenu = uimenu(app.ViewModeMenu);
            app.CenteredTODOMenu.Enable = 'off';
            app.CenteredTODOMenu.Text = 'Centered [TODO]';

            % Create StackedTODOMenu
            app.StackedTODOMenu = uimenu(app.ViewModeMenu);
            app.StackedTODOMenu.Enable = 'off';
            app.StackedTODOMenu.Checked = 'on';
            app.StackedTODOMenu.Text = 'Stacked [TODO]';

            % Create MatrixTODOMenu
            app.MatrixTODOMenu = uimenu(app.ViewModeMenu);
            app.MatrixTODOMenu.Enable = 'off';
            app.MatrixTODOMenu.Text = 'Matrix [TODO]';

            % Create EnableNormalizationTODOMenu
            app.EnableNormalizationTODOMenu = uimenu(app.TimeseriesMenu);
            app.EnableNormalizationTODOMenu.Enable = 'off';
            app.EnableNormalizationTODOMenu.Text = 'Enable Normalization [TODO]';

            % Create EnableEventDrawingTODOMenu
            app.EnableEventDrawingTODOMenu = uimenu(app.TimeseriesMenu);
            app.EnableEventDrawingTODOMenu.Enable = 'off';
            app.EnableEventDrawingTODOMenu.Separator = 'on';
            app.EnableEventDrawingTODOMenu.Checked = 'on';
            app.EnableEventDrawingTODOMenu.Text = 'Enable Event Drawing [TODO]';

            % Create SetEventNamesTODOMenu
            app.SetEventNamesTODOMenu = uimenu(app.TimeseriesMenu);
            app.SetEventNamesTODOMenu.Enable = 'off';
            app.SetEventNamesTODOMenu.Text = 'Set Event Names [TODO]';

            % Create SetEventColoursTODOMenu
            app.SetEventColoursTODOMenu = uimenu(app.TimeseriesMenu);
            app.SetEventColoursTODOMenu.Enable = 'off';
            app.SetEventColoursTODOMenu.Text = 'Set Event Colours [TODO]';

            % Create FrequencyMenu
            app.FrequencyMenu = uimenu(app.SurfNIRSUIFigure);
            app.FrequencyMenu.Text = 'Frequency';

            % Create EnableNormalizationTODOMenu_2
            app.EnableNormalizationTODOMenu_2 = uimenu(app.FrequencyMenu);
            app.EnableNormalizationTODOMenu_2.Enable = 'off';
            app.EnableNormalizationTODOMenu_2.Text = 'Enable Normalization [TODO]';

            % Create SetDisplayRangeTODOMenu
            app.SetDisplayRangeTODOMenu = uimenu(app.FrequencyMenu);
            app.SetDisplayRangeTODOMenu.Enable = 'off';
            app.SetDisplayRangeTODOMenu.Text = 'Set Display Range [TODO]';

            % Create MontageMenu
            app.MontageMenu = uimenu(app.SurfNIRSUIFigure);
            app.MontageMenu.Text = 'Montage';

            % Create ActivateAllTODOMenu
            app.ActivateAllTODOMenu = uimenu(app.MontageMenu);
            app.ActivateAllTODOMenu.Enable = 'off';
            app.ActivateAllTODOMenu.Text = 'Activate All [TODO]';

            % Create DeactivateAllTODOMenu
            app.DeactivateAllTODOMenu = uimenu(app.MontageMenu);
            app.DeactivateAllTODOMenu.Enable = 'off';
            app.DeactivateAllTODOMenu.Text = 'Deactivate All [TODO]';

            % Create EnableSCIColourCodingTODOMenu
            app.EnableSCIColourCodingTODOMenu = uimenu(app.MontageMenu);
            app.EnableSCIColourCodingTODOMenu.Enable = 'off';
            app.EnableSCIColourCodingTODOMenu.Separator = 'on';
            app.EnableSCIColourCodingTODOMenu.Checked = 'on';
            app.EnableSCIColourCodingTODOMenu.Text = 'Enable SCI Colour-Coding [TODO]';

            % Create ApplySCIThresholdTODOMenu
            app.ApplySCIThresholdTODOMenu = uimenu(app.MontageMenu);
            app.ApplySCIThresholdTODOMenu.Enable = 'off';
            app.ApplySCIThresholdTODOMenu.Text = 'Apply SCI Threshold [TODO]';

            % Create SettingsMenu
            app.SettingsMenu = uimenu(app.SurfNIRSUIFigure);
            app.SettingsMenu.Text = 'Settings';

            % Create EnableHoverInteractionsTODOMenu
            app.EnableHoverInteractionsTODOMenu = uimenu(app.SettingsMenu);
            app.EnableHoverInteractionsTODOMenu.Enable = 'off';
            app.EnableHoverInteractionsTODOMenu.Checked = 'on';
            app.EnableHoverInteractionsTODOMenu.Text = 'Enable Hover Interactions [TODO]';

            % Create SelectDatatypestoDisplayTODOMenu
            app.SelectDatatypestoDisplayTODOMenu = uimenu(app.SettingsMenu);
            app.SelectDatatypestoDisplayTODOMenu.Enable = 'off';
            app.SelectDatatypestoDisplayTODOMenu.Separator = 'on';
            app.SelectDatatypestoDisplayTODOMenu.Text = 'Select Datatypes to Display [TODO]';

            % Create SetDatatypeColoursTODOMenu
            app.SetDatatypeColoursTODOMenu = uimenu(app.SettingsMenu);
            app.SetDatatypeColoursTODOMenu.Enable = 'off';
            app.SetDatatypeColoursTODOMenu.Text = 'Set Datatype Colours [TODO]';

            % Create EnableAlwaysReloadingDataTODOMenu
            app.EnableAlwaysReloadingDataTODOMenu = uimenu(app.SettingsMenu);
            app.EnableAlwaysReloadingDataTODOMenu.Enable = 'off';
            app.EnableAlwaysReloadingDataTODOMenu.Separator = 'on';
            app.EnableAlwaysReloadingDataTODOMenu.Text = 'Enable Always Reloading Data [TODO]';

            % Create UIAxes_Main
            app.UIAxes_Main = uiaxes(app.SurfNIRSUIFigure);
            app.UIAxes_Main.XTick = [];
            app.UIAxes_Main.YTick = [];
            app.UIAxes_Main.FontSize = 24;
            app.UIAxes_Main.Position = [257 15 1168 970];

            % Create UIAxes_Autocorr
            app.UIAxes_Autocorr = uiaxes(app.SurfNIRSUIFigure);
            app.UIAxes_Autocorr.XTick = [];
            app.UIAxes_Autocorr.YTick = [];
            app.UIAxes_Autocorr.Position = [1671 741 250 250];

            % Create UIAxes_CorrMat
            app.UIAxes_CorrMat = uiaxes(app.SurfNIRSUIFigure);
            app.UIAxes_CorrMat.XTick = [];
            app.UIAxes_CorrMat.YTick = [];
            app.UIAxes_CorrMat.Position = [1423 741 250 250];

            % Create UIAxes_Freq
            app.UIAxes_Freq = uiaxes(app.SurfNIRSUIFigure);
            app.UIAxes_Freq.XTick = [];
            app.UIAxes_Freq.YTick = [];
            app.UIAxes_Freq.Position = [1423 533 498 210];

            % Create UIAxes_Montage
            app.UIAxes_Montage = uiaxes(app.SurfNIRSUIFigure);
            app.UIAxes_Montage.XTick = [];
            app.UIAxes_Montage.YTick = [];
            app.UIAxes_Montage.Position = [1423 16 498 506];

            % Create Tree
            app.Tree = uitree(app.SurfNIRSUIFigure);
            app.Tree.SelectionChangedFcn = createCallbackFcn(app, @TreeSelectionChanged, true);
            app.Tree.FontSize = 10;
            app.Tree.Position = [7 9 251 833];

            % Create SurfNIRSLabel
            app.SurfNIRSLabel = uilabel(app.SurfNIRSUIFigure);
            app.SurfNIRSLabel.FontSize = 48;
            app.SurfNIRSLabel.Position = [70 922 209 63];
            app.SurfNIRSLabel.Text = 'SurfNIRS';

            % Create DatasetsLabel
            app.DatasetsLabel = uilabel(app.SurfNIRSUIFigure);
            app.DatasetsLabel.FontSize = 24;
            app.DatasetsLabel.Position = [60 841 100 32];
            app.DatasetsLabel.Text = 'Datasets';

            % Create Slider_2Label
            app.Slider_2Label = uilabel(app.SurfNIRSUIFigure);
            app.Slider_2Label.HorizontalAlignment = 'right';
            app.Slider_2Label.Position = [1740 699 25 22];
            app.Slider_2Label.Text = '';

            % Create NavigateacrossandwithinrunsLabel
            app.NavigateacrossandwithinrunsLabel = uilabel(app.SurfNIRSUIFigure);
            app.NavigateacrossandwithinrunsLabel.HorizontalAlignment = 'right';
            app.NavigateacrossandwithinrunsLabel.FontSize = 18;
            app.NavigateacrossandwithinrunsLabel.Position = [1 879 187 44];
            app.NavigateacrossandwithinrunsLabel.Text = {'Navigate across(←/→)'; 'and within(↑/↓) runs:'};

            % Create ButtonLeft
            app.ButtonLeft = uibutton(app.SurfNIRSUIFigure, 'push');
            app.ButtonLeft.ButtonPushedFcn = createCallbackFcn(app, @ButtonLeftPushed, true);
            app.ButtonLeft.BackgroundColor = [1 1 1];
            app.ButtonLeft.Position = [191 879 22 23];
            app.ButtonLeft.Text = '←';

            % Create ButtonRight
            app.ButtonRight = uibutton(app.SurfNIRSUIFigure, 'push');
            app.ButtonRight.ButtonPushedFcn = createCallbackFcn(app, @ButtonRightPushed, true);
            app.ButtonRight.BackgroundColor = [1 1 1];
            app.ButtonRight.Position = [237 879 22 23];
            app.ButtonRight.Text = '→';

            % Create ButtonUp
            app.ButtonUp = uibutton(app.SurfNIRSUIFigure, 'push');
            app.ButtonUp.ButtonPushedFcn = createCallbackFcn(app, @ButtonUpPushed, true);
            app.ButtonUp.BackgroundColor = [0.902 0.902 0.902];
            app.ButtonUp.Position = [214 903 22 23];
            app.ButtonUp.Text = '↑';

            % Create ButtonDown
            app.ButtonDown = uibutton(app.SurfNIRSUIFigure, 'push');
            app.ButtonDown.ButtonPushedFcn = createCallbackFcn(app, @ButtonDownPushed, true);
            app.ButtonDown.BackgroundColor = [0.902 0.902 0.902];
            app.ButtonDown.Position = [214 879 22 23];
            app.ButtonDown.Text = '↓';

            % Create Image
            app.Image = uiimage(app.SurfNIRSUIFigure);
            app.Image.Position = [4 922 66 66];
            app.Image.ImageSource = fullfile(pathToMLAPP, 'logo_temp.png');

            % Show the figure after all components are created
            app.SurfNIRSUIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = SurfNIRS_exported

            % Create UIFigure and components
            createComponents(app)

            % Register the app with App Designer
            registerApp(app, app.SurfNIRSUIFigure)

            % Execute the startup function
            runStartupFcn(app, @startupFcn)

            if nargout == 0
                clear app
            end
        end

        % Code that executes before app deletion
        function delete(app)

            % Delete UIFigure when app is deleted
            delete(app.SurfNIRSUIFigure)
        end
    end
end