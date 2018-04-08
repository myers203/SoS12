classdef MapManager < handle
    %Database Generic database for storing and updating information.
    
    properties
    end
    
    properties (SetAccess=immutable)
        map
    end
        
    methods
        function obj = MapManager()
            obj.map = containers.Map('KeyType','double','ValueType','any');
        end
        
        function updateMap(obj,key,varargin)
            
            if ~obj.map.isKey(key)
               obj.newEntry(key,varargin);
            else
                do_update = obj.checkUpdate(key,varargin);
                
                if do_update
                    obj.valueUpdate(key, varargin);
                end
                
            end
            
        end
        
        function do_update = checkUpdate(obj,key,varargin) %#ok<INUSD>
            % useful if we are doing updates based on receive time or
            % similar.
            do_update = true;
        end
        
        function newEntry(obj,key,varargin)
            value = varargin{1};
            obj.map(key)=value;
        end
        
        function valueUpdate(obj, key, varargin)
            new_value = varargin{1};
            % this might be overkill for values which are themselves
            % classes, but it will be important for structures,
            % arrays, and so on.
            obj.map(key) = new_value;
        end
        
        
    end
    
    methods (Static)
        function mapManagerTest()
            %TODO
            
            disp('Passed MapManager Test!');
        end
    end
    
end

