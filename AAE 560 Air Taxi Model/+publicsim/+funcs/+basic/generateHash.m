function key = generateHash(varargin)
hashEngine = java.security.MessageDigest.getInstance('MD5');
hashEngine = buildHashEngine(hashEngine, varargin{:});
key = sprintf('%.2x', typecast(hashEngine.digest(), 'uint8'));
end

function hashEngine = buildHashEngine(hashEngine, varargin)
for i = 1:numel(varargin)
    switch class(varargin{i})
        case 'double'
            hashEngine.update(typecast(varargin{i}, 'uint8'));
        case {'char', 'logical'}
            hashEngine.update(typecast(double(varargin{i}), 'uint8'));
        case 'cell'
            buildHashEngine(hashEngine, varargin{i}{:});
        case 'struct'
            data = struct2cell(varargin{i});
            buildHashEngine(hashEngine, data{:});
        otherwise
            fprintf('Using bytestream for data of class %s\n', class(varargin{i}));
            hashEngine.update(getByteStreamFromArray(varargin{i}));
    end
end
end
