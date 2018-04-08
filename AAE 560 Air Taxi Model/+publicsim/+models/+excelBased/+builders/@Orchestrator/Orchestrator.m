classdef Orchestrator < publicsim.models.excelBased.builders.Builder
    
    properties
        startTime
        endTime
        logPath
        earthModel
    end
    
    properties(Access=private,Constant)
        START_TIME_COLUMN='Start Time';
        END_TIME_COLUMN='End Time';
        END_CONDITION_COLUMN='End Condition';
        LOG_PATH_COLUMN='Log Path';
        EARTH_MODEL_COLUMN='Earth Model';
    end
    
    methods
        function obj=Orchestrator()
        end
        
        function parse(obj,sheetData)
            obj.sheetData=sheetData;
            obj.getStartEndTimes();
            obj.getLogPath();
            obj.getEarthModel();
        end
        
        function getEarthModel(obj)
            earthModels=obj.findColumnDataByLabel(obj.EARTH_MODEL_COLUMN);
            obj.earthModel=earthModels{1};
        end
        
        function getLogPath(obj)
            logPaths=obj.findColumnDataByLabel(obj.LOG_PATH_COLUMN);
            obj.logPath=logPaths{1};
        end
        
        function getStartEndTimes(obj)
            startTimes=obj.findColumnDataByLabel(obj.START_TIME_COLUMN);
            obj.startTime=startTimes{1};
            endTimes=obj.findColumnDataByLabel(obj.END_TIME_COLUMN);
            obj.endTime=endTimes{1};
            assert(obj.endTime>=obj.startTime,'Only positive-time conditions are allowed currently.');
        end
        
        function setEndTime(obj,endTime)
            obj.endTime=endTime;
        end
        
    end
    
end

