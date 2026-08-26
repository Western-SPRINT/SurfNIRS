classdef DataList < handle
    % Container for all Data. Also includes import and navigation functions.
    
    properties (SetAccess = private, GetAccess = public)
        List
        SelectedID = [];
    end

    properties ( Dependent )
        SelectedData
    end

    properties ( Constant, Access = private )
        DefaultList = table(Size=[0 8], ...
                            VariableNames=["sub" "task" "ses" "run" "step" "ID_acquisition" "ID_full" "Data"], ...
                            VariableTypes=[repmat("string",[1 7]) "SurfNIRS.Data"]);
    end

    
    methods
        function obj = DataList()
            obj.Initialize();
        end

        function Initialize(obj)
            obj.SelectedID = [];
            obj.List = obj.DefaultList;
        end

        function data = get.SelectedData(obj)
            data = obj.GetDataByID(obj.SelectedID);
        end

        %% Utilities

        function SelectFirst(obj)
            % Attempts to select until successful or all options are
            % exhausted
            arguments
                obj (1,1) SurfNIRS.DataList
            end

            obj.SelectedID = [];
            while ~isempty(obj.List) && isempty(obj.SelectedID)
                obj.SelectByID(obj.List.ID_full(1));
            end
        end

        function [success, removed] = SelectByID(obj, ID_full)
            % Attempts to set the selected acquisition-step by ID. Loads
            % the data if it has not yet been loaded. This will remove the
            % data if it fails to load.
            arguments
                obj (1,1) SurfNIRS.DataList
                ID_full (1,:) string {mustBeNonzeroLengthText}
            end

            % default to fail
            success = false;
            removed = false;

            % stop if already set
            if ~isempty(obj.SelectedID) && (ID_full == obj.SelectedID)
                return
            end
            
            % find
            ind = find(obj.List.ID_full == ID_full);
            if length(ind) ~= 1
                return
            end

            % load if needed
            if ~obj.List.Data(ind).loaded
                [loaded, removed] = LoadID(obj, ID_full);
                if ~loaded || removed
                    return
                end
            end

            % set
            obj.SelectedID = ID_full;
            success = true;
        end

        function data = GetDataByID(obj, ID_full)
            % Returns the SurfNIRS.Data object for the corresponding ID
            arguments
                obj (1,1) SurfNIRS.DataList
                ID_full (1,:) string {mustBeNonzeroLengthText}
            end
            % default to empty
            data = [];
            
            % find
            ind = find(obj.List.ID_full == ID_full);
            if length(ind) ~= 1
                return
            else
                data = obj.List.Data(ind);
            end
        end

        function [count_loaded, count_removed, count_loaded_total] = LoadAll(obj)
            % Attempt to load all non-loaded Data. Any that fail to load
            % will be removed.

            % init
            count_loaded = 0;
            count_removed = 0;
            count_loaded_total = 0;

            % process all non-loaded
            for r = height(obj.List) : -1 : 1
                if ~obj.List.Data(r).loaded
                    [loaded, removed] = LoadID(obj, obj.List.ID_full(r));
                    if loaded
                        count_loaded = count_loaded + 1;
                    elseif removed
                        count_removed = count_removed + 1;
                    end
                end
            end

            % count remaining
            count_loaded_total = height(obj.List);
        end

        function [loaded, removed] = LoadID(obj, ID_full)
            % Attempt to load the specified non-loaded entry. Removed upon
            % failure. Returns true if already loaded.
            arguments
                obj (1,1) SurfNIRS.DataList
                ID_full (1,:) string {mustBeNonzeroLengthText}
            end

            % default to fail
            loaded = false;
            removed = false;
            
            % find by ID
            ind = find(obj.List.ID_full == ID_full);
            if length(ind) ~= 1
                return
            end

            % try to load
            success = obj.List.Data(ind).Load;
            if ~success
                obj.List(ind,:) = [];
                removed = true;
            else
                loaded = true;
            end
        end

        %% Import - Public Methods
        
        function count = ImportMulti_AnalyzIR_nirs_core_Data(obj, filepaths)
            % Import one or more .mat files containing a AnalyzIR nirs.core.Data
            arguments
                obj (1,1) SurfNIRS.DataList
                filepaths (1,:) string {mustBeFile}
            end

            % init
            count = 0;

            % stop if AnalyzIR is not available
            if ~SurfNIRS.misc.check_AnalyzIR
                return
            end

            count = sum( arrayfun(@(x) obj.ImportFile_AnalyzIR_nirs_core_Data(x, "auto", label="auto"), filepaths) );
        end

        function count = ImportMulti_AnalyzIR_raw_NIRx(obj, filepaths)
            % Import one or more sets of .wl* files containing a raw NIRx data
            arguments
                obj (1,1) SurfNIRS.DataList
                filepaths (1,:) string {mustBeFile}
            end

            % init
            count = 0;

            % stop if AnalyzIR is not available
            if ~SurfNIRS.misc.check_AnalyzIR
                return
            end

            count = sum( arrayfun(@obj.ImportFile_AnalyzIR_raw_NIRx, filepaths) );
        end

        function count = ImportBIDS_AnalyzIR_nirs_core_Data(obj, folder)
            % Import AnalyzIR nirs.core.Data from a folder containing files
            % name sub-SUB_ses-SES_task-TASK_run-RUN_STEP.mat
            arguments
                obj (1,1) SurfNIRS.DataList
                folder (1,1) string {mustBeFolder}
            end

            % init
            count = 0;

            % stop if AnalyzIR is not available
            if ~SurfNIRS.misc.check_AnalyzIR
                return
            end

            % find .mat files with BIDS naming
            list = dir(fullfile(folder, "**", "sub-*_ses-*_task-*_run-*_*.mat"));

            % parse BIDS info
            file_info = arrayfun(@(x) regexp(x.name, "(?<sub>sub-\w+)_(?<ses>ses-\w+)_(?<task>task-\w+)_(?<run>run-[a-zA-Z0-9-]+)_(?<step>.+).mat", "names"), list);
            if isempty(file_info)
                return
            end
            file_info = struct2table(file_info);
            file_info.sub = cellfun(@string, file_info.sub);
            file_info.ses = cellfun(@string, file_info.ses);
            file_info.run = cellfun(@string, file_info.run);
            file_info.task = cellfun(@string, file_info.task);
            file_info.step = cellfun(@string, file_info.step);
            file_info.filename = string({list.name})';
            file_info.filepath = arrayfun(@(x) string([x.folder filesep x.name]), list);

            % run
            count = sum( arrayfun(@(f) obj.ImportFile_AnalyzIR_nirs_core_Data(f.filepath, f.step, sub=f.sub, task=f.task, ses=f.ses, run=f.run) , table2struct(file_info)) );
        end

        function count = ImportMulti_dotnirs(obj, filepaths)
            % Import one or more .nirs files (raw or Homer2)
            arguments
                obj (1,1) SurfNIRS.DataList
                filepaths (1,:) string {mustBeFile}
            end

            % add d
            count = sum( arrayfun(@(x) obj.ImportFile_dotnirs(x, "auto", "d", label="auto"), filepaths) );

            % add dod/dc if found in first file
            file = load(filepaths(1), "-mat");
            if isfield(file, "procResult")
                for dt = ["dod" "dc"]
                    if ~isempty(file.procResult.(dt))
                        count = count + sum( arrayfun(@(x) obj.ImportFile_dotnirs(x, "auto", dt, label="auto"), filepaths) );
                    end
                end
            end
        end

        function count = ImportBIDS_dotnirs(obj, folder)
            % Import .nirs (raw or Homer2) from a folder containing files
            % name sub-SUB_ses-SES_task-TASK_run-RUN_STEP.nirs

            arguments
                obj (1,1) SurfNIRS.DataList
                folder (1,1) string {mustBeFolder}
            end

            % find .mat files with BIDS naming
            list = dir(fullfile(folder, "**", "sub-*_ses-*_task-*_run-*_*.nirs"));

            % parse BIDS info
            file_info = arrayfun(@(x) regexp(x.name, "(?<sub>sub-\w+)_(?<ses>ses-\w+)_(?<task>task-\w+)_(?<run>run-[a-zA-Z0-9-]+)_(?<step>.+).nirs", "names"), list);
            if isempty(file_info)
                return
            end
            file_info = struct2table(file_info);
            file_info.sub = cellfun(@string, file_info.sub);
            file_info.ses = cellfun(@string, file_info.ses);
            file_info.run = cellfun(@string, file_info.run);
            file_info.task = cellfun(@string, file_info.task);
            file_info.step = cellfun(@string, file_info.step);
            file_info.filename = string({list.name})';
            file_info.filepath = arrayfun(@(x) string([x.folder filesep x.name]), list);

            % add d
            count = sum( arrayfun(@(f) obj.ImportFile_dotnirs(f.filepath, f.step, "d", sub=f.sub, task=f.task, ses=f.ses, run=f.run) , table2struct(file_info)) );

            % add dod/dc if found in first file
            file = load(file_info.filepath(1), "-mat");
            if isfield(file, "procResult")
                for dt = ["dod" "dc"]
                    if ~isempty(file.procResult.(dt))
                        switch dt
                            case "dod"
                                step_suffix = "_OD";
                            case "dc"
                                step_suffix = "_OD_Hb";
                            otherwise
                                step_suffix = "";
                        end
                        count = count + sum( arrayfun(@(f) obj.ImportFile_dotnirs(f.filepath, f.step+step_suffix, dt, sub=f.sub, task=f.task, ses=f.ses, run=f.run) , table2struct(file_info)) );
                    end
                end
            end
        end

        function count = ImportProject_Homer3_groupResults(obj, filepath)
            % Imports all files in a Homer3 project as outlined by the
            % groupResults file

            arguments
                obj (1,1) SurfNIRS.DataList
                filepath (1,1) string {mustBeFile}
            end

            % init
            count = 0;

            % stop if Homer3 is not available
            if ~SurfNIRS.misc.check_Homer3
                return
            end

            % load groupResults
            file = load(filepath);
            var_names = string(fields(file));
            ind = find(arrayfun(@(f) isa(file.(f), "GroupClass"), var_names), 1);
            if isempty(ind)
                % no valid object
                return
            else
                % select first element of first "nirs.core.Data"
                group = file.(var_names(ind))(1);
            end

            % add...
            task = "Homer3";
            has_dod = false;
            has_dc = true;
            for sub_ind = 1:length(group.subjs)
                sub = group.subjs(sub_ind).name;

                for ses_ind = 1:length(group.subjs(sub_ind).sess)
                    ses = group.subjs(sub_ind).sess(ses_ind).name;

                    for run_ind = 1:length(group.subjs(sub_ind).sess(ses_ind).runs)
                        run = group.subjs(sub_ind).sess(ses_ind).runs(run_ind).name;

                        % if first, look for dod and dc
                        if sub_ind==1 && ses_ind==1 && run_ind==1
                            group.subjs(sub_ind).sess(ses_ind).runs(run_ind).LoadDerivedData;
                            has_dod = ~isempty(group.subjs(sub_ind).sess(ses_ind).runs(run_ind).procStream.output.dod);
                            has_dc = ~isempty(group.subjs(sub_ind).sess(ses_ind).runs(run_ind).procStream.output.dc);
                        end

                        % add d
                        count = count + obj.ImportFile_Homer3_groupResults(filepath, "raw", "d", sub=sub, task=task, ses=ses, run=run);

                        % add dod
                        if has_dod
                            count = count + obj.ImportFile_Homer3_groupResults(filepath, "raw_OD", "dod", sub=sub, task=task, ses=ses, run=run);
                        end

                        % add dc
                        if has_dc
                            count = count + obj.ImportFile_Homer3_groupResults(filepath, "raw_OD_Hb", "dc", sub=sub, task=task, ses=ses, run=run);
                        end
                    end
                end
            end
        end
    end

    %% Private Methods

    methods ( Access = private )
        function success = AddEntry(obj, data)
            % Add a Data object to the list (unless duplicate)

            % default to fail
            success = false;

            % determine IDs
            ID_acquisition = data.sub + "_" + data.task + "_" + data.ses + "_" + data.run; 
            ID_full = ID_acquisition + "_" + data.step;

            % stop if already added
            if any(obj.List.ID_full == ID_full)
                return
            end

            % add to list
            obj.List(end+1,["sub" "task" "ses" "run" "step" "ID_acquisition" "ID_full" "Data"]) = {data.sub
                                                                                                   data.task
                                                                                                   data.ses
                                                                                                   data.run
                                                                                                   data.step
                                                                                                   ID_acquisition
                                                                                                   ID_full
                                                                                                   data
                                                                                                   }';

            % resort list
            obj.Sort;

            % success
            success = true;
        end

        function Sort(obj)
            obj.List = sortrows(obj.List,["sub" "task" "ses" "run" "step"]);
        end

        %% Import - Private Methods (single file)

        function success = ImportFile_AnalyzIR_raw_NIRx(obj, filepath)
            % Import a set of .wl* files containing raw NIRx
            arguments
                obj (1,1) SurfNIRS.DataList
                filepath (1,1) string {mustBeFile}
            end

            % default to fail
            success = false;

            % stop if AnalyzIR is not available
            if ~SurfNIRS.misc.check_AnalyzIR
                return
            end

            % stop if filetype is unexpected
            [~,filename,filetype] = fileparts(filepath);
            if ~strcmpi(filetype, ".wl1")
                return
            end

            % use filename as label
            step = filename;
            description.label = filename;

            % create Data object
            opts = namedargs2cell(description);
            data = SurfNIRS.Data("Load_AnalyzIR_raw_NIRx", filepath, step, opts{:});

            % add
            success = obj.AddEntry(data);
        end

        function success = ImportFile_AnalyzIR_nirs_core_Data(obj, filepath, step, description)
            % Import a .mat file containing a AnalyzIR nirs.core.Data
            arguments
                obj (1,1) SurfNIRS.DataList
                filepath (1,1) string {mustBeFile}
                step (1,1) string {mustBeNonzeroLengthText} = "auto"
                description.sub (1,1) string {mustBeNonzeroLengthText}
                description.task (1,1) string {mustBeNonzeroLengthText}
                description.ses (1,1) string {mustBeNonzeroLengthText}
                description.run (1,1) string {mustBeNonzeroLengthText}
                description.label (1,1) string {mustBeNonzeroLengthText}
            end

            % default to fail
            success = false;

            % stop if AnalyzIR is not available
            if ~SurfNIRS.misc.check_AnalyzIR
                return
            end

            % stop if filetype is unexpected
            [~,filename,filetype] = fileparts(filepath);
            if ~strcmpi(filetype, ".mat")
                return
            end

            % auto-named step? label?
            if step == "auto"
                step = filename;
            end
            if isfield(description, "label") && description.label == "auto"
                description.label = filename;
            end

            % create Data object
            opts = namedargs2cell(description);
            data = SurfNIRS.Data("Load_AnalyzIR_nirs_core_Data", filepath, step, opts{:});

            % add
            success = obj.AddEntry(data);
        end

        function success = ImportFile_dotnirs(obj, filepath, step, datatype, description)
            % Import a .nirs file (raw or Homer2)
            arguments
                obj (1,1) SurfNIRS.DataList
                filepath (1,1) string {mustBeFile}
                step (1,1) string {mustBeNonzeroLengthText} = "auto"
                datatype (1,1) string {mustBeMember(datatype,["d" "dod" "dc"])} = "d"
                description.sub (1,1) string {mustBeNonzeroLengthText}
                description.task (1,1) string {mustBeNonzeroLengthText}
                description.ses (1,1) string {mustBeNonzeroLengthText}
                description.run (1,1) string {mustBeNonzeroLengthText}
                description.label (1,1) string {mustBeNonzeroLengthText}
            end

            % default to fail
            success = false;

            % stop if filetype is unexpected
            [~,filename,filetype] = fileparts(filepath);
            if ~strcmpi(filetype, ".nirs")
                return
            end

            % auto-named step?
            if step == "auto"
                step = filename;

                switch datatype
                    case "d"
                        %no change
                    case "dod"
                        step = step + "_OD";
                    case "dc"
                        step = step + "_OD_Hb";
                    otherwise
                        error("Unsupported datatype: %s", datatype)
                end
            end
			if isfield(description, "label") && description.label == "auto"
                description.label = filename + step;
            end

            % create Data object
            opts = namedargs2cell(description);
            opts = [opts "Homer_datatype" datatype];
            data = SurfNIRS.Data("Load_dotnirs", filepath, step, opts{:});

            % add
            success = obj.AddEntry(data);
        end

        function success = ImportFile_Homer3_groupResults(obj, filepath, step, datatype, description)
            % Import from a Homer3 groupResults file
            arguments
                obj (1,1) SurfNIRS.DataList
                filepath (1,1) string {mustBeFile}
                step (1,1) string {mustBeNonzeroLengthText} = "auto"
                datatype (1,1) string {mustBeMember(datatype,["d" "dod" "dc"])} = "d"
                description.sub (1,1) string {mustBeNonzeroLengthText}
                description.task (1,1) string {mustBeNonzeroLengthText}
                description.ses (1,1) string {mustBeNonzeroLengthText}
                description.run (1,1) string {mustBeNonzeroLengthText}
                description.label (1,1) string {mustBeNonzeroLengthText}
            end

            % default to fail
            success = false;

            % stop if Homer3 is not available
            if ~SurfNIRS.misc.check_Homer3
                return
            end

            % stop if filetype is unexpected
            [~,filename,filetype] = fileparts(filepath);
            if ~strcmpi(filetype, ".mat")
                return
            end

            % auto-named step?
            if step == "auto"
                step = filename;

                switch datatype
                    case "d"
                        %no change
                    case "dod"
                        step = step + "_OD";
                    case "dc"
                        step = step + "_OD_Hb";
                    otherwise
                        error("Unsupported datatype: %s", datatype)
                end
            end
			if isfield(description, "label") && description.label == "auto"
                description.label = filename + step;
            end

            % create Data object
            opts = namedargs2cell(description);
            opts = [opts "Homer_datatype" datatype];
            data = SurfNIRS.Data("Load_Homer3_groupResults", filepath, step, opts{:});

            % add
            success = obj.AddEntry(data);
        end
    end

end

