function success = Load_AnalyzIR_nirs_core_Data(obj, ~)
    % default to fail
    success = false;

    % stop if AnalyzIR is not available
    if ~SurfNIRS.misc.check_AnalyzIR
        return
    end

    % load file
    file = load(obj.filepath);

    % select first "nirs.core.Data"
    var_names = string(fields(file));
    ind = find(arrayfun(@(f) isa(file.(f), "nirs.core.Data"), var_names), 1);
    if isempty(ind)
        % no valid object
        return
    else
        % select first element of first "nirs.core.Data"
        data = file.(var_names(ind))(1);
    end
    
    % parse
    Process_AnalyzIR_nirs_core_Data(obj, data);
    
    % success
    success = true;
end