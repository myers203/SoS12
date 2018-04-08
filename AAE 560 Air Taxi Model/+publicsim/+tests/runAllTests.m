function allTestResults = runAllTests(varargin)

if (nargin == 1)
    dir = varargin{1};
else
    dir = '.';
end

import publicsim.*;

tester = tests.UniversalTester();
allTestResults = tester.runAllTests(dir);
end