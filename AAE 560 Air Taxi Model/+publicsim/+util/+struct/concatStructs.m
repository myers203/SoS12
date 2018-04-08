function newStruct = concatStructs(oldStruct, addStruct, catFunc)
%CONCATSTRUCTS Concatenates like fields of structs together. Default is
%horzcat, can specify third input as @vertcat(a, b)
if (nargin == 2)
    catFunc = @(a, b) horzcat(a, b);
else
    catFunc = eval(['@(a, b) ' catFunc '(a, b);']);
end

structFields = fields(oldStruct);
addStructFields = fields(addStruct);
if ~isequal(structFields, addStructFields)
    error('Structs must have the same fields to concatenate!');
end

for i = 1:numel(structFields)
    if isa(oldStruct.(structFields{i}), 'struct')
        newStruct.(structFields{i}) = publicsim.util.struct.concatStructs(oldStruct.(structFields{i}), addStruct.(structFields{i}));
    elseif isa(oldStruct.(structFields{i}), 'cell')
        for j = 1:numel(oldStruct.(structFields{i}))
            newStruct.(structFields{i}){j} = catFunc(oldStruct.(structFields{i}){j}, addStruct.(structFields{i}){j});
        end
    else
        newStruct.(structFields{i}) = catFunc(oldStruct.(structFields{i}), addStruct.(structFields{i}));
    end
end

end

