function parsedData = parseLogs(logPath,acAgents,portAgents,duration)
    logger = publicsim.sim.Logger(logPath);
    logger.restore();
    parsedData = struct();
    
    % Aircraft Data Parsing
    aircraftData = publicsim.sim.Loggable.readParamsByClass(logger,'airtaxi.agents.Aircraft',{'getOperationMode','operating_costs','revenue','getMarketServed'});
    portData     = publicsim.sim.Loggable.readParamsByClass(logger,'airtaxi.agents.Port',{'getCustomerData'});

    ac_data    = parseAircraftData(aircraftData,acAgents,duration);
    port_data  = parsePortData(portData,portAgents,duration);
   
    parsedData.ac_data = ac_data;
    parsedData.port_data = port_data;
end


function port_data = parsePortData(unparsed_port_data,portAgents,duration)
    customerData = [unparsed_port_data.getCustomerData];
    allCustomers = [customerData.value];
    allIds       = [customerData.id];
    allTimes     = [customerData.time];
    port_count   = 1;
    port_data    = cell(size(portAgents));

    for ref = 1:(duration+1):length(allTimes)
        data_temp = struct();
        data_temp.id = allIds(ref);
        if data_temp.id~=portAgents{port_count}.id
            keyboard
        end
        data_temp.customer_count   = [allCustomers(ref:ref+duration).total_count];
        data_temp.served_customers = [allCustomers(ref:ref+duration).served_count];
        data_temp.trip_demand      = [allCustomers(ref:ref+duration).trip_demand];
        
        data_temp.times = allTimes(ref:ref+duration);
        port_data{port_count} = data_temp;
        port_count = port_count+1;
    end
end

function ac_data = parseAircraftData(unparsed_ac_data,acAgents,duration)
    modeData = [unparsed_ac_data.getOperationMode];
    operatingCostData = [unparsed_ac_data.operating_costs];
    revenueData = [unparsed_ac_data.revenue];
    marketServedData = [unparsed_ac_data.getMarketServed];
    
    allModes = {modeData.value};
    allIds   = [modeData.id];
    allTimes = [modeData.time];
    
    allCosts = [operatingCostData.value];
    allRevenues = [revenueData.value];
    allMarketServed = [marketServedData.value];
    
    ac_data = cell(size(acAgents));
    ac_count = 1;
    for ref = 1:(duration+1):length(allTimes)
        data_temp = struct();
        data_temp.id = allIds(ref);
        if data_temp.id~=acAgents{ac_count}.id
            keyboard
        end
        data_temp.modes = allModes(ref:ref+duration);
        data_temp.operating_costs = allCosts(ref:ref+duration);
        data_temp.revenue = allRevenues(ref:ref+duration);
        data_temp.market_served = allMarketServed(ref:ref+duration);
        data_temp.times = allTimes(ref:ref+duration);
        ac_data{ac_count} = data_temp;
        ac_count = ac_count+1;
    end
    
    
    
    
end