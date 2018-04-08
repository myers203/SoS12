function bool = fastIsMember(testVals, testStruct)
%FASTISMEMBER Drastically faster ismember() function for checking if field
%names in testVals exist in testStruct
if isa(testStruct, 'struct')
    knownVals = fieldnames(testStruct);
else
    knownVals = testStruct;
end
% Accept a single string for comparison or cell array of strings
if isa(testVals, 'cell')
    bool = zeros(1, numel(testVals));
    for i = 1:numel(testVals)
        bool(i) = any(strcmp(testVals{i}, knownVals));
    end
else
    bool = any(strcmp(testVals, knownVals));
end

end

