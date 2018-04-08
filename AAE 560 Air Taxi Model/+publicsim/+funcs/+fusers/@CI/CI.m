classdef CI < publicsim.funcs.fusers.Fuser
    % Track to track fusion with covariance intersection
    
    properties
        
        enableMemory = 1;
        
    end
    
    methods
        
        function obj=CI(fuserType)
            obj=obj@publicsim.funcs.fusers.Fuser(fuserType);
            obj.enableMemory = 1;
        end
        
        function fuseTracks(obj,~)
            allTracks=values(obj.trackMap);
            
            if numel(allTracks)==1
                track=allTracks{1};
                t=track.t;
                x0=track.x;
                P0=track.P;
                obj.fusedTrack.initByState(x0,P0,t);
            else
                
                times=zeros(numel(allTracks),1);
                for i=1:numel(allTracks)
                    track=allTracks{i};
                    times(i)=track.t;
                end
                
                %get all tracks to common time
                % Common time is the latest time of a track update from all
                % tracks
                
                [~,idx]=max(times);
                lastTrack=allTracks{idx};
                
                for i=1:numel(allTracks)
                    [x_is,P_is] = allTracks{i}.getPositionAtTime(lastTrack.t);
                    X{i} = x_is;
                    P{i} = P_is;
                    
                end
                
                if obj.enableMemory
                    % Include fused track in the update if available
                    
                    if ~isempty(obj.fusedTrack.t)
                        %check for time discrepency
                        if obj.fusedTrack.t > lastTrack.t
                            % No new update is needed.
                            disp('This should not be the case---error check code needed here')
                            keyboard
                        end

                        [xFusedOld,PFusedOld] = obj.fusedTrack.getPositionAtTime(lastTrack.t);
                        
                        X{end+1}= xFusedOld;
                        P{end+1} = PFusedOld;
                    end
                end
                
                [xFused,PFused] = obj.calcFusedTrackCI(X,P);
                
                obj.fusedTrack.initByState(xFused,PFused,lastTrack.t);
            end
            
        end
        
    end
    
    methods(Static)
        function [x_fused,P_fused]=calcFusedTrackCI(X,P)
            
            n = length(P);
            numdim  = length(X{1});
            I       = cell(n,1);
            if(n == 2)  %With intersection of two components, do a line search
                for jj = 1:n
                    I{jj} = inv(P{jj});
                end
                objective = @(beta) -1*det(beta*I{1} + (1-beta)*I{2});
                [~,beta] = publicsim.funcs.fusers.CI.sectionSearch(0,1,objective,12);
                omega = [beta; 1-beta];
            else
                
                I_total = zeros(numdim);
                for jj = 1:n
                    I{jj} = inv(P{jj});
                    I_total = I_total + I{jj};
                end
                
                detI = zeros(n,1);
                detI_delta = zeros(n,1);   %det(I_tot - I_i)
                detI_total = det(I_total);
                for kk = 1:n
                    detI(kk)       = det(I{kk});
                    detI_delta(kk) = det(I_total - I{kk});
                end
                
                denominator = n*detI_total + sum(detI) - sum(detI_delta);
                
                omega = (detI_total - detI_delta + detI)./denominator;
                
            end
            
            I_result  = zeros(numdim);
            for ii = 1:n
                I_result = I_result + omega(ii).*I{ii};
            end
            P_fused = inv(I_result);
            
            %inv(P_cc)*c = sum(omega(i)*inv(P(i))*x(i))
            weighted_sum = zeros(numdim,1);
            for jj = 1:n
                weighted_sum = weighted_sum + omega(jj)*I{jj}*X{jj};
            end
            x_fused = I_result\weighted_sum;
            
        end
        
        
        function [value,point] = sectionSearch(lower_bound,upper_bound,objs,numIters)
            % objs is function handle to function to be minimized
            
            % phi = (1+sqrt(5))/2;
            % phi = 2 - phi;
            phi = 0.381966011250105;
            
            delta = upper_bound - lower_bound;
            p   = [lower_bound lower_bound+phi*delta upper_bound-phi*delta upper_bound];
            val = [objs(p(1)) objs(p(2)) objs(p(3)) objs(p(4))];
            
            for ii = 1:numIters
                if(val(2) > val(3))
                    %[a b new upper]
                    test   = p(4) - phi*(p(4)-p(2));
                    p      = [p(2) p(3) test p(4)];
                    val    = [val(2) val(3) objs(test) val(4)];
                else
                    %[lower new a b]
                    test = p(1) + (p(3)-p(1))*phi;
                    p    = [p(1) test p(2) p(3)];
                    val  = [val(1) objs(test) val(2)  val(3)];
                end
            end
            [value,idx] = min(val);
            point       = p(idx);
        end
        
    end
    
end
