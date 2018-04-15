function results = runModel_new(input_file,port_file,runNum,simSeconds)
    import publicsim.*;
    global globalWeather     
    
    % Parse Data Input File
    [~,~,params] = xlsread(input_file,'params');
    portConfig = params{runNum+1,11};
    [~,~,portData] = xlsread(port_file,portConfig);

    simTimes.startTime = 0;
    simTimes.endTime   = simSeconds; % equivalent min
                               % 1 Sim s = 1 actual min
    logPath            = strcat('./tmp/run',num2str(runNum),'example_model');
    simInst            = publicsim.sim.Instance(logPath);
    
    % User input parsing
    n_aircraft    = params{runNum+1,2} + params{runNum+1,3};
    n_ports       = size(portData,1)-1;

    % Add weather to the simulation
    globalWeather = airtaxi.agents.Weather();
    simInst.AddCallee(globalWeather);

    % Add operator to the simulation
    operator = airtaxi.agents.Operator();
    simInst.AddCallee(operator);

    % Set up Aircraft agents
    acAgents = cell(1,n_aircraft);
    for i=1:n_aircraft
        ac = airtaxi.agents.Aircraft();
        acAgents{i} = ac;
        operator.addChild(ac);
    end
    
    % Set up Port agents
    portAgents = cell(1,n_ports);
    for i=1:n_ports
        port = airtaxi.agents.Port();
        portAgents{i} = port;
        operator.addChild(port);
    end
    
    % Parse the user input file and assign the attributes to the agents
    airtaxi.models.SoS12.setupScenario(input_file,port_file,runNum, ...
        acAgents,portAgents,operator,globalWeather);

    % Run simulation
    simInst.runUntil(simTimes.startTime,simTimes.endTime);
    
    % Parse data logs
    duration = simTimes.endTime - simTimes.startTime;
    parsed_data = airtaxi.funcs.parseLogs(logPath,acAgents,portAgents,duration);
    
    % Postprocessing
    results = airtaxi.models.SoS12.processData(parsed_data,acAgents,portAgents,operator,runNum);
end
