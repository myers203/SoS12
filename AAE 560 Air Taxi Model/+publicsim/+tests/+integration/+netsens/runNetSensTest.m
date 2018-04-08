function [  ] = runNetSensTest(  )
%RUNNETSENSTEST Summary of this function goes here
%   Detailed explanation goes here
import publicsim.*;

startTime=0;
endTime=100;
simInst=sim.Instance('./tmp/netsens');
topicGroup=funcs.groups.TopicGroup();
observableManager=tests.integration.netsens.ObjectManager(startTime);

sensorTopic='sensors';

[nodes,network]=tests.integration.netsens.buildNetwork(simInst); %#ok<ASGLU>

observer=nodes{1}{1};
observer.setNetworkName('Observer');
topicGroup.appendToTopic('observer',observer);


sensors={};
for i=1:length(nodes{3})
    sensors=[sensors,nodes{3}{i}]; %#ok<AGROW>
end
for i=1:length(sensors)
    sensors{i}.setNetworkName(['Sensor-' num2str(i)]);
    n_dims=3;
    movable=publicsim.funcs.movement.NewtonMotion(n_dims);
    sensors{i}.setMovementManager(movable);
    sensors{i}.setInitialState(startTime,{'position',randn(1,3)*100,'velocity',[0 0 0],'acceleration',[0 0 0]});
    sensors{i}.setObservableManager(observableManager);
    topicGroup.appendToTopic([sensorTopic '/' num2str(i)],sensors{i});
end


numObservables=10;
for i=1:numObservables
    observable=tests.integration.netsens.MovingObject(startTime,randn(1,3)*100,randn(1,3)*1,randn(1,3)*0.1);
    simInst.AddCallee(observable);
    observableManager.addObservable(observable);
    topicGroup.appendToTopic('observables',observable);
end

    

network.updateNextHopList();
network.vizualizeGraph(network);

simInst.runUntil(startTime,endTime);

%clear all;
processNetSensTest('./tmp/netsens');


end

function processNetSensTest(filePath)
    import publicsim.*;
    
    log=sim.Logger(filePath);
    log.restore();
    observerTopic=log.getTopic('observer','','');
    
    [~,observerData]=log.readFromTopic(observerTopic);
    observerData=observerData{1};
    obsData=[];
    for i=1:length(observerData)
        obs=observerData{i};
        rxTime=obs{1};
        rxTopic=obs{2};
        txIdx=str2num(rxTopic.subtype);
        rxData=obs{3};
        txTime=rxData.time;
        ids=cell2mat(rxData.ids);
        positions=cell2mat(rxData.measurements);
        newObsData=[ones(length(ids),1)*txIdx ones(length(ids),1)*txTime ones(length(ids),1)*rxTime ids positions];
        obsData=[obsData; newObsData];
    end
    
    latency_times=obsData(:,3);
    [latency_times,idx]=sort(latency_times,'ascend');
    latencies=obsData(:,3)-obsData(:,2);
    latencies=latencies(idx);
    
    obsIdx=unique(obsData(:,4));
    dataById=cell(length(obsIdx),1);
    for i=1:length(obsIdx)
        idx=obsIdx(i);
        dataById{i}=obsData(obsData(:,4)==idx,:);
    end
    
    t1_data=dataById{1};
    idxNameList={'Transmitterd ID','Transmit Time','Rx Time','Target IDX','X','Y','Z'};
    
    figure;
    scatter3(obsData(:,5),obsData(:,6),obsData(:,7),[],obsData(:,1));
    figure;
    plot(latency_times,latencies*1000);
    xlabel('Time (s)');
    ylabel('Measurement Rx Delay (ms)');
    
end
