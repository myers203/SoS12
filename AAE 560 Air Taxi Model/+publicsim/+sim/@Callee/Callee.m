classdef Callee < handle & publicsim.sim.Loggable
    %CALLEE a class that can be scheduled in the simulation
    %   Callees' are identifiable objects instantiated inside of a
    %   simulation that enable interaction with the even queue and logging
    %
    %   scheduleAtTime(time) adds the callee's runAtTime function to the
    %   queue at time, where time below the current time is adjusted
    %   forward
    %
    %   scheduleAtTime(time,myFuncHandle) replaces runAtTime with
    %   myFuncHandle callback
    %
    %   getCurrentTime() returns current sim time
    
    properties
        hasBeenInit=0 %set to 1 after init
    end
    
    properties(SetAccess=private)
        id          %unique per-callee id number
        commonName  %callee name; useful for identification in logs/plots
    end
    
    %Transient prevents storage on save command
    properties(SetAccess=private,Transient=true)
        instance    %back-reference to the sim instance
    end
    
    methods
        
        function obj=Callee()
            %creates a new callee; usually overloaded
        end
        
        function init(obj) %#ok<MANU>
            %runs at sim start
        end
        
        function fini(obj) %#ok<MANU>
            %runs at sim end
        end
        
        
        
        function scheduleAtTime(obj,time,varargin)
            %adds the callee to the event queue; by default runAtTime(time)
            %will be called, but a function handle can be passed as
            %scheduleAtTime(time,@myFunc) ; will be called as myFunc(time)
            if nargin >= 3
                functionHandle=varargin{1};
            else
                functionHandle=@obj.runAtTime;
            end
            obj.instance.Scheduler.AddEvent(obj,time,functionHandle);
        end
        
        function time=getCurrentTime(obj)
            %returns the current simulation time; useful in nested code
            time=obj.instance.Scheduler.getCurrentTime();
        end
        
    end
    
    methods(Hidden=true)
        function setId(obj,id)
            %sets the unique callee id
            obj.id=id;
        end
        
        function setCommonName(obj,name)
            %sets the callee's common name
            obj.commonName=name;
        end
        
        function setInstance(obj,instance)
            %adds the back-reference to the instance
            obj.instance=instance;
        end
    end
    
    methods(Abstract)
        runAtTime(obj,time);
    end
    
end

