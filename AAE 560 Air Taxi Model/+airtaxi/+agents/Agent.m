classdef Agent <   publicsim.agents.base.Periodic ...
                 & publicsim.agents.base.Networked 
    %AGENT Trace and conversion utility for ssat agents
    properties (Access = protected)
        convert = airtaxi.util.Convert;
    end
    
    methods
        function obj = Agent()
            obj = obj@publicsim.agents.base.Periodic();            
        end

        % Add agent ID and printf() formatting to Loggable's trace methods
        
        function outstr = fmt(obj,format,varargin)
            outstr = [sprintf('%3d',obj.id) ':' obj.identifier() ' ' sprintf(format,varargin{:})];
        end 
        
        function disp_DEBUG(obj,format,varargin)
            disp_DEBUG@publicsim.sim.Loggable(obj,obj.fmt(format,varargin{:}));
        end
        
        function disp_INFO(obj,format,varargin)
            disp_INFO@publicsim.sim.Loggable(obj,obj.fmt(format,varargin{:}));
        end
        
        function disp_WARN(obj,format,varargin)
            disp_WARN@publicsim.sim.Loggable(obj,obj.fmt(format,varargin{:}));
        end
        
        function disp_ERROR(obj,format,varargin)
            disp_ERROR@publicsim.sim.Loggable(obj,obj.fmt(format,varargin{:}));
        end
        
        function disp_FATAL(obj,format,varargin)
            disp_FATAL@publicsim.sim.Loggable(obj,obj.fmt(format,varargin{:}));
        end        
   end

    methods (Abstract)
        % Agent can create ID string any way it likes
        identifier(obj)
    end    
    
            %%%% TEST METHODS %%%%
    
    methods (Static, Access = {?publicsim.tests.UniversalTester})
        function tests = test()
            % Run all tests TODO Make gooder
            tests = {};
            %tests{1} = 'publicsim.tests.agents.base.MovableTest.test_Movable';
        end
    end
end
