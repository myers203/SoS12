classdef Taskable < handle
    methods(Abstract)
        getTaskableStatus(sensorStatus,time);
        processTaskableCommand(time,command);
    end
end

