classdef inputParser < inputParser & dynamicprops
    %INPUTPARSER Backwards-compatible version of the input parser for 2013a
    
    properties (Access = private)
        matlabVersion
    end
    
    methods
        function obj = inputParser()
            obj@inputParser;
            obj.matlabVersion = version();
            
            % Find the generic year/letter revision
            [startInd, endInd] = regexp(obj.matlabVersion, ...
                '(?<=\()(.*?)(?=\))');
            genericVersion = obj.matlabVersion(startInd:endInd);
            switch genericVersion
                case 'R2013a'
                    obj.addprop('addParameter');
                    obj.addParameter = @(varargin) obj.addParamValue(varargin{:});
            end
        end
    end
    
end

