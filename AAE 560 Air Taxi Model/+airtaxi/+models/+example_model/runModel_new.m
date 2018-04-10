function runModel_new(~)
    import publicsim.*;
    
    simTimes.startTime = 0;
    simTimes.endTime   = 500; % equivalent min
                               % 1 Sim s = 1 actual min
    logPath            = './tmp/example_model';
    simInst            = publicsim.sim.Instance(logPath);

    % User input parsing
    input_file = "+airtaxi/sample_inputs.xlsx";
    [~,~,user_input] = xlsread(input_file);
    
    n_aircraft    = user_input{10,2};
    n_ports       = user_input{13,2};
    operator_info = user_input(1:4,2);
    
    % Add operator to the simulation
    operator = airtaxi.agents.Operator(operator_info);
    simInst.AddCallee(operator);

    % Set up Aircraft agents
    acAgents = cell(1,n_aircraft);
    for i=1:n_aircraft
        ac = airtaxi.agents.Aircraft(n_ports);
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
    airtaxi.models.example_model.setupScenario(input_file,user_input,acAgents,portAgents,operator);

    % Run simulation
    simInst.runUntil(simTimes.startTime,simTimes.endTime);
    
    % Parse data logs
    duration = simTimes.endTime - simTimes.startTime;
    parsed_data = airtaxi.funcs.parseLogs(logPath,acAgents,portAgents,duration);
    
    % Postprocessing
    airtaxi.models.example_model.processData(parsed_data,acAgents,portAgents)
end
