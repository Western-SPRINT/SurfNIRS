classdef Data < handle
    % Contains the data (raw and calculations) from a single acquisition-step
    % Designed to be setup quickly and then not load/calculate until needed
    
    properties (SetAccess = private, GetAccess = public)
        sub
        task
        ses
        run
        step
        filepath
        loaded = false

        datatypes = string([])
        sample_times = [];
        channels = table(Size=[0 3], VariableNames=["source" "detector" "data"], VariableTypes=["uint32" "uint32" "cell"])
        sources = table(Size=[0 3], VariableNames=["label" "x" "y"], VariableTypes=["string" "double" "double"])
        detectors = table(Size=[0 3], VariableNames=["label" "x" "y"], VariableTypes=["string" "double" "double"])
        
        Fs = nan;
        autocorr_lag_times = [];
        fourier_frequencies = [];
        corrmat_channels = [];
        corrmat_datatypes = [];
        corrmat_values = [];
    end

    properties (Dependent = true)
        datatypes_count
        channels_count
        sources_count
        detectors_count
        samples
        label
    end

    properties (Access = private)
        description
        private_inputs
        load_function
    end
    
    methods

        function obj = Data(load_function, filepath, step, description, private_inputs)
            arguments
                load_function (1,:) string {mustBeNonzeroLengthText}
                filepath (1,1) string {mustBeFile}
                step (1,1) string {mustBeNonzeroLengthText}
                description.sub (1,1) string {mustBeNonzeroLengthText} = "unknown"
                description.task (1,1) string {mustBeNonzeroLengthText} = "unknown"
                description.ses (1,1) string {mustBeNonzeroLengthText} = "unknown"
                description.run (1,1) string {mustBeNonzeroLengthText} = "unknown"
                description.label (1,1) string {mustBeNonzeroLengthText}
                private_inputs.Homer_datatype (1,1) string {mustBeMember(private_inputs.Homer_datatype,["d" "dod" "dc"])}
            end

            % check that loading function exists
            if ~exist(load_function, "file")
                error("Unsupported load function: %s", load_function)
            else
                % store function handle to use during loading
                obj.load_function = str2func(load_function);
            end

            % store
            obj.filepath = filepath;
            obj.step = step;

            % keep original description for Homer3
            obj.private_inputs.description_original = description;
            
            % override description
            obj.description = description;
            for f = string(fields(obj.description)')
                if f ~= "label"
                    % enforce BIDS-style name
                    if ~startsWith(obj.description.(f), f + "-")
                        obj.description.(f) = f + "-" + obj.description.(f);
                    end
%                     obj.description.(f) = strrep(obj.description.(f), "_", "-");

                    % store values
                    obj.(f) = obj.description.(f);
                end
            end

            % store private_inputs if applicable
            for f = string(fields(private_inputs)')
                obj.private_inputs.(f) = private_inputs.(f);
            end
        end

        function success = Load(obj)
            success = obj.load_function(obj, obj.private_inputs) && obj.Process;
            obj.loaded = success;
        end

        function c = get.datatypes_count(obj)
            c = length(obj.datatypes);
        end
        function c = get.channels_count(obj)
            c = height(obj.channels);
        end
        function c = get.sources_count(obj)
            c = height(obj.sources);
        end
        function c = get.detectors_count(obj)
            c = height(obj.detectors);
        end
        function c = get.samples(obj)
            c = length(obj.sample_times);
        end

        function label = get.label(obj)
            if isfield(obj.description,"label") && ~isempty(obj.description.label)
                label = obj.description.label;
            else
                label = obj.sub + "_" + obj.task + "_" + obj.ses + "_" + obj.run + "_" + obj.step;
            end
        end
    end

    methods (Access = private)
        function success = Process(obj)
            % default to fail
            success = false;

            % TEMP
            % SD = [13 14; 12 14; 12 13; 11 11; 10 11; 10 10; 9 8; 8 8; 8 7];
            % SD = array2table(SD,VariableNames=["source" "detector"]);
            % select = arrayfun(@(s,d) any((SD.source == s) & (SD.detector == d)), obj.channels.source, obj.channels.detector);
            % obj.channels = obj.channels(select, :);

            % rename datatypes
            obj.datatypes = strrep(obj.datatypes, "hbo", "HbO");
            obj.datatypes = strrep(obj.datatypes, "hbr", "HbR");
            obj.datatypes = strrep(obj.datatypes, "hbt", "HbT");

            % calculate Fs
            obj.Fs = 1 / median(diff(obj.sample_times));

            % Temporal Autocorr
            sec = 20;
            obj.autocorr_lag_times = 0 : (1/obj.Fs) : sec;
            num_lags = floor(sec * obj.Fs);
            for c = 1:obj.channels_count
                obj.channels.autocorr{c} = nan(num_lags+1, obj.datatypes_count);
                for dt = 1:obj.datatypes_count
                    data = obj.channels.data{c}(:,dt)';
                    [xc, lags] = xcorr(data - mean(data), num_lags, "coeff");
                    obj.channels.autocorr{c}(:,dt) = xc(lags>=0);
                end
            end

            % Fourier
            obj.fourier_frequencies = obj.Fs*(0:(obj.samples/2))/obj.samples;
            for c = 1:obj.channels_count
                obj.channels.fourier{c} = nan(length(obj.fourier_frequencies), obj.datatypes_count);
                for dt = 1:obj.datatypes_count
                    data = obj.channels.data{c}(:,dt)';
                    Y = fft(data);
                    P2 = abs(Y/obj.samples);
                    P1 = P2(1:obj.samples/2+1);
                    P1(2:end-1) = 2*P1(2:end-1);
                    obj.channels.fourier{c}(:,dt) = P1';
                end
            end

            % Correlation Matrix
            obj.corrmat_channels = repmat(1:obj.channels_count, [1 obj.datatypes_count]);
            obj.corrmat_datatypes = cell2mat(arrayfun(@(dt) ones(1,obj.channels_count)*dt, 1:obj.datatypes_count, UniformOutput=false));
            d = cell2mat(arrayfun(@(c,dt) obj.channels.data{c}(:,dt), obj.corrmat_channels, obj.corrmat_datatypes, UniformOutput=false));
            obj.corrmat_values = corr(d);

            % success
            success = true;
        end
    end
end

