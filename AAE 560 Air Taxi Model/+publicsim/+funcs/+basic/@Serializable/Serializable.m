classdef Serializable < handle 
    %SERIALIZABLE converts all public properties into an object
    %   Detailed explanation goes here
    
    properties
    end
    
    methods
        
        function obj=Serializable()
        end
        
        function output=serialize(obj)
            dataObject=[];
            proplist=properties(obj);
            for i=1:numel(proplist)
                dataObject.(proplist{i})=obj.(proplist{i});
            end
            output=getByteStreamFromArray(dataObject);
        end
        
        function deserialize(obj,input)
            dataObject=getArrayFromByteStream(input);
            proplist=fields(dataObject);
            for i=1:numel(proplist)
                obj.(proplist{i})=dataObject.(proplist{i});
            end
        end
        
    end
    
    methods(Static)
        

        
    end
    
end

