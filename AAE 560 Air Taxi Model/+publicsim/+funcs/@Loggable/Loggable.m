classdef Loggable < handle
    %LOGGABLE A function that can log
    %   
    % addFunctionLogEntry(logKey,logEntry)  logKey define any additional
    % key for the log, and logEntry is any data. To retreive, use the agent
    % name and the key value as [ class(function) '-' logKey], e.g.,:
    % publicsim.sim.Loggable.readParamsByClass(obj.logger, ...
    % 'publicsim.agents.functional.Sensing', ...
    % {['publicsim.funcs.sensors.Radar' '-' logKey]});
    %
    
    properties (Transient)
        logKeyPrefix=''
        logEntryFunctionHandle
        parentLoggable
    end
    
    methods
        
        function obj=Loggable()
        end
        
        function attachLoggableCallee(obj,callee)
            %Connect the parent callee with the function logs
            if ~isa(callee,'publicsim.sim.Loggable')
                return;
            end
            
            obj.logKeyPrefix=[class(obj) '-'];
            obj.logEntryFunctionHandle=@callee.addDefaultLogEntry;
        end
        
        function inheritLoggableParameters(obj,func)
                assert(isa(func,'publicsim.funcs.Loggable'),'Only for use with another loggable function');
                obj.parentLoggable=func;
        end
        
        function addFunctionLogEntry(obj,logKey,logEntry)
            if ~isempty(obj.logEntryFunctionHandle)
                obj.logEntryFunctionHandle([obj.logKeyPrefix logKey],logEntry);
            elseif ~isempty(obj.parentLoggable)
                obj.logKeyPrefix=[class(obj) '-'];
                obj.logEntryFunctionHandle=obj.parentLoggable.logEntryFunctionHandle;
                obj.logEntryFunctionHandle([obj.logKeyPrefix logKey],logEntry);
            end
        end
        
    end
    
end

