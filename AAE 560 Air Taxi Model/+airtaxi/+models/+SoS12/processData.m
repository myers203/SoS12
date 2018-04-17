function results = processData(parsed_data,operator,runNum,speedScaleFactor)
    ac_data = parsed_data.ac_data;
%     port_data = parsed_data.port_data;
%     ac_colors = {'r','b','g','k','c','y'};

%     port_id_plot = 2;
%     for ii=1:length(portAgents)
%         plotCustomerData(port_data,ii);
%     end
    results = plotACModes(ac_data,operator,runNum,speedScaleFactor);
%     plotACEcon(ac_data,acAgents,ac_colors);
end

function results = plotACModes(ac_data,operator,runNum,speedScaleFactor)
%     ac_modes = {'idle','enroute2pickup','onTrip','crash-fatal','crash-nonfatal'};
%     modes_val = [1,2,3,4,5];
%     modes_ref = containers.Map(ac_modes,modes_val);
%preparing accident matrices for each type of collision. will also need to
%take into account number of passengers.
%     fatal_matrix = zeros(length(ac_data),size(ac_data{1}.modes,2));
%     nonfatal_matrix = zeros(length(ac_data),size(ac_data{1}.modes,2));
    % preparing matrices for time in the air 
    flight_time_er2p = zeros(length(ac_data),size(ac_data{1}.modes,2));
    flight_time_onT = zeros(length(ac_data),size(ac_data{1}.modes,2));
    for ii = 1:length(ac_data)
%        fatal_matrix(ii,:) = strcmp(ac_data{ii}.modes,'crash-fatal');
%        nonfatal_matrix(ii,:) = strcmp(ac_data{ii}.modes,'crash-nonfatal');
       flight_time_er2p(ii,:) = strcmp(ac_data{ii}.modes,'enroute2pickup');
       flight_time_onT(ii,:) = strcmp(ac_data{ii}.modes,'onTrip');
    end
%     fatalities = sum(max(fatal_matrix'));
    fatalities_human = operator.fatal_crashes_human;
    fatalities_auto = operator.fatal_crashes_auto;
%     non_fatalities = sum(max(nonfatal_matrix'));
    non_fatalities_human = operator.nonfatal_crashes_human;
    non_fatalities_auto = operator.nonfatal_crashes_auto;
    
    % TODO: update this 
    vertiport_caused = 0;
    
    avg_dist_bw_ports = mean(mean(operator.calcDistBetweenPorts));
    
    tot_flight_time_er2p = sum(sum(flight_time_er2p))*speedScaleFactor;
    tot_flight_time_onT  = sum(sum(flight_time_onT))*speedScaleFactor; 
    % whole time in the air for the entire fleet in hours
    flight_time_total = (tot_flight_time_er2p +...
        tot_flight_time_onT)/60;
    % performance metric
    f_rate = (fatalities_human+fatalities_auto)*1e5/(flight_time_total); 
    nonf_rate = (non_fatalities_human+non_fatalities_auto)*1e5/(flight_time_total);
   % performance metric in incidents per flight hour...hope to make this 
   % per 100,000 flight hours
   figure(2)
   bar([f_rate, nonf_rate])
   set(gca,'xticklabel',{'Fatality Rate','Non-fatality Rate'})
   ylabel('Incidents per 100,000 Flight Hours')
   title('Collision Data')
   
   results = {runNum, fatalities_human, fatalities_auto, ...
       non_fatalities_human, non_fatalities_auto, ...
       tot_flight_time_onT, tot_flight_time_er2p, ...
       vertiport_caused, avg_dist_bw_ports};
end

% function plotCustomerData(port_data,id)
%     figure('Name',strcat('Customer Data: Port ',num2str(id))); hold on; box on; grid on;
%     ax = gca();
%     x = port_data{id}.times;
%     y1 = port_data{id}.customer_count;
%     plot(ax,x,y1,'k','LineWidth',2);
% %     y2 = port_data{id}.served_customers;
% %     plot(ax,x,y2,'g','LineWidth',2);
%     title(['Customer Data (Port ',num2str(id),')'])
% %     legend({'Total Customers','Customers Served'});
%     set(ax,'ytick',0:max(y1)+1)
%     ylim([0 max(y1)+1]);
%     xlabel('Time [min]');
%     ylabel('Number of customers');
% end