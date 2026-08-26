classdef SessionInfo < handle
    % Central location for all SurfNIRS session info
    
    properties ( SetAccess = private, GetAccess = public )
        app
        Data
        Navigation
        Draw
        LastImportFolder = string([pwd filesep])
    end

    properties ( Hidden )
        debug = false;
    end

    methods
        function obj = SessionInfo(app)
            obj.app = app;
            obj.Data = SurfNIRS.DataList;
            obj.Navigation = SurfNIRS.modules.Navigation(obj);
            obj.Draw = SurfNIRS.modules.Draw(obj);
        end

        function SetLastImportFolder(obj, folder)
            % Set folder to begin next search in

            arguments
                obj (1,1) SurfNIRS.SessionInfo
                folder (1,1) string
            end

            % end with filesep
            if ~folder.endsWith(filesep)
                folder = folder + filesep;
            end

            % set
            obj.LastImportFolder = folder;
        end
    end

end

