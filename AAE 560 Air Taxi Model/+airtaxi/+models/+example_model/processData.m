function processData(parsed_data,acAgents,portAgents)
    ac_data = parsed_data.ac_data;
    port_data = parsed_data.port_data;
    ac_colors = {'r','b','g','k','c','y'};

%     port_id_plot = 2;
%     for ii=1:length(portAgents)
%         plotCustomerData(port_data,ii);
%     end
    plotACModes(ac_data,acAgents,ac_colors);
%     plotACEcon(ac_data,acAgents,ac_colors);
end

function plotACModes(ac_data,acAgents,ac_colors)
%     ac_modes = {'idle','charging','enroute2charging','enroute2pickup','onTrip'};
    ac_modes = {'idle','enroute2pickup','onTrip','crash-fatal','crash-nonfatal'};
    modes_val = [1,2,3,4,5];
    modes_ref = containers.Map(ac_modes,modes_val);
    
    
    for ii=1:length(ac_data)
        figure('Name', strcat('Modes: AC ',num2str(ii)))
        hold on
        box  on
        grid on
        ax = gca();
        y = zeros(1,length(ac_data{ii}.modes));
        x = ac_data{ii}.times;
        for jj=1:length(ac_data{ii}.modes)
            y(jj) = modes_ref(ac_data{ii}.modes{jj});
        end
        plot(ax,x,y,'b','LineWidth',2);
        title(['AC ',num2str(acAgents{ii}.ac_id),' (',acAgents{ii}.type,') Modes']);
        set(ax,'ytick',1:length(ac_modes),'yticklabel',ac_modes,'FontSize',10);
        ylim([0 length(ac_modes)+1])
        xlabel('Time [min]');
    end
end

function plotCustomerData(port_data,id)
    figure('Name',strcat('Customer Data: Port ',num2str(id))); hold on; box on; grid on;
    ax = gca();
    x = port_data{id}.times;
    y1 = port_data{id}.customer_count;
    plot(ax,x,y1,'k','LineWidth',2);
%     y2 = port_data{id}.served_customers;
%     plot(ax,x,y2,'g','LineWidth',2);
    title(['Customer Data (Port ',num2str(id),')'])
%     legend({'Total Customers','Customers Served'});
    set(ax,'ytick',0:max(y1)+1)
    ylim([0 max(y1)+1]);
    xlabel('Time [min]');
    ylabel('Number of customers');
end