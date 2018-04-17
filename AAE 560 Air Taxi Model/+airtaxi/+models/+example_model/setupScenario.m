function setupScenario(input_file,user_input,acAgents,portAgents,operator)
    % Currently assumes a single operator
    n_ports     = length(portAgents);
    n_aircraft  = length(acAgents);
    
    [~,~,port_info]    = xlsread(input_file,'Ports');
    [~,~,ac_info]      = xlsread(input_file,'Aircraft');
    
    % Ports serviced and chargers purchased
    [port_ids] = parseServicedPorts(user_input);
    
    % Parse the AC info
    ac_type_params     = parseACInfo(ac_info);
    
    % Parse the port info
    [port_params,port_locations] =...
        parsePortInfo(port_info,port_ids,n_ports);
    n_start_zones = port_params(:,2);
    % Assign port properties
    portAgents = setPortProperties(portAgents,port_params);
        
    PortRange.Xmin = port_locations{1}(1);
    PortRange.Ymin = port_locations{1}(1);
    PortRange.Xmax = PortRange.Xmin;
    PortRange.Ymax = PortRange.Ymin;
    
    for ii=1:n_ports
        loc = port_locations{ii};
        loc(3) = 0;
        portAgents{ii}.setLocation(loc);
        portAgents{ii}.port_id = port_ids(ii);
        
        PortRange.Xmin = min(PortRange.Xmin,loc(2));
        PortRange.Xmax = max(PortRange.Xmax,loc(2));
        PortRange.Ymin = min(PortRange.Ymin,loc(2));
        PortRange.Ymax = max(PortRange.Ymax,loc(2));
    end
   
%     weather.setZone(PortRange);

    %Setting number of aircraft to be the same as available landing zones
    %in case of user error.
    if n_aircraft>sum(n_start_zones)
        fprintf(2,['WARNING: The number of aircraft exceeds '...
            'available landing zones.\n'...
            'Setting fleet to be equal to number of landing zones...'])
        n_aircraft = sum(n_start_zones);
        acAgents = acAgents([1:n_aircraft]);
    end
    
    for ii=1:n_aircraft
        acAgents{ii}.ac_id = ii; 
    end
    
    n_aircraft_loop = n_aircraft;
    count = 1;
    %this loop structure will take ANY combination of number of ports,
    %number of landing zones, and number of aircraft.
    while sum(n_start_zones>0) && n_aircraft_loop>0
        for ii=1:n_ports
            if n_start_zones(ii)>0
                start_port = ii;
                n_start_zones(ii) = n_start_zones(ii)-1;
                n_aircraft_loop=n_aircraft_loop-1;
            else
                continue;
            end
            loc = port_locations{start_port};
            loc(3) = 0;
            acAgents{count}.setLocation(loc);
            acAgents{count}.current_port = start_port;
            count=count+1;
            if count > n_aircraft
                break
            end
        end
    end
    
    operator.setService(portAgents);
    operator.setAircraft(acAgents);
    
    % Sim realtime plotting settings
    bounds = findPlottingBounds(port_locations);
    airtaxi.funcs.plots.Plotter.setup([],acAgents,portAgents,bounds);
    
    % Plot Visibility
    alpha = 0.1 + 0.2 * visibility;
    c = [0 0 1 alpha];
    pos = [bounds.xLim(1) bounds.yLim(1) bounds.xLim(2) bounds.yLim(2)];
    rectangle('Position',pos,'FaceColor',c,'EdgeColor',c);
end

function ac_type_params = parseACInfo(ac_info)
    all_ac_types = ac_info(2:end,1);
    all_ac_types(cellfun(@(C) any(isnan(C(:))),all_ac_types)) = [];
    ac_type_params = cell2mat(ac_info(2:1+length(all_ac_types),2:4));
end

function [port_params,port_locations] = parsePortInfo(port_info,port_ids,n_ports)
    all_port_ids = cell2mat(port_info(2:end,1));
    all_port_ids(isnan(all_port_ids)) = [];
    port_locations = cell(1,n_ports);
    port_params    = nan(n_ports,3);
    for ii=1:n_ports
        info_row_ref = 1+find(all_port_ids == port_ids(ii));
        port_locations{ii} = cell2mat(port_info(info_row_ref,2:3));
        port_params(ii,:)  = cell2mat(port_info(info_row_ref,4:6));
    end
end

function portAgents = setPortProperties(portAgents,port_params)
    for ii=1:length(portAgents)
        portAgents{ii}.landing_slots = port_params(ii,2);
    end
end

function [ac_types,ac_type_numbers] = parseFleet(user_input)
    ii = 3;
    ac_types = {};
    while ~isempty(user_input{9,ii})
           if isnan(user_input{9,ii})
               break
           end
        ac_types{end+1}   = user_input{9,ii};
        ii = ii+1;
    end

    ac_type_numbers = cell2mat(user_input(10,3:ii-1));
end

function [port_ids] = parseServicedPorts(user_input)
    ii = 3;
    port_ids = [];
    while ~isempty(user_input{12,ii})
        if isnan(user_input{12,ii})
            break
        end
        % Check if the port is serviced
        if strcmpi(user_input{13,ii},'Yes')
            port_ids(end+1) = str2double(extractAfter(user_input{12,ii},'Port ')); %#ok<*AGROW>
        end
        ii = ii+1;
    end
end

function bounds = findPlottingBounds(port_locations)
    x = nan(1,length(port_locations)); y =x;
    for ii=1:length(port_locations)
        x(ii) = port_locations{ii}(1);
        y(ii) = port_locations{ii}(2);
    end
    x = sort(x); y = sort(y);
    x_min = x(1); x_max = x(end); y_min = y(1); y_max = y(end);
    bounds.xLim = [x_min x_max] + [-5 5];
    bounds.yLim = [y_min y_max] + [-10 10];
end