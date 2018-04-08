classdef StudyOrchestrator < handle

    properties
        xlsModel
        analysis
        log
    end
    
    properties(Access=private)
        xlsFile
        analyzerType
        earth
    end
    
    properties (Constant)
        EARTH_MODEL_TYPE='elliptical'
    end
    
    methods
        
        function obj=StudyOrchestrator()

        end
        
        function initOrchestrator(obj)
            assert(~isempty(obj.xlsFile),'XLS File not populated!');
            obj.xlsModel = publicsim.models.excelBased.excelModelBuilder(obj.xlsFile);
        end
        
        function initAnalysis(obj)
            assert(~isempty(obj.analyzerType),'Analyzer type not populated!');
            assert(~isempty(obj.log),'Log is empty!');
            obj.analysis = eval(sprintf('%s(obj.log)',obj.analyzerType));
        end
        
        function initEarth(obj)
            earthModel=publicsim.util.Earth();
            earthModel.setModel(obj.EARTH_MODEL_TYPE); 
            obj.earth = earthModel;
        end
        
        function recordLog(obj)
            assert(~isempty(obj.xlsModel),'XLS Model has not been assigned!');
           obj.log=obj.xlsModel.getLogger(); 
        end
        
        function setXlsFile(obj,xlsFileName)
            assert(ischar(class(xlsFileName)),'XLS FILE TYPE MUST BE A STRING!');
            obj.xlsFile = xlsFileName;
        end
        
        function setAnalyzer(obj,analyzer)
            assert(ischar(class(analyzer)),'ANALYZER TYPE MUST BE A STRING!');
            obj.analyzerType = analyzer;
        end
        
        function refreshAnalyzer(obj)
           assert(~isempty(obj.log),'Cannot refresh analyzer.  Log must not be empty');
           obj.analysis = eval(sprintf('%s(obj.log)',obj.analyzerType));
        end

    end
    
end

