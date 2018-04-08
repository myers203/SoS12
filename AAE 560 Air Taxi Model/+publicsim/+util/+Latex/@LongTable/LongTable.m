classdef LongTable < soda.util.latex.Tabular
    
    methods
        
        function addHeader(obj, data)
            % Makes a header row that is bolded with an underline
            obj.addRow(data, 'thead');
            obj.addRowRaw({'\hline'});
        end
        
        function texPrefix = getPrefix(obj)
            texPrefix{4} = ['\begin{longtable}{ ', repmat('c ', 1, obj.numCols), '}'];
        end
        
        function saveTable(obj, path, name, saveFlag)
            % Saves the table as a tex file
            % Super
            
            if ~exist('saveFlag','var') || ~saveFlag % manage the saving in case we don't want to overwrite.
                return
            end
            
            saveTable@soda.util.latex.Tabular(obj, path, name);
            
            fullPath = [path, filesep(), 'longTableFormat', '.tex'];
            fid = fopen(fullPath, 'w+');
            formatCells = {'\usepackage{booktabs}', ...
                '\usepackage{longtable}', ...
                '\newcommand*{\thead}[1]{\multicolumn{1}{c}{\bfseries\begin{tabular}{@{}c@{}}#1\end{tabular}}}'};
            obj.writeCellsToFile(fid, formatCells);
            fclose(fid);
            fprintf('Wrote LaTeX format file to %s\n', fullPath);
%             warning('Must include format file in master LaTeX document before ''\begin{document}'' statement!');
        end
        
    end
    
    methods (Static)
        function formattedData = thead(data)
            % Makes the row bolded
            formattedData = cell(size(data));
            for i = 1:numel(data)
                formattedData{i} = ['\thead{', data{i}, '}'];
            end
        end
        
        function texSuffix = getSuffix()
            texSuffix{1} = '\end{longtable}';
        end
        
    end
    
end

