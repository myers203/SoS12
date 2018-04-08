classdef UniversalTester < handle
    %UNIVERSALTEST Base class for test functions
    properties (Constant, Access = private)
        key_fail = 0;
        key_pass = 1;
        key_DNE = -1;
        key_noTest = -2;
        
        key_icon_none = 3;
        key_icon_green = 1;
        key_icon_yellow = 2;
        key_icon_red = 0;
        key_icon_X = -1;
        key_icon_noTest = -2;
    end
    
    properties
        completeResults % Used for passing all the results between functions
    end
    
    methods
        function resultList = runAllTests(obj, varargin)
            % Remember which figures were open before these tests were run
            protectedFigures = get(0, 'children');
            % Get all class names in the specified or current directory
            if isempty(varargin)
                directory = '.';
            else
                directory = varargin{1};
            end
            
            % Get all classes in the directory
            if isa(directory, 'cell')
                directory = sort(directory);
                info = [];
                for i = 1:numel(directory)
                    info = [info, obj.dirinfo(directory{i})]; %#ok
                end
            else
                info = obj.dirinfo(directory);
            end
            
            fullClasses = vertcat(info.fullClasses);
            for i=1:numel(fullClasses)
                tmpVar=fullClasses{i};
                tmpVar(1)=[];
                tmpVar=strrep(tmpVar,'\+','.');
                tmpVar=strrep(tmpVar,'\','.');
                if tmpVar(1)=='.'
                    tmpVar(1)=[];
                end
                fullClasses{i}=tmpVar;
            end
            
            if(isempty(fullClasses))
                fprintf('\nNo classes found in this directory.\n');
                return;
            end
            
            allFullClasses = fullClasses;
            
            resultList = [];
            % Run all tests for each class that defines a test
            for i = 1:numel(allFullClasses)
                results = obj.getTestStruct();
                try
                    metaObj = eval(['?', allFullClasses{i}]);
                    testMethodIndex = find(strcmp('test', {metaObj.MethodList.Name}));
                catch
                    fprintf('Could not get test info for class %s\n', allFullClasses{i});
                    parent = which(allFullClasses{i});
                    parent = parent(numel(pwd) + 2:end);
                    results.parent = parent;
                    results.name = 'Could not get test info';
                    results.result = obj.key_DNE; % Test not defined
                    
                    resultList = [resultList, results];%#ok
                    continue;
                end
                % Base case (did not define a test)
                parent = which(metaObj.Name);
                parent = parent(numel(pwd) + 2:end);
                results.parent = parent;
                results.name = '<No Tests Found>';
                results.result = obj.key_noTest; % Test not defined
                if ~isempty(testMethodIndex)
                    
                    % Should only ever have one method called 'test', but let's just be sure
                    if numel(testMethodIndex == 1)
                        % Make sure this is the defining class of the test
                        % method
                        if strcmp(metaObj.MethodList(testMethodIndex).DefiningClass.Name, metaObj.Name)
                            % Make sure we have access to the method
                            if ~isempty(metaObj.MethodList(testMethodIndex).Access)
                                if isa(metaObj.MethodList(testMethodIndex).Access, 'cell') % It should be if inheriting from  UniversalTester
                                    if find(any(strcmp(class(obj), metaObj.MethodList(testMethodIndex).Access{:}.Name)))
                                        try
                                            % Get list of tests to run from
                                            % the class
                                            tests = eval([metaObj.Name, '.test']);
                                            % Run all the tests and collect
                                            % results
                                            for j = 1:numel(tests)
                                                % The parent name is the
                                                % parent of the called
                                                % function, which could be
                                                % different than the parent
                                                % that passed the function
                                                % name
                                                parentName = strsplit(tests{j}, '.');
                                                parentName = parentName(1:end - 1);
                                                trueParentName = parentName{1};
                                                for k = 2:numel(parentName)
                                                    trueParentName = strcat(trueParentName, '.', parentName{k});
                                                end
                                                
                                                try
                                                    eval(tests{j});
                                                    newResult = obj.generateTestStruct(1, trueParentName, tests{j});
                                                catch err
                                                    newResult = obj.generateTestStruct(0, trueParentName, tests{j}, err);
                                                end
                                                
                                                if (j == 1)
                                                    results = obj.addResult(newResult);
                                                else
                                                    results = obj.addResult(newResult, results);
                                                end
                                                
                                                if (strcmp(trueParentName, metaObj.Name) ~= 1)
                                                    % True parent is different than the passer, let's record that
                                                    psuedoResult = obj.generateTestStruct(newResult.result, metaObj.Name, tests{j}, ['   Located in ', trueParentName]);
                                                    results = obj.addResult(psuedoResult, results);
                                                end
                                            end
                                        catch err
                                            parent = which(metaObj.Name);
                                            parent = parent(numel(pwd) + 2:end);
                                            results.parent = parent;
                                            results.name = 'Failed to Execute';
                                            results.result = obj.key_DNE;
                                            results.info = err;
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
                clearvars('metaObj');
                % Append to results list
                try
                    resultList = [resultList, results];%#ok
                catch
                    fprintf('Error parsing results for %s\n', allFullClasses{i});
                end
            end
            
            % Filter out any classes that did not return any tests but
            % contained called test functions
            i = 0;
            while i < numel(resultList)
                i = i + 1;
                % Get all tests with the same parent
                idxs = find(strcmp(resultList(i).parent, {resultList.parent}));
                if (numel(idxs) == 1)
                    % Move to next if there's only one test
                    continue;
                end
                
                for j = 1:numel(idxs)
                    if resultList(idxs(j)).result == obj.key_noTest
                        % Other tests exist for parent, should remove test
                        resultList = [resultList(1:idxs(j) - 1), resultList(idxs(j) + 1:end)];
                        i = i - 1;
                        break;
                    end
                end
            end
            
            obj.completeResults = resultList;
            
            % Close all figures that were created by running the tests
            allFigures = get(0, 'children');
            for i = 1:numel(allFigures)
                shouldClose = 1;
                for j = 1:numel(protectedFigures)
                    if (allFigures(i) == protectedFigures(j))
                        shouldClose = 0;
                        continue;
                    end
                end
                if (shouldClose)
                    close(allFigures(i));
                end
            end
            
            if (numel(resultList) > 0)
                obj.showTestResults(resultList);
            end
            
            pass = sum([resultList.result] == obj.key_pass);
            fail = sum([resultList.result] == obj.key_fail);
            dne = sum([resultList.result] == obj.key_DNE);
            missing = sum([resultList.result] == obj.key_noTest);
            
            fprintf('%d classes found, %d tests found for %d classes\n', numel(allFullClasses), (pass + fail + dne), numel(allFullClasses) - missing);
            fprintf('Passed: %d\nFailed: %d\nDNE: %d\nMissing: %d\n', pass, fail, dne, missing);
            
            
        end
        
        
        function showTestResults(obj, results)
            % Show the test results in an expandable tree
            root = uitreenode('v0', 'Project', 'Project', [], false);
            branches = {}; % List of all branches
            branchMap = containers.Map('KeyType', 'char', 'ValueType', 'any');
            
            
            % Load icons
            folderPath = which(class(obj));
            folderPath = folderPath(1:(end - numel(mfilename) - 2));
            folderPath = [folderPath, 'icons\'];
            icon_green = java.awt.Toolkit.getDefaultToolkit.createImage([folderPath, 'icon-green.gif']);
            icon_yellow = java.awt.Toolkit.getDefaultToolkit.createImage([folderPath, 'icon-yellow.gif']);
            icon_red = java.awt.Toolkit.getDefaultToolkit.createImage([folderPath, 'icon-red.gif']);
            icon_X = java.awt.Toolkit.getDefaultToolkit.createImage([folderPath, 'icon-X.gif']);
            icon_noTest = java.awt.Toolkit.getDefaultToolkit.createImage([folderPath, 'icon-noTest.gif']);
            
            
            % Parse all parents of the results to create branches. Record
            % failures
            failures = {};
            for i = 1:numel(results)
                splitParent = strsplit(results(i).parent, '\');
                for j = 1:numel(splitParent)
                    if ~any(strcmp(strcat(splitParent{1:j}), branchMap.keys))
                        nextInd = numel(branches) + 1;
                        branches{nextInd} = uitreenode('v0', splitParent{j}, splitParent{j}, [], false);%#ok
                        value = struct('branchInd', nextInd, 'iconType', obj.key_icon_none);
                        branchMap(strcat(splitParent{1:j})) =  value;
                        if (j > 1)
                            parent = branchMap(strcat(splitParent{1:j - 1}));
                            branches{parent.branchInd}.add(branches{nextInd});
                        else
                            root.add(branches{nextInd});
                        end
                    end
                end
                
                test = uitreenode('v0', results(i).name, results(i).name, [], true);
                switch results(i).result
                    case obj.key_fail
                        test.setIcon(icon_red);
                        failures{end + 1} = {splitParent};%#ok
                    case obj.key_pass
                        test.setIcon(icon_green);
                    case obj.key_DNE
                        test.setIcon(icon_X);
                        failures{end + 1} = {splitParent};%#ok
                    case obj.key_noTest
                        test.setIcon(icon_noTest);
                end
                parentName = strrep(results(i).parent, '\', '');
                parent = branchMap(parentName);
                oldIconType = parent.iconType;
                switch parent.iconType
                    case 3
                        parent.iconType = results(i).result;
                    case obj.key_pass % Green (All passing)
                        if results(i).result ~= 1 % Failed
                            parent.iconType = 2; % Yellow
                        end
                    case {obj.key_fail, obj.key_DNE} % Red (All failing)
                        if results(i).result == 1 % Passed
                            parent.iconType = obj.key_icon_yellow; % Yellow
                        end
                end
                branchMap(parentName) = parent;
                
                
                if (oldIconType ~= parent.iconType)
                    % Update everything above the parent as well
                    fullName = strsplit(results(i).parent, '\');
                    for j = 1:(numel(fullName) - 1)
                        didChange = 0;
                        upParentName = strcat(fullName{1:end - j});
                        childName = strcat(fullName{1:end - j + 1});
                        upParent = branchMap(upParentName);
                        child = branchMap(childName);
                        switch upParent.iconType
                            case 3
                                upParent.iconType = child.iconType;
                                didChange = 1;
                            case obj.key_pass % Green (All passing)
                                if child.iconType ~= 1 % Failed or partially failing
                                    upParent.iconType = obj.key_icon_yellow; % Yellow
                                    didChange = 1;
                                end
                            case obj.key_fail % Red (All failing)
                                if child.iconType == 1 % Passed
                                    upParent.iconType = obj.key_icon_yellow; % Yellow
                                    didChange = 1;
                                end
                            case obj.key_noTest % No test
                                if child.iconType ~= -2
                                    upParent.iconType = obj.key_icon_yellow;
                                    didChange = 1;
                                end
                        end
                        if ~didChange
                            break;
                        end
                        branchMap(upParentName) = upParent;
                    end
                end
                
                branches{parent.branchInd}.add(test);
            end
            
            
            % Update all icon colors
            
            allKeys = branchMap.keys;
            for i = 1:numel(allKeys)
                value = branchMap(allKeys{i});
                branch = branches{value.branchInd};
                switch value.iconType
                    case obj.key_icon_green % Green
                        branch.setIcon(icon_green);
                    case obj.key_icon_yellow % Yellow
                        branch.setIcon(icon_yellow);
                    case obj.key_icon_red % Red
                        branch.setIcon(icon_red);
                    case obj.key_icon_X % X (Failed to run)
                        branch.setIcon(icon_X);
                    case obj.key_icon_noTest % ? (No test)
                        branch.setIcon(icon_noTest);
                end
                
            end
            
            figure('Name', ['Test Results, ', char(datetime('now'))], 'NumberTitle', 'off');
            mtree = uitree('v0', 'Root', root);
            mtree.Position(3) = 550;
            % Expand at least the base level
            mtree.expand(root);
            
            % Expand to any failing tests
            for i = 1:numel(failures)
                splitPath = failures{i};
                splitPath = splitPath{1};
                for j = 1:numel(splitPath)
                    value = branchMap(strcat(splitPath{1:j}));
                    branch = branches{value.branchInd};
                    mtree.expand(branch);
                end
            end
            
            % Create right-click menu
            jmenu = javax.swing.JPopupMenu;
            hTree = handle(mtree.getTree, 'CallbackProperties');
            set(hTree, 'MousePressedCallback', {@publicsim.tests.UniversalTester.mousePressedCallback, jmenu, obj.completeResults});
        end
        
        
        function info = dirinfo(obj, directory)
            %Recursively generate an array of structures holding information about each
            %directory/subdirectory beginning, (and including) the initially specified
            %parent directory.
            info = what(directory);
            info.fullClasses=cell(numel(info.classes),1);
            for i=1:numel(info.classes)
                info.fullClasses{i}=[directory '\' info.classes{i}];
            end
            flist = dir(directory);
            dlist =  {flist([flist.isdir]).name};
            for i=1:numel(dlist)
                dirname = dlist{i};
                if(~strcmp(dirname,'.') && ~strcmp(dirname,'..'))
                    info = [info, obj.dirinfo([directory,'\',dirname])];%#ok
                end
            end
        end
    end
    
    methods (Static, Access = {?publicsim.tests.UniversalTester})
        function tests = test()
            % Nothing to test here, just make sure a test works
            tests = {};
        end
    end
    
    methods (Static)
        function mousePressedCallback(hTree, eventData, jmenu, completeResults)
            % Many thanks to Yair at: http://undocumentedmatlab.com/blog/adding-context-menu-to-uitree
            if eventData.isMetaDown  % right-click is like a Meta-button
                % Get the clicked node
                clickX = eventData.getX;
                clickY = eventData.getY;
                jtree = eventData.getSource;
                treePath = jtree.getPathForLocation(clickX, clickY);
                try
                    % Modify the context menu or some other element
                    % based on the clicked node. Here is an example:
                    fullPath = '';
                    funcName = '';
                    for i = 1:(treePath.getPathCount - 1) % Java indexing, start at 0 (but not really b/c throwing away the root)
                        node = treePath.getPathComponent(i);
                        name = strsplit(char(node.getName), ':');
                        if ~node.isLeaf % Not a function
                            if ~isempty(fullPath)
                                fullPath = [fullPath, '\']; %#ok
                            end
                            fullPath = [fullPath, name{end}]; %#ok
                        else
                            funcName = name{end};
                            % Get rid of trailing parenthesis
                            funcName = strsplit(funcName, '()');
                            funcName = funcName{1};
                        end
                    end
                    
                    % Allow opening if it's a file for function in a file
                    jmenu.removeAll();
                    if (exist(fullPath, 'file') == 2)
                        className = strsplit(fullPath, '\');
                        className = className{end};
                        className = className(1:end - 2);
                        if isempty(funcName) || (strcmp(funcName, 'Failed to Execute') == 1)
                            menuItem1 = javax.swing.JMenuItem(['Open ', className, '.m']);
                            set(menuItem1, 'ActionPerformedCallback', {@publicsim.tests.UniversalTester.openMenuItem, fullPath});
                        else
                            menuItem1 = javax.swing.JMenuItem(['Open ', className, '.', funcName]);
                            set(menuItem1, 'ActionPerformedCallback', {@publicsim.tests.UniversalTester.openMenuItem, fullPath, funcName});
                        end
                        % Add the open button
                        jmenu.add(menuItem1);
                        
                        % Now search for info about the selected test bn
                        for i = 1:numel(completeResults)
                            if (strcmp(fullPath, completeResults(i).parent) == 1)
                                testName = strsplit(completeResults(i).name, '()');
                                testName = testName{1};
                                if ~isempty(funcName)
                                    if (strcmp(funcName, testName) ~= 1)
                                        continue;
                                    end
                                end
                                % Add whatever information in subtests
                                
                                switch completeResults(i).result;
                                    case publicsim.tests.UniversalTester.key_fail
                                        testResult = 'Failed';
                                    case publicsim.tests.UniversalTester.key_pass
                                        testResult = 'Passed';
                                    case publicsim.tests.UniversalTester.key_DNE
                                        testResult = 'Did not execute';
                                    case publicsim.tests.UniversalTester.key_noTest
                                        testResult = 'No tests found';
                                end
                                
                                jmenu.add(sprintf('%s: %s\n', testName, testResult));
                                if ~isempty(completeResults(i).info);
                                    if isa(completeResults(i).info, 'char')
                                        jmenu.add(completeResults(i).info);
                                    else
                                        message = completeResults(i).info.message;
                                        lastFunction = completeResults(i).info.stack(1).name;
                                        lineNumber = completeResults(i).info.stack(1).line;
                                        file = completeResults(i).info.stack(1).file;
                                        
                                        menuItemError = javax.swing.JMenuItem(sprintf('    Error: %s: %s, line %d\n', message, lastFunction, lineNumber));
                                        set(menuItemError, 'ActionPerformedCallback', {@publicsim.tests.UniversalTester.openMenuItem, file, lineNumber});
                                        
                                        jmenu.add(menuItemError);
                                    end
                                end
                                
                            end
                        end
                    end
                    
                    % remember to call jmenu.remove(item) in item callback
                    % or use the timer hack shown here to remove the item:
                    %
                catch
                    % clicked location is NOT on top of any node
                    % Note: can also be tested by isempty(treePath)
                end
                
                % Display the (possibly-modified) context menu
                jmenu.show(jtree, clickX, clickY);
                jmenu.repaint;
            end
        end
        
        function openMenuItem(hObj,eventData,fullPath, varargin)
            % Verify this is the full path
            if isempty(strfind(fullPath, pwd))
                % Append the pwd to the path
                fullPath = [pwd, '/', fullPath];
            end
            
            if isempty(varargin) % Just open the file
                edit(fullPath);
            else
                if isa(varargin{1}, 'double')
                    % Open to line number
                    lineNum = varargin{1};
                    matlab.desktop.editor.openAndGoToLine(fullPath, lineNum);
                elseif isa(varargin{1}, 'char')
                    % Open to function
                    funcName = varargin{1};
                    matlab.desktop.editor.openAndGoToFunction(fullPath, funcName);
                end
            end
        end
        
        function removeMenuItem(hObj,eventData,jmenu,item)
            jmenu.remove(item);
        end
        
        function newTest = generateTestStruct(result, parentName, testName, varargin)
            newTest = publicsim.tests.UniversalTester.getTestStruct();
            newTest.parent = which(parentName);
            newTest.parent = newTest.parent(numel(pwd) + 2:end);
            newTest.name = strsplit(testName, '.');
            newTest.name = newTest.name{end};
            newTest.result = result;
            if ~isempty(varargin)
                newTest.info = varargin{1};
            else
                newTest.info = [];
            end
        end
        
        function blankResult = getTestStruct()
            blankResult = struct();
            blankResult.parent = '';
            blankResult.name = '';
            blankResult.result = [];
            blankResult.info = [];
        end
        
        
        function generateLatexList(results, fileName, varargin)
            % Generates a list in Latex of the tests run
            
            % Required inputs:
            % results: Struct array of results, returned by runAllTests()
            % fileName: String of the desired text file name
            
            % Optional inputs (pairs):
            % showResults: Display pass/fail/DNE for the tests
            % showTestDescription: Displays the 'help' info of the test
            
            
            
            % First, filter results to only those classes that had tests
            results = results([results.result] ~= -2); % Does this look stupid enough?
            
            % Sort alphabetically by parent name
            [~, indexList] = sort({results.parent});
            results = results(indexList);
            
            fh = fopen(fileName, 'wt');
            assert(fh ~= -1, 'File creation failed!');
            
            % Set up the list
            fprintf(fh, '\\setlistdepth{20}\n');
            fprintf(fh, '\\newlist{testList}{itemize}{20}\n');
            for i = 1:20
                fprintf(fh, '\\setlist[testList,%d]{label=\\textbullet}\n', i);
            end
            
            % Print out the list
            publicsim.tests.UniversalTester.printLatexSubList(results, fh, '', varargin{:});
        end
        
        function printLatexSubList(results, fh, parent, varargin)
            % Prints all results sub the parent to the file handle
            
            np = inputParser;
            np.addParameter('showResults', 0, @isnumeric);
            np.addParameter('showTestDescription', 0, @isnumeric);
            np.parse(varargin{:});
            
            if ~isempty(parent)
                assert(numel(results) == numel(publicsim.tests.UniversalTester.getChildren(results, parent)), 'Broken parent!');
            end
            
            fprintf(fh, '\\begin{testList}[noitemsep]\n');
            
            if strcmp(results(1).parent, parent) == 1
                % Parent is self, we can print here
                splits = strsplit(parent, '\');
                
                classCall = strrep(parent(1:end - numel(splits{end}) - 1), '\', '.');
                classCall = strrep(classCall, '@', '');
                classCall = strrep(classCall, '+', '');
                for i = 1:numel(results)
                    testName = results(i).name;
                    if strcmp(testName(end - 1:end), '()') == 0
                        testName = [testName, '()'];
                    end
                    
                    if np.Results.showResults
                        switch results(i).result
                            case publicsim.tests.UniversalTester.key_fail
                                resultText = 'Failed';
                            case publicsim.tests.UniversalTester.key_pass
                                resultText = 'Passed';
                            case publicsim.tests.UniversalTester.key_noTest
                                resultText = 'No Test';
                            case publicsim.tests.UniversalTester.key_DNE
                                resultText = 'Did Not Execute';
                            otherwise
                                resultText = 'Unrecognized Result!';
                        end
                        
                        testName = [testName, ': ', resultText];
                    end
                       
                    fprintf(fh, ['\\item{\\textbf{', publicsim.util.Latex.latexifyString(testName), '}}\n']);
                    
                    if np.Results.showTestDescription
                        helpText = help([classCall, '.', results(i).name]);
                        helpSplit = strsplit(helpText, '\n');
                        helpText = strtrim(helpSplit{1});
                        if ~isempty(helpText)
                            fprintf(fh, '\\begin{testList}[noitemsep]\n');
                            fprintf(fh, '\\item{\\textit{%s}}\n', publicsim.util.Latex.latexifyString(helpText));
                            fprintf(fh, '\\end{testList}\n');
                        end
                    end
                    
                end
            else
                
                
                printedResults = zeros(1, numel(results)); % Flags if the results at the index have been printed
                while ~all(printedResults)
                    
                    % Get the next result to be printed
                    nextIndex = find(~printedResults, 1, 'first'); % Ensures alphabetical
                    
                    partialParent = results(nextIndex).parent(numel(parent) + 1:end);
                    parentSplits = strsplit(partialParent, '\');
                    newParent = [parent, parentSplits{1}];
                    if numel(parentSplits) ~= 1
                        newParent = [newParent, '\']; %#ok
                    end
                    
                    fprintf(fh, ['\\item{', publicsim.util.Latex.latexifyString(parentSplits{1}), '}\n']);
                    
                    [children, iters] = publicsim.tests.UniversalTester.getChildren(results, newParent);
                    assert(numel(children) ~= 0, 'Error getting children!');
                    publicsim.tests.UniversalTester.printLatexSubList(children, fh, newParent, varargin{:});
                    printedResults(iters) = 1;
                end
                
                
            end
            
            fprintf(fh, '\\end{testList}\n');
        end
        
        
        
        function [children, indicies] = getChildren(results, parent)
            iter = 0;
            for i = 1:numel(results)
                if strfind(results(i).parent, parent) == 1
                    iter = iter + 1;
                    children(iter) = results(i);
                    indicies(iter) = i;
                end
            end
            
            if iter == 0
                children = [];
                indicies = [];
            end
        end
        
        
        
        % Really simply append to list if it already exists. This is just
        % to make future changes to how this works much more contained
        function results = addResult(newResult, varargin)
            if isempty(varargin)
                results = newResult;
            else
                results = varargin{1};
                results(end + 1) = newResult;
            end
        end
        
        function testFolderPath = getTestDataFolderPath(className)
            classPath = which(className);
            classPath = regexp(classPath, '^.*\\', 'match');
            classPath = classPath{1};
            
            testFolderPath = [classPath, 'testData'];
        end
    end
    
end

