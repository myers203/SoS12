function setupScenario(input_file,port_file,runNum,acAgents,portAgents,operator)
    % Currently assumes a single operator
    n_ports     = length(portAgents);
    n_aircraft  = length(acAgents);
    
    % Parse Data Files
    [~,~,params] = xlsread(input_file,'params');
    portConfig = params{runNum+1,11};
    [~,~,port_info] = xlsread(port_file,portConfig);

    numHumanAcft = params{runNum+1,2};

    % Parse Operator info
    operator.setNetDelay(params{runNum+1,7});
    operator.setTakeoffClearance(params{runNum+1,8});
    operator.setLandingClearance(params{runNum+1,9});
    operator.setSeparationDistance(params{runNum+1,10});

    % Parse the port info
    [port_ids,port_locations] = parsePortInfo(port_info);

    for ii=1:n_ports
        loc = port_locations{ii};
        loc(3) = 0;
        portAgents{ii}.setLocation(loc);
        portAgents{ii}.port_id = port_ids(ii);
    end
   
%     %Setting number of aircraft to be the same as available landing zones
%     %in case of user error.
%     if n_aircraft>sum(n_start_zones)
%         fprintf(2,['WARNING: The number of aircraft exceeds '...
%             'available landing zones.\n'...
%             'Setting fleet to be equal to number of landing zones...'])
%         n_aircraft = sum(n_start_zones);
%         acAgents = acAgents([1:n_aircraft]);
%     end
    
    for ii=1:n_aircraft
        if ii <= numHumanAcft
            acAgents{ii}.pilot_type = 'human';
            acAgents{ii}.setColor('b');
        else
            acAgents{ii}.pilot_type = 'full-auto';
            acAgents{ii}.setColor('g');
        end

        acAgents{ii}.ac_id = ii; 
        visibility = params{runNum+1,4};
        acAgents{ii}.setVisibility(visibility);
        acAgents{ii}.setSkill(params{runNum+1,5});
        acAgents{ii}.setCruiseSpeed(params{runNum+1,6});
    end
    
    n_aircraft_loop = n_aircraft;
    count = 1;
    %this loop structure will take ANY combination of number of ports,
    %number of landing zones, and number of aircraft.
    while n_aircraft_loop>0
        for ii=1:n_ports
            start_port = ii;
            n_aircraft_loop=n_aircraft_loop-1;
            loc = port_locations{start_port};
            loc(3) = 0;
            acAgents{count}.setLocation(loc);
            acAgents{count}.current_port = start_port;
            count=count+1;
            if count > n_aircraft
                break;
            end
        end
    end
    
    operator.setService(portAgents);
    operator.setAircraft(acAgents);
    
    % Sim realtime plotting settings
    bounds = findPlottingBounds(port_locations);
    airtaxi.funcs.plots.Plotter.setup([],acAgents,portAgents,bounds);
    
    % Plot Visibility
    alpha = 0.6 * (1-visibility);
    c = [0 0 1 alpha];
    pos = [bounds.xLim(1) bounds.yLim(1) ...
        bounds.xLim(2)-bounds.xLim(1) bounds.yLim(2)-bounds.yLim(1)];
    rectangle('Position',pos,'FaceColor',c,'EdgeColor',c);
end

function [port_ids,port_locations] = parsePortInfo(port_info)
    num_ports = size(port_info,1)-1;
    port_ids = zeros(num_ports,1);
    port_locations = cell(1,num_ports);
    for i=1:num_ports
        port_ids(i) = port_info{i+1,1};
        port_locations{i} = cell2mat(port_info(i+1,2:3));
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