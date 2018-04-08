function fh = detectTime()
%DETECTTIME Triggers events once the time reaches or exceeds the trigger time
% Event Arguments:
% time: [s] Time of which to trigger the event
shouldRun = [];
fh = @detectTimeNested;

    function bool = detectTimeNested(time, args)
        if isempty(shouldRun)
            shouldRun = ones(numel(args), 1);
        end
        if ~any(shouldRun)
            bool = 0;
            return;
        end
        bool = zeros(numel(args), 1);
        for i = 1:numel(args)
            if shouldRun(i) && (time >= args{i}.time)
                bool(i) = 1;
                shouldRun(i) = 0;
            end
        end
    end

end

