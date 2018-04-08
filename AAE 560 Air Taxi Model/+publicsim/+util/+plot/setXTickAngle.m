function setXTickAngle(angle)
% Matlab version-safe setting of X tick angle

v = version('-release');
vYear = regexp(v, '\d+', 'match');
vYear = str2double(vYear{1});
assert(vYear >= 2016, 'Must have Matlab version 2016a or higher!');

if vYear > 2016
    xtickangle(angle)
else
    set(gca, 'XTickLabelRotation', angle);
end

end

