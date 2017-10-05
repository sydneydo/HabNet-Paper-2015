classdef ResourceUseDefinitionImpl < handle
    %ResourceUseDefinitionImpl Generic Class to Define different types of
    %resource producers and consumers
    %   Detailed explanation goes here
    
    properties
        ResourceStore
        DesiredFlowRate
        MaxFlowRate
    end
    
    methods
        function obj = ResourceUseDefinitionImpl(store,desiredFlowRate,maxFlowRate)
            if nargin > 0  
                obj.ResourceStore = store;
                
                if nargin > 1
                    obj.DesiredFlowRate = desiredFlowRate;
                    obj.MaxFlowRate = maxFlowRate;
                end
            end
        end
    end
    
end

