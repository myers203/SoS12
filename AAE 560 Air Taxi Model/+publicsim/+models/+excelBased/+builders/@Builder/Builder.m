classdef Builder < handle
    
    properties(Access=protected)
        sheetData
    end
    
    methods
        
        function obj=Builder()
        end
        
        function data=findColumnDataByLabel(obj,label)
            data={};
            columnNames=obj.sheetData(1,:);
            for i=1:numel(columnNames)
                if isequal(columnNames{i},label)
                    data=obj.sheetData(2:end,i);
                    return;
                end
            end
        end
    end
    
    methods(Abstract)
        parse(obj,sheetData);
    end
    
    methods(Static)
        function entry=findEntryByName(data,name)
            for i=1:numel(data)
                if isequal(data{i}.name,name)
                    entry=data{i};
                    return;
                end
            end
            entry=[];
        end
        
        function array=splitCSVToArray(csvString)
            if isempty(csvString) || any(isnan(csvString))
                array=[];
                return;
            end
            if ~ischar(csvString)
                array=csvString;
                return;
            end
            entries=strsplit(csvString,',');
            array=zeros(numel(entries),1);
            for i=1:numel(entries)
                array(i)=str2num(entries{i}); %#ok<ST2NM>
            end
        end
    end
    
end

