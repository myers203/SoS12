classdef TrackDatabase < publicsim.funcs.databases.MapManager
    
    properties
        filter_type
        %noise = [1,1,1];
        world
    end
    
    properties(SetAccess=private)
        do_doppler
    end
    
    methods
        function obj = TrackDatabase(filter_type)
            obj.filter_type = filter_type;
            % e.g., filter_type = 'publicsim.funcs.trackers.BasicKalman(3)';
            obj.checkDoDoppler();
        end
        
        function setWorldModel(obj,world)
            obj.world=world;
        end
        
        function checkDoDoppler(obj)
            % Intend to do some switching on the filter names to know whether or not the kalman filter should take in velocity information.
            % For now, let's just assume they don't.
            obj.do_doppler = 0;
        end
        
        %         function updateMap(obj,key, measurement, time)
        %            obj@publicsim.funcs.databases.MapManager.updateMap(obj, key, measurement, time); % is it worth doing this to be explicit?
        %         end
        
        
        function newEntry(obj,key,obsData)
            
            if any(isnan(obsData{1}.measurements))
                return;
            end
            
            %             measurement = varargin{1}{1};
            %             time = varargin{1}{2};  % Measurement time
            new_filter = eval(obj.filter_type);
            
            new_filter.setWorldModel(obj.world);
            
            %             if ~obj.do_doppler
            %                measurement = measurement(1:3);
            %             end
            
            new_filter.initByObs(obsData{1}); %note, this measurement is the ECEF first location;
            
            obj.map(key) = new_filter;
        end
        
        function valueUpdate(obj,key,obsData)
            
            %If we are sorting out doppler here, then this code is
            %relevant, otherwise, it's being done filter side.
            % %             measurement = obsData{1}.measurements;
            % % %             measurement = varargin{1}{1};
            % %             if any(isnan(measurement))
            % %                 return;
            % %             end
            % % %             time = varargin{1}{2};
            % % %             noise = varargin{1}{3};
            % %             filter = obj.map(key);
            % %
            % %             if ~obj.do_doppler
            % %                 measurement = measurement(1:3);
            % % %                 noise = noise(1:3);
            % %             end

            if any(isnan(obsData{1}.measurements))
                return;
            end
            filter = obj.map(key);
            filter.addObservation(obsData{1});
            
        end
        
        function do_update = checkUpdate(obj,key,obsData)
            
            time = obsData{1}.time;
            %             time = varargin{1}{2};
            filter = obj.map(key);
            
            do_update = time >= filter.t;
            
            if ~do_update
                warning('Out of order measurements!');
            end
        end
        
        function [output,keyList]=serialize(obj)
            keyList=keys(obj.map);
            output=cell(numel(keyList),1);
            for i=1:numel(keyList)
                to=obj.map(keyList{i});
                output{i}={keyList{i},to.serialize()};
            end
        end
        
        function tfilter=deserialize(obj,input)
            for i=1:numel(input)
                dataIn=input{i};
                key=dataIn{1};
                val=dataIn{2}; %#ok<NASGU>
                tfilter=eval([obj.filter_type '.deserialize(val)']);
                obj.map(key)=tfilter;
            end
        end
        
        
    end
    
end

