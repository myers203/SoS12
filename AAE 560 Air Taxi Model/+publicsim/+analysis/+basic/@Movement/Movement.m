classdef Movement < publicsim.analysis.CoordinatedAnalyzer
    %MOVEMENT Analyzes basic agents Locatable and Movable
    %   Provides data loading and plotting utilities
    
    properties
        logger
        allPositionData=struct('times',[],'positions',[],...
            'velocities',[],...
            'accelerations',[],...
            'fullNames',[],'uids',[],...
            'agentIds',[],'names',[],'observableIds',[]);
        agentIdToObservableId
        movableAgentIds
    end
    
    methods
        
        function obj=Movement(logger, coordinator)
            if ~exist('coordinator', 'var')
                coordinator = publicsim.analysis.Coordinator();
            end
            obj@publicsim.analysis.CoordinatedAnalyzer(coordinator);
            obj.logger=logger;
            obj.agentIdToObservableId=containers.Map('KeyType','int64','ValueType','any');
            obj.getAllPositions();
            obj.buildAgentObservableIdMap();
        end
        
        function plotPositions(obj)
            figure;
            x=obj.allPositionData.positions(:,1);
            y=obj.allPositionData.positions(:,2);
            z=obj.allPositionData.positions(:,3);
            uids=obj.allPositionData.uids;
            scatter3(x,y,z,[],uids,'d','filled');
            title('Actual Object Movements');
        end
        
        function plotPositionsByType(obj,type)
            figure;
            positionDataSubset=obj.getPositionsForClass(type);
            x=positionDataSubset.positions(:,1);
            y=positionDataSubset.positions(:,2);
            z=positionDataSubset.positions(:,3);
            uids=positionDataSubset.uids;
            scatter3(x,y,z,[],uids,'d','filled');
            title('Actual Object Movements');
        end
        
        function plotOnEarth(obj,earth)
            
            locatableStyle = 'd';
            movableStyle = 'o';
            
            colors = get(groot,'DefaultAxesColorOrder');
            nColors = size(colors,1);
            
            map_buffer = 5;
            z_buffer = 5000;
            
            uniqueNames = unique(obj.allPositionData.fullNames);
            nNames = numel(uniqueNames);
            
            maxes = -inf(1,3);
            mins = inf(1,3);
            
            figure();
            ax = gca;
            hold(ax,'on');
            handles = cell(1,nNames);
            legendNames = cell(1,nNames);
            handleVector = nan(1,nNames);
            
            objCounter = 0;
            
            for i = 1:nNames
                currentName = uniqueNames{i};
                agentIdxs = find(strcmp(currentName,obj.allPositionData.fullNames));
                
                agentIds=unique(obj.allPositionData.agentIds(agentIdxs));
                isMovable=0;
                for j=1:numel(obj.movableAgentIds)
                    if any(obj.movableAgentIds(j)==agentIds)
                        isMovable=1;
                    end
                end
                
                objCounter = objCounter+1;
                colorIdx = mod(objCounter,nColors);
                if colorIdx==0
                    colorIdx = nColors;
                end
                color = colors(colorIdx,:);
                
                if isMovable==0
                    style = locatableStyle;
                    faceColor = color;
                    %color = 'b';
                else
                    style = movableStyle;
                    faceColor = [];
                    
                end
                
                currentPositions = obj.allPositionData.positions(agentIdxs,:);
                currentLla = earth.convert_ecef2lla(currentPositions);
                handles{i} = plot3(currentLla(:,2),currentLla(:,1),currentLla(:,3),style,'MarkerEdgeColor',color);
                if ~isempty(faceColor)
                    handles{i}.MarkerFaceColor = faceColor;
                end
                handleVector(i) = handles{i};
                maxes = max([maxes;currentLla]);
                mins  = min([mins; currentLla]);
                legendNames{i} = currentName;
            end
            
            publicsim.util.visualization.earth_map(ax,[(mins(1) - map_buffer) (mins(2) - map_buffer) (maxes(1) + map_buffer) (maxes(2) + map_buffer)]);
            zLims = get(ax,'ZLim');
            set(ax,'ZLim',[0,zLims(2)+z_buffer]);
            view(-17,58);
            xlabel('Longitude (deg)'); ylabel('Latitude (deg)'); zlabel('Altitude (m)');
            hold(ax,'off');
            set(gcf,'color','w');
            
            legend(ax,handleVector,legendNames,'Interpreter','none');
            
            figWindow = get(gcf,'Position');
            set(gcf,'Position',[figWindow(1),figWindow(2),900,420]);
        end
        
        function plotOnEarth2(obj,earth)
            % working on finding a way to plot each agent individually...
            % without registering a callee.
            
            locatableStyle = 's';
            movableStyle = 'o';
            
            colors = {'r','g','y','c','m','k'};
            nColors = numel(colors);
            
            map_buffer = 5;
            z_buffer = 5000;
            
            uniqueNames = unique(obj.allPositionData.fullNames);
            nNames = numel(uniqueNames);
            
            maxes = -inf(1,3);
            mins = inf(1,3);
            
            figure();
            ax = gca;
            hold(ax,'on');
            handles = {};
            legendNames = {};
            
            objCounter = 0;
            
            for i = 1:nNames
                currentName = uniqueNames{i};
                agentIdxs = obj.allPositionData.agentIds(strcmp(currentName,obj.allPositionData.fullNames));
                
                for j = 1:agentIdxs
                    objCounter = objCounter+1;
                    if numel(agentIdxs)==1
                        style = locatableStyle;
                        faceColor = 'b';
                        color = 'b';
                    else
                        style = movableStyle;
                        faceColor = 'none';
                        colorIdx = mod(objCounter,nColors);
                        if colorIdx==0
                            colorIdx = nColors;
                        end
                        color = colors{colorIdx};
                    end
                    
                    currentPositions = obj.allPositionData.positions(agentIdxs,:);
                    currentLla = earth.convert_ecef2lla(currentPositions);
                    handles{end+1} = plot3(currentLla(:,2),currentLla(:,1),currentLla(:,3),[style color]); %#ok<AGROW>
                    handles{end}.MarkerFaceColor = faceColor;
                    
                    maxes = max([maxes;currentLla]);
                    mins  = min([mins; currentLla]);
                    legendNames{end+1} = [currentName sprintf('-%d',j)]; %#ok<AGROW>
                end
            end
            
            publicsim.util.visualization.earth_map(ax,[(mins(1) - map_buffer) (mins(2) - map_buffer) (maxes(1) + map_buffer) (maxes(2) + map_buffer)]);
            zLims = get(ax,'ZLim');
            set(ax,'ZLim',[0,zLims(2)+z_buffer]);
            view(-17,58);
            xlabel('Longitude (deg)'); ylabel('Latitude (deg)'); zlabel('Altitude (m)');
            hold(ax,'off');
            set(gcf,'color','w');
            
            legend(ax,handles,legendNames,'Position','EastOutside','Interpreter','none');
        end
        
        function output=getPositionsForClass(obj,className)
            [output, bool, memoizeKey] = obj.getMemoize(className);
            if bool
                return;
            end
            
            if ~iscell(className)
                className={className};
            end
            idxSet=[];
            for i=1:numel(obj.allPositionData.fullNames)
                testClass=obj.allPositionData.fullNames{i};
                allClassNames=[superclasses(testClass); testClass];
                for j=1:numel(className)
                    if any(ismember(className{j},allClassNames))
                        idxSet(end+1)=i; %#ok<AGROW>
                    end
                end
            end
            output.positions=obj.allPositionData.positions(idxSet,:);
            output.velocities = obj.allPositionData.velocities(idxSet, :);
            output.agentIds=obj.allPositionData.agentIds(idxSet)';
            output.observableIds=obj.allPositionData.observableIds(idxSet);
            [~,~,output.uids]=unique(output.agentIds);
            output.times=obj.allPositionData.times(idxSet);
            
            obj.memoize(output, memoizeKey, className)
        end
        
        function output=getObservablePositions(obj)
            %This function operates on the assumption that there is only
            %one observable manager in use!
            [output, bool, memoizeKey] = obj.getMemoize();
            if bool
                return;
            end
            
            idxSet=1:numel(obj.allPositionData.observableIds);
            idxSet=idxSet(obj.allPositionData.observableIds>0);
            output.positions=obj.allPositionData.positions(idxSet,:);
            output.velocities=obj.allPositionData.velocities(idxSet,:);
            output.accelerations=obj.allPositionData.accelerations(idxSet,:);
            output.observableIds=obj.allPositionData.observableIds(idxSet);
            output.times=obj.allPositionData.times(idxSet);
            
            obj.memoize(output, memoizeKey);
        end
        
    end
    
    methods(Access=private)
        function getAllPositions(obj)
            movableData=publicsim.sim.Loggable.readParamsByClass(obj.logger,'publicsim.agents.base.Movable',{'getPosition','getVelocity','getAcceleration'});
            locatableData=publicsim.sim.Loggable.readParamsByClass(obj.logger,'publicsim.agents.base.Locatable',{'getPosition'});
            positionData=[movableData.getPosition locatableData.getPosition];
            
            obj.movableAgentIds=unique([movableData.getPosition.id]);
            locatableData.getVelocity=locatableData.getPosition;
            locatableData.getAcceleration=locatableData.getPosition;
            for i=1:numel(locatableData.getPosition)
                locatableData.getVelocity(i).value=[0 0 0];
                locatableData.getAcceleration(i).value=[0 0 0];
            end
            velocityData=[movableData.getVelocity locatableData.getVelocity];
            accelerationData=[movableData.getAcceleration locatableData.getAcceleration];
            
            allTimes={positionData.time};
            obj.allPositionData.times=cell2mat(allTimes);
            allIds={positionData.id};
            obj.allPositionData.agentIds=cell2mat(allIds);
            [~,ia]=unique([obj.allPositionData.agentIds; obj.allPositionData.times;]','rows');
            %Remove duplicates
            positionData=positionData(ia);
            
            allTimes={velocityData.time};
            velocityDatatimes=cell2mat(allTimes);
            allIds={velocityData.id};
            velocityDataagentIds=cell2mat(allIds);
            [~,ia]=unique([velocityDataagentIds; velocityDatatimes;]','rows');
            velocityData=velocityData(ia);
            
            allTimes={accelerationData.time};
            accelerationDatatimes=cell2mat(allTimes);
            allIds={accelerationData.id};
            accelerationDataagentIds=cell2mat(allIds);
            [~,ia]=unique([accelerationDataagentIds; accelerationDatatimes;]','rows');
            accelerationData=accelerationData(ia);
            
            allPositions={positionData.value};
            allVelocities={velocityData.value};
            allAccelerations={accelerationData.value};
            obj.allPositionData.positions=cell2mat(allPositions');
            obj.allPositionData.velocities=cell2mat(allVelocities');
            obj.allPositionData.accelerations=cell2mat(allAccelerations');
            allTimes={positionData.time};
            obj.allPositionData.times=cell2mat(allTimes);
            allIds={positionData.id};
            obj.allPositionData.agentIds=cell2mat(allIds);
            
            obj.allPositionData.fullNames={positionData.className};
            for i=1:numel(obj.allPositionData.fullNames)
                C=strsplit(obj.allPositionData.fullNames{i},'.');
                obj.allPositionData.names{i}=[C{end} '-' num2str(obj.allPositionData.agentIds(i))];
            end
            
            [~,~,uids]=unique({positionData.className});
            obj.allPositionData.uids=uids;
        end
        
        function buildAgentObservableIdMap(obj)
            assert(~isempty(obj.allPositionData),'Must build positions first');
            objectAgentIds=unique(obj.allPositionData.agentIds);
            allAgents=publicsim.sim.Loggable.getAgentsByClass(obj.logger,'publicsim.agents.base.Movable');
            movableAgentIds=[allAgents.id];
            for i=1:numel(objectAgentIds)
                searchId=objectAgentIds(i);
                if ~any(searchId==movableAgentIds)
                    obj.agentIdToObservableId(searchId)=[];
                else
                    agentObj=allAgents(searchId==movableAgentIds).value;
                    obj.agentIdToObservableId(searchId)=...
                        agentObj.movableId;
                end
            end
            
            movableIds=0*ones(numel(obj.allPositionData.agentIds),1);
            for i=1:numel(obj.allPositionData.agentIds)
                movableId=obj.agentIdToObservableId(...
                    obj.allPositionData.agentIds(i));
                if ~isempty(movableId)
                    movableIds(i)=movableId;
                end
            end
            obj.allPositionData.observableIds=movableIds;
        end
    end
end

