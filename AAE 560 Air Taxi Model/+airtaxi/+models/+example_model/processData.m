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

function plotACEcon(ac_data,acAgents,ac_colors)
    % Initialize arrays
    gross_costs = zeros(1,length(ac_data{1}.times));
    gross_revenue = gross_costs; gross_returns = gross_costs;
    customers_served = gross_costs;
    
    % For each aircraft
    for ii=1:length(ac_data)
        figure('Name',strcat('Operation Economics: AC ',num2str(ii)));
        hold on
        box  on
        grid on
        ax = gca();
        y1 = ac_data{ii}.operating_costs;
        x = ac_data{ii}.times;
        plot(ax,x,y1,'r','LineWidth',2);
        y2 = ac_data{ii}.revenue;
        plot(ax,x,y2,'g','LineWidth',2);
        y3 = y2 - y1;
        plot(ax,x,y3,'k','LineWidth',2);
        legend(ax,{'Operating Costs','Revenue','Returns'});
        title(['AC ',num2str(acAgents{ii}.ac_id),' (',acAgents{ii}.type,') Returns']);
        ylabel('$');
        xlabel('Time [min]');
        
        gross_costs = gross_costs + y1;
        gross_revenue = gross_revenue + y2;
        gross_returns = gross_returns + y3;
        customers_served = customers_served + [ac_data{ii}.market_served.customers_served];
    end
    
    % Plot the overall economics
    figure('Name','Operation Economics (Entire Fleet)');
    hold on
    box  on
    grid on
    ax = gca();
    tt = ac_data{1}.times;
    plot(ax,tt,gross_costs,'r','LineWidth',2);
    plot(ax,tt,gross_revenue,'g','LineWidth',2);
    plot(ax,tt,gross_returns,'k','LineWidth',2);
    legend(ax,{'Gross Ops Costs','Gross Revenue','Gross Returns'});
    title('Operation Economics (Entire Fleet)');
    ylabel('$');
    xlabel('Time [min]');
    

    % Plot market share data
    figure('Name','Customers Served (Entire fleet)')
    hold on
    box on
    grid on
    ax = gca();
    plot(ax,tt,customers_served,'k','LineWidth',2);
    title('Customers Served (Entire Fleet)');
    ylabel('Number of Customers')
    xlabel('Time [min]');
    
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