classdef ObservableInspector < handle
    %OBSERVABLEINSPECTOR is a class to provide direct access to an
    %observable manager.
    
    properties
        observableObjectManager
    end
    
    methods
        function obj=ObservableInspector()
        end
        
        function setObservableManager(obj,observableObjectManager)
            %sets the observable manager
            obj.observableObjectManager=observableObjectManager;
        end
    end
    
end

