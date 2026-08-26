function success = Load_AnalyzIR_nirs_core_Data(obj, ~)
    % default to fail
    success = false;

    % stop if AnalyzIR is not available
    if ~SurfNIRS.misc.check_AnalyzIR
        return
    end

    % load file
    data = nirs.io.loadNIRx(obj.filepath.char);
    
    % parse
    Process_AnalyzIR_nirs_core_Data(obj, data);
    
    % success
    success = true;
end