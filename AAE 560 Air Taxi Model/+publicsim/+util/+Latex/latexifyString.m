function latexString = latexifyString(plainString, varargin)
%LATEXIFYSTRING Cleans up a plain string to work in Latex

np = inputParser;
np.addParameter('specToFile', 1, @isnumeric);

np.parse(varargin{:});

% Basically just a whole bunch of find and replaces 

cleanList = { ...
    '^', '\textasciicirum'; ...
    '~', '\textasciitilde'; ...
    '*', '\textastriskcentered'; ...
    '\', '\textbackslack'; ...
    '|', '\textbar'; ...
    '{', '\textbraceleft'; ...
    '}', '\textbraceright'; ...
    '$', '\textdollar'; ...
    '-', '\textendash'; ...
    '>', '\textgreater'; ...
    '<', '\textless'; ...
    '_', '\textunderscore'};


latexString = '';

if np.Results.specToFile
    mod = '\';
else
    mod = '';
end

for i = 1:numel(plainString);
    index = find(strcmp(cleanList(:, 1), plainString(i)));
    if ~isempty(index)
        latexString = [latexString, mod, cleanList{index, 2}, ' ']; %#ok
    else
        latexString = [latexString, plainString(i)]; %#ok
    end
end    

end

