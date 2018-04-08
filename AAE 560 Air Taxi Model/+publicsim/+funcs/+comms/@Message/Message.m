classdef Message < handle
    %MESSAGE Information holder used to set sizing manually
    %   setMessageSize(bytes)
    %
    %   setPayload(message)
    %
    %   getPayload()
    
    properties(SetAccess=protected)
        payload
        size
        topicKey
    end
    
    methods
        
        function obj=Message(payload,size)
            if nargin >= 1 && ~isempty(payload)
                obj.setPayload(payload)
            end
            if nargin >= 2 && ~isempty(size)
                obj.setMessageSize(size);
            end
        end
        
        function setMessageSize(obj,size)
            obj.size=size;
        end
        
        function size=getMessageSize(obj)
            size=obj.size;
        end
        
        function setPayload(obj,message)
            obj.payload=getByteStreamFromArray(message);
        end
        
        function payload=getPayload(obj)
            payload=getArrayFromByteStream(obj.payload);
        end
        
    end
    
end

