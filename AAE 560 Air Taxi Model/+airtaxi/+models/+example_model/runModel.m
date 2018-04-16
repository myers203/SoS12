function runModel(~)
    import publicsim.*;
    
    simTimes.startTime = 0;
    simTimes.endTime   = 1000; % 1000 min
                               % 1 Sim s = 1 actual min
    logPath            = './tmp/example_model';
    simInst            = publicsim.sim.Instance(logPath);

    % User input parsing
    input_file = "+airtaxi/sample_inputs.xlsx";
    [~,~,user_input] = xlsread(input_file);
    
    n_aircraft       = user_input{10,2};
    n_ports_serviced = user_input{13,2};
    operator_info    = user_input(1:4,2);
    
    % Connect aircraft and the ports
    [airNet,airMgr,obsMgr] = airtaxi.models.example_model.buildModel(simInst,simTimes,...
        [n_ports_serviced,n_aircraft],{'airtaxi.agents.Port','airtaxi.agents.Aircraft'},n_ports_serviced);
    airNet.updateNextHopList();    

    
    % Set up agents
    acAgents   = airMgr.getChildObjects('Aircraft');
    portAgents = airMgr.getChildObjects('Port');
    operator   = airtaxi.agents.Operator(operator_info);
    
    % Add operator to the simulation
    simInst.AddCallee(operator);
    
    % Add the aircraft as children to the operator
    for ii=1:length(acAgents)
        operator.addChild(acAgents{ii});
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
