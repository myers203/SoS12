function [simRuns] = runAll(~)
    %RUNALL Summary of this function goes here
    %   Detailed explanation goes here
    tic
    input_file = '+airtaxi/Inputs.xlsx';
    port_file = '+airtaxi/PortLocations.xlsx';
    output_file = '+airtaxi/output.xlsx';
    speed_scale_factor = 1/5;

    % parse run data
    [~,~,runs] = xlsread(input_file,'runs');

    startRun = runs{1,2};
    stopRun = runs{2,2};
    simSeconds = runs{3,2};
    
    % Error Checking
    if isnumeric(startRun) && isnumeric(stopRun)
        [~,~,params] = xlsread(input_file,'params');
        if ~isnumeric(params{startRun+1,1}) || ~isnumeric(params{stopRun+1,1})
            disp('Start and Stop Run IDs do not match sheet "params"');
            return;
        end
    end
    
    % Error Checking
    if ~isnumeric(simSeconds)
        disp('Sim Time should be an integer value.');
        return;
    end
    
    numRuns = stopRun-startRun+1;

    results = cell(numRuns+1,9);
    try
        % test to see if we can write to the file
        xlswrite(output_file,[1]);
    catch ME
        disp('File is locked, please close.');
        disp('Press F5 to continue.');
        keyboard
    end
    
    if exist(output_file,'file') > 0
        disp(['Existing file "', output_file, '" will be deleted.']);
        disp('Change the file name if you want to keep it.');
        disp('Press F5 to continue.');
        keyboard
        delete(output_file);
    end
    
    % First row of results is header row
    results(1,:) = {'Run_ID','fatal human', 'fatal auto', ...
       'non-fatal human', 'non-fatal auto', ...
       'total flight time on-trip', 'total flight time enroute', ...
       'vertiport caused', 'avg dist btween ports'};
    
    % Check for Parallel Processing
    runParallel = license('test','Distrib_Computing_Toolbox');

    % Comment out this line to run in parallel mode

    %runParallel = false;

    if runParallel
        for i = 1:numRuns
            F(i) = parfeval(@airtaxi.models.SoS12.runModel_new,1, ...
                input_file,port_file,startRun+i-1,simSeconds, ...
                speed_scale_factor);
        end
        
        % Build a waitbar to track progress
        h = waitbar(0,['Waiting for ', num2str(numRuns), ' runs to complete...']);        
        
        for i = 1:numRuns
            [completedIdx, r] = fetchNext(F);
            results(completedIdx+1,:) = r;
            waitbar(i/numRuns,h,sprintf('%d / %d runs completed.',i,numRuns));
        end
        delete(h);
    else
        for i=1:numRuns
            results(i+1,:) = airtaxi.models.SoS12.runModel_new( ...
                input_file,port_file,startRun+i-1,simSeconds, ...
                speed_scale_factor);
        end
    end
    
    % Write outputs to file
    xlswrite(output_file,results);
   toc 
end



% j = cell(4,1);
% for i=1:4
%     j{i} = batch(@airtaxi.models.example_model.runModel_new,2,{i});
% end
% 
% for i=1:4
%     wait(j{i})
%     r = fetchOutputs(j{i});
%     disp(['Trial ' num2str(i) ': Fatal: ' num2str(r{1}) ]);
%     disp(['Trial ' num2str(i) ': Non-Fatal: ' num2str(r{2}) ]);
% end
