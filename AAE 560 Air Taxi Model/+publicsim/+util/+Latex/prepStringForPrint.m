function printString = prepStringForPrint(plainString)
%LATEXIFYSTRING Cleans up a plain string to work in Latex

% Basically just a whole bunch of find and replaces 

cleanList = { ...
    '\', '\\'; ...
    };

printString = '';

for i = 1:numel(plainString);
    index = find(strcmp(cleanList(:, 1), plainString(i)));
    if ~isempty(index)
        printString = [printString, cleanList{index, 2}]; %#ok
    else
        printString = [printString, plainString(i)]; %#ok
    end
end    

end

