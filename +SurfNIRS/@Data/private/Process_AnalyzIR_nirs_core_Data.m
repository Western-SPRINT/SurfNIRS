function Process_AnalyzIR_nirs_core_Data(obj, data)

    % must be a nirs.core.Data
    if ~isa(data, "nirs.core.Data")
        error("Error parsing nirs.core.Data. Incorrect format!")
    end

    % parse
    link_types_string = string(data.probe.link.type);
    obj.datatypes = unique(link_types_string)';
    obj.channels = unique(data.probe.link(:,["source" "detector"]), "rows");
    obj.sample_times = data.time;
    obj.sources = table(arrayfun(@(s) sprintf("S%d", s), 1:size(data.probe.srcPos,1))',data.probe.srcPos(:,1),data.probe.srcPos(:,2),VariableNames=["label" "x" "y"]);
    obj.detectors = table(arrayfun(@(s) sprintf("D%d", s), 1:size(data.probe.detPos,1))',data.probe.detPos(:,1),data.probe.detPos(:,2),VariableNames=["label" "x" "y"]);
    
    % organize data by channel/datatype
    for c = 1:obj.channels_count
        samples = nan(length(obj.sample_times),obj.datatypes_count);
        is_channel = data.probe.link.source==obj.channels.source(c) & data.probe.link.detector==obj.channels.detector(c);
        for dt = 1:obj.datatypes_count
            ind = find(is_channel & link_types_string==obj.datatypes(dt));
            % expect exactly one 
            if length(ind)~=1
                error("Error parsing nirs.core.Data. Did not find exactly one match for a channel-datatype pair.")
            end
            samples(:,dt) = data.data(:,ind);
        end
        obj.channels.data{c} = samples;
    end

end