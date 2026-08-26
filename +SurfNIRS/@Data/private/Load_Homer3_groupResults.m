function [success] = Load_Homer3_groupResults(obj, private_inputs)
    % default to fail
    success = false;
    
    % stop if Homer3 is not on the path
    if ~SurfNIRS.misc.check_Homer3
        return
    end

    % stop if Homer_datatype was not set
    if ~isfield(private_inputs, "Homer_datatype")
        error(mfilename + ": missing value for ""Homer_datatype""")
    else
        Homer_datatype = private_inputs.Homer_datatype;
    end

    % load groupResult or get preloaded
    persistent groupResults
    if isempty(groupResults)
        groupResults = dictionary;
    end
    if groupResults.numEntries && groupResults.isKey(obj.filepath)
        % fetch previously loaded
        group = groupResults(obj.filepath);
    else
        % load
        file = load(obj.filepath);

        % find GroupClass
        var_names = string(fields(file));
        ind = find(arrayfun(@(f) isa(file.(f), "GroupClass"), var_names), 1);
        if isempty(ind)
            % no valid object
            return
        else
            % select first element of first "nirs.core.Data"
            group = file.(var_names(ind))(1);
        end

        % store for next file
        groupResults(obj.filepath) = group;
    end

    % find run
    ind_sub = find(private_inputs.description_original.sub == arrayfun(@(x) string(x.name), group.subjs));
    if length(ind_sub) ~= 1, return; end
    ind_ses = find(private_inputs.description_original.ses == arrayfun(@(x) string(x.name), group.subjs(ind_sub).sess));
    if length(ind_ses) ~= 1, return; end
    ind_run = find(private_inputs.description_original.run == arrayfun(@(x) string(x.name), group.subjs(ind_sub).sess(ind_ses).runs));
    if length(ind_run) ~= 1, return; end
    run = group.subjs(ind_sub).sess(ind_ses).runs(ind_run);

    % track number loaded
    persistent load_counts
    if isempty(load_counts)
        load_counts = dictionary;
    end
    if ~load_counts.numEntries || ~load_counts.isKey(obj.filepath)
        load_counts(obj.filepath) = 0;
    end

    % load raw data
    load_counts(obj.filepath) = load_counts(obj.filepath) + 1;
    if isempty(run.acquired.data)
        run.LoadAcquiredData;
    end
    
    % parse - montage
    obj.sources = table(arrayfun(@(s) sprintf("S%d", s), 1:size(run.acquired.probe.sourcePos2D,1))',run.acquired.probe.sourcePos2D(:,1),run.acquired.probe.sourcePos2D(:,2),VariableNames=["label" "x" "y"]);
    obj.detectors = table(arrayfun(@(s) sprintf("D%d", s), 1:size(run.acquired.probe.detectorPos2D,1))',run.acquired.probe.detectorPos2D(:,1),run.acquired.probe.detectorPos2D(:,2),VariableNames=["label" "x" "y"]);

    % parse - by datatype
    switch Homer_datatype
        case "d"
            obj.datatypes = string(run.acquired.probe.wavelengths');
            data = run.acquired.data;
            datatype_inds = [data.measurementList.wavelengthIndex]';
        case {"dod" "dc"}
            % load processed if not already available
            if isempty(run.procStream.output.(Homer_datatype))
                run.LoadDerivedData;
            end
            data = run.procStream.output.(Homer_datatype);
            if Homer_datatype == "dod"
                obj.datatypes = string(run.acquired.probe.wavelengths');
                datatype_inds = [data.measurementList.wavelengthIndex]';
            else
                obj.datatypes = string(unique({data.measurementList.dataTypeLabel}));
                datatype_inds = cellfun(@(x) find(strcmp(x,obj.datatypes)), {data.measurementList.dataTypeLabel})';
            end
        otherwise
            error("Unknown ""Homer_datatype"": %s", Homer_datatype)
    end

    % finish parse
    obj.sample_times = data.time;
    signals_source = [data.measurementList.sourceIndex]';
    signals_detector = [data.measurementList.detectorIndex]';
    obj.channels = array2table(unique([signals_source signals_detector], 'rows'), VariableNames=["source" "detector"]);
    
    % organize channdel data
    for c = 1:obj.channels_count
        samples = nan(length(obj.sample_times),obj.datatypes_count);
        is_channel = signals_source==obj.channels.source(c) & signals_detector==obj.channels.detector(c);
        for dt = 1:obj.datatypes_count
            ind = find(is_channel & datatype_inds==dt);
            % expect exactly one 
            if length(ind)~=1
                error("Error parsing Homer3 data. Did not find exactly one match for a channel-datatype pair.")
            end
            samples(:,dt) = data.dataTimeSeries(:,ind);
        end
        obj.channels.data{c} = samples;
    end


    % cleanup after ever 30 runs loaded
    if load_counts(obj.filepath) >= 30
        group.FreeMemoryRecursive;
        load_counts(obj.filepath) = 0;
    end

    % success
    success = true;
end