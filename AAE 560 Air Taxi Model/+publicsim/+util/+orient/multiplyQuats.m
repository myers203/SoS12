function q = multiplyQuats(varargin)
% Multiplies quaternions in reverse order to produce successive quaternion rotation

assert(numel(varargin) >= 2)
q = varargin{end};
for i = numel(varargin) - 1:-1:1
    q = quatMult(q, varargin{i});
end

    function pq = quatMult(p, q)
%         pq = [p(1) * q(1) - p(2:4) * q(2:4)', ...
%             p(1) * q(2) + p(2) * q(1) - p(3) * q(4) + p(4) * q(3), ...
%             p(1) * q(3) + p(2) * q(4) + p(3) * q(1) - p(4) * q(2), ...
%             p(1) * q(4) - p(2) * q(3) + p(3) * q(2) + p(4) * q(1)];
        
        pq = [p(1) * q(1) - dot(p(2:4), q(2:4)), p(1) * q(2:4) + q(1) * p(2:4) + cross(p(2:4), q(2:4))];
    end

end

