classdef Tabular < handle
    %TABULAR Easily create Latex tables. Each class instance is a table
    
    properties
        texCell = {}; % 2-D cell array to build into a Latex table
        numRows = 0;
        decimalDepth = 3; % Number of decimals shown. Default is 2, universally. Can be set to an array for a decimal depth per column
    end
    
    properties (SetAccess = private)
        numCols = 0;
    end
    
    methods
        function addRow(obj, data, varargin)
            % Add a row of data to the table.
            % Inputs:
            % - obj: Tabular object
            % - data: 1-D cell array of desired data. Numbers will
            % automatically be converted to strings
            % - varargin: Optional argument(s). TODO: make format specifier
            % functions
            
            assert(~isempty(data), 'No data provided for the row!');
            assert(isa(data, 'cell'), 'Input must be a 1-D cell array!');
            obj.numRows = obj.numRows + 1;
            
            obj.numCols = max(obj.numCols, numel(data));
            data = obj.cleanData(data);
            
            if ~isempty(varargin)
                formattedData = obj.processRowFormat(data, varargin{:});
            else
                formattedData = data;
            end
            
            obj.texCell{obj.numRows, 1} = ''; % Initialize as empty string
            for i = 1:numel(data)
                if i == numel(data)
                    suffix = ' \\';
                else
                    suffix = ' & ';
                end
                obj.texCell{obj.numRows} = [obj.texCell{obj.numRows}, formattedData{i}, suffix];
            end
        end
        
        function addRowRaw(obj, data)
            obj.numRows = obj.numRows + 1;
            obj.texCell{obj.numRows} = '';
            for i = 1:numel(data)
                obj.texCell{obj.numRows, 1} = [obj.texCell{obj.numRows}, data{i}];
            end
        end
        
        function cleanData = cleanData(obj, data)
            % Cleans up the input so nothing is lost in Latex translation
            % Also cleans up numbers
            cleanData = cell(size(data));
            for i = 1:numel(data)
                if isa(data{i}, 'numeric')
                    if numel(obj.decimalDepth) >= numel(data)
                        cleanData{i} = sprintf(['%0.', num2str(obj.decimalDepth(i)), 'f'], data{i});
                    else
                        cleanData{i} = sprintf(['%0.', num2str(obj.decimalDepth(1)), 'f'], data{i});
                    end
                else
                    cleanData{i} = data{i};
                end
            end
        end
        
        function formattedData = processRowFormat(obj, data, varargin)
            % Formats the data
            for i = 1:numel(varargin)
                if ~ismethod(obj, varargin{i})
                    % Not a method, custom per-column format
                    % TODO: actually do this
                else
                    formattedData = obj.(varargin{i})(data);
                end
            end
        end
        
        function addHeader(obj, data)
            % Makes a header row that is bolded with an underline
            obj.addRow(data, 'bold');
            obj.addRowRaw('\hline');
        end
        
        function saveTable(obj, path, name)
            % Saves the table as a tex file
            fullPath = [path, filesep(), name, '.tex'];
            fid = fopen(fullPath, 'w+');
            obj.writeCellsToFile(fid, obj.getPrefix());
            obj.writeCellsToFile(fid, obj.texCell);
            obj.writeCellsToFile(fid, obj.getSuffix());
            fclose(fid);
            fprintf('Wrote LaTeX table to %s\n', fullPath);
        end
        
    end
    
    methods (Static)% Row format specifier functions
        
        
        function formattedData = bold(data)
            % Makes the row bolded
            formattedData = cell(size(data));
            for i = 1:numel(data)
                formattedData{i} = ['\textbf{', data{i}, '}'];
            end
        end
        
        function formattedData = boldFirst(data)
            % Makes the first column bolded
            formattedData = data;
            if numel(formattedData) >= 1
                formattedData{1} = ['\textbf{', data{1}, '}'];
            end
        end
        
        function texPrefix = getPrefix(obj)
            texPrefix{1} = '\begin{center}';
            texPrefix{2} = ['\begin{tabular}{ ', repmat('c ', 1, obj.numCols), '}'];
        end
        
        function writeCellsToFile(fid, cells)
            for i = 1:numel(cells)
                fprintf(fid, [soda.util.latex.prepStringForPrint(cells{i}) ,'\n']);
            end
        end
        
        function texSuffix = getSuffix()
            texSuffix{1} = '\end{tabular}';
            texSuffix{2} = '\end{center}';
        end
        
    end
end
    
