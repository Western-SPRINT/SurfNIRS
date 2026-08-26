function [success] = Load_dotnirs(obj, private_inputs)
    % default to fail
    success = false;

    % stop if Homer_datatype was not set
    if ~isfield(private_inputs, "Homer_datatype")
        error(mfilename + ": missing value for ""Homer_datatype""")
    else
        Homer_datatype = private_inputs.Homer_datatype;
    end

    % load nirs file as mat
    file = load(obj.filepath, "-mat");

    % stop if need dod/dc and is unavailable, otherwise get data
    if any(Homer_datatype==["dod" "dc"])
        if ~isfield(file,"procResult") || isempty(file.procResult.(Homer_datatype))
            return
        end
    end

    % parse
    obj.channels = array2table(unique(file.SD.MeasList(:,[1 2]), "rows"), VariableNames=["source" "detector"]);
    obj.sample_times = file.t;
    obj.sources = table(arrayfun(@(s) sprintf("S%d", s), 1:size(file.SD.SrcPos,1))',file.SD.SrcPos(:,1),file.SD.SrcPos(:,2),VariableNames=["label" "x" "y"]);
    obj.detectors = table(arrayfun(@(s) sprintf("D%d", s), 1:size(file.SD.DetPos,1))',file.SD.DetPos(:,1),file.SD.DetPos(:,2),VariableNames=["label" "x" "y"]);

    % organize channel data
    switch Homer_datatype
        case {"d" "dod"}
            % wavelengths
            obj.datatypes = string(file.SD.Lambda);

            % select data
            if Homer_datatype=="d"
                data = file.d;
            else
                data = file.procResult.dod;
            end

            % organize data
            for c = 1:obj.channels_count
                samples = nan(length(obj.sample_times),obj.datatypes_count);
                is_channel = file.SD.MeasList(:,1)==obj.channels.source(c) & file.SD.MeasList(:,2)==obj.channels.detector(c);
                for dt = 1:obj.datatypes_count
                    ind = find(is_channel & file.SD.MeasList(:,4)==dt);
                    % expect exactly one 
                    if length(ind)~=1
                        error("Error parsing .nirs file. Did not find exactly one match for a channel-datatype pair.")
                    end
                    samples(:,dt) = data(:,ind);
                end
                obj.channels.data{c} = samples;
            end

        case "dc"
            % chromophores
            obj.datatypes = ["HbO" "HbR" "HbT"];

            % organize data
            for c = 1:obj.channels_count
                ind = find(file.SD.MeasList(:,1)==obj.channels.source(c) & file.SD.MeasList(:,2)==obj.channels.detector(c), 1);
                obj.channels.data{c} = file.procResult.dc(:,:,ind);
            end

        otherwise
            error("Unknown ""Homer_datatype"": %s", Homer_datatype)
    end
    
    % success
    success = true;
end