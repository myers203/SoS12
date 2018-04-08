classdef Coordinator < handle
    %COORDINATOR Responds to requests for analyzer objects so that multiple
    %analyzers can be shared between different functions
    
    properties
        analyzers
    end
    
    methods
        function obj = Coordinator()
            obj.analyzers = containers.Map();
        end
        
        function analyzer = requestAnalyzer(obj, analyzerName, logger, varargin)
            assert(ischar(analyzerName), 'Analyzer name must be given as a string!');
            key = publicsim.funcs.basic.generateHash([analyzerName, varargin]);
            if obj.analyzers.isKey(key)
                analyzer = obj.analyzers(key);
            else
                try
                    analyzer = eval(sprintf('%s(logger, obj, varargin{:});', analyzerName));
                    if ~isa(analyzer, 'publicsim.analysis.CoordinatedAnalyzer')
                        warning('%s analyzer is not coordinated! Reconstructing...', analyzerName);
                        analyzer = eval(sprintf('%s(logger, varargin{:});', analyzerName));
                    end
                catch error
                    warning('Failed to create %s with coordinator input argument: %s', analyzerName, error.message);
                    analyzer = eval(sprintf('%s(logger, varargin{:});', analyzerName));
                    if ~isa(analyzer, 'publicsim.analysis.CoordinatedAnalyzer')
                        warning('%s analyzer is coordinated but does not support coordinator construction argument!', analyzerName);
                    else
                        warning('%s analyzer is not coordinated!', analyzerName);
                    end
                end
                obj.analyzers(key) = analyzer;
            end
        end
    end
    
end

