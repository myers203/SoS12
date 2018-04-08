classdef Memoizable < handle
    %MEMOIZABLE adds memoization
    
    properties (Access = private)
        memTable
    end
    
    methods
        
        function obj = Memoizable()
            obj.memTable = containers.Map();
        end
        
        function memoize(obj, data, key, varargin)
            if obj.memTable.isKey(key)
                warning('Already a key! This should not happen!');
            end
            obj.memTable(key) = data;
        end
        
        function [data, bool, key] = getMemoize(obj, varargin)
            data = [];
            % Get the call function name
            key = publicsim.funcs.basic.generateHash([obj.getParentFunction, varargin{:}]);
            
            bool = obj.memTable.isKey(key);
            if bool
                data = obj.memTable(key);
            end
        end
    end
    
    methods (Access = private)
        function parentFunction = getParentFunction(~)
            stackInfo = dbstack;
            parentFunction = stackInfo(3).name;
        end
    end
    
end

