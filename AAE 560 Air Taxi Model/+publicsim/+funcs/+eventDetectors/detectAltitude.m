function fh = detectAltitude(obj)
% Event detector for triggering upon crossing an altitude in a direction
% Event Arguments:
% direction: [-1, 1] Direction of crossing an altitude mark to trigger.
% [-1] will trigger on descent, [1] will trigger on ascent
% altitude: [m] Altitude of event trigger
lastAltitude = -inf;
shouldRun = [];
fh = @detectAltitudeNested;

    function bool = detectAltitudeNested(~, args)
        if isempty(shouldRun)
            shouldRun = ones(numel(args), 1);
        end
        if ~any(shouldRun)
            bool = 0;
            return;
        end
        lla = obj.world.convert_ecef2lla(obj.getPosition());
        currentAltitude = lla(3);
        if currentAltitude > lastAltitude
            direction = 1;
        elseif currentAltitude < lastAltitude
            direction = -1;
        else
            direction = 0;
        end
        
        % Process the arguments
        bool = zeros(numel(args), 1);
        for i = 1:numel(args)
            if shouldRun(i)
                if direction == args{i}.direction
                    switch direction
                        case 1 % Rising
                            bool(i) =  currentAltitude > args{i}.altitude;
                        case -1 % Falling
                            bool(i) = currentAltitude < args{i}.altitude;
                    end
                    if bool(i)
                        shouldRun(i) = 0;
                    end
                end
            end
        end
        % Save the current altitude for the next run
        lastAltitude = currentAltitude;
    end
end