classdef Database < handle & dynamicprops
    %Database Generic database for storing and updating information.
    
    properties
    end
    
    properties (SetAccess=immutable,Hidden)
        maps
    end
    
    methods
        function obj = Database(map_names,key_types)
            
            obj.maps = map_names;
            
            assert(iscell(map_names))
            assert(iscell(key_types))
            assert( numel(map_names)==numel(key_types) )
            for i = 1:numel(map_names)
                addprop(obj,map_names{i});
                obj.(map_names{i}) = containers.Map('KeyType',key_types{i},'ValueType','any');
            end
            
        end
        
        function updateDatabase(obj,key,value,varargin)
            if nargin == 3
                map_name = obj.maps{1};
            else
                map_name = varargin{1};
            end
            
            if ~obj.(map_name).isKey(key)
                obj.newEntry(map_name,key,value);
            else
                saved_value = obj.(map_name)(key);
                
                do_update = obj.checkUpdate(value);
                
                if do_update
                    obj.valueUpdate(saved_value, value, map_name, key);
                end
                
            end
            
        end
        
        function do_update = checkUpdate(obj,value) %#ok<INUSD>
            % useful if we are doing updates based on receive time or
            % similar.
            do_update = true;
        end
        
        function newEntry(obj,map_name,key,value)
            obj.(map_name)(key)=value;
        end
        
        function out = valueUpdate(obj, saved_value, new_value, map_name, key) %#ok<INUSL>
            out = new_value;
            
            % this might be overkill for values which are themselves
            % classes, but it will be important for structures,
            % arrays, and so on.
            obj.(map_name)(key) = new_value;
        end
    end
    
    %%%% TEST METHODS %%%%
    
    methods (Static, Access = {?publicsim.tests.UniversalTester})
        function tests = test()
            % Run all tests
            tests{1} = 'publicsim.funcs.databases.Database.test_database';
        end
    end
    
    methods (Static)
        function test_database()
            
            a = publicsim.funcs.databases.Database({'test'},{'double'});
            a.updateDatabase(1,[1,2,3]);
            assert(all(a.test(1)==[1,2,3]));
            
            a.updateDatabase(1,[4,5,6]);
            assert(all(a.test(1)==[4,5,6]));
            
            a.updateDatabase(2,[1,2,3]);
            assert(all(a.test(2)==[1,2,3]));
            
            b = publicsim.funcs.databases.Database({'test'},{'char'});
            b.updateDatabase('t',[1,2,3]);
            assert(all(b.test('t')==[1,2,3]));
            b.updateDatabase('u',[1,2]);
            
            c = publicsim.funcs.databases.Database({'test'},{'double'});
            d = c;
            addprop(d,'aaa');
            d.aaa = 1;
            
            c.updateDatabase(2,d);
            
            d.aaa = 2;
            c.updateDatabase(2,d);
            
            assert(c.test(2).aaa == 2)
            
            disp('Passed Database Test!');
            
        end
    end
    
end

