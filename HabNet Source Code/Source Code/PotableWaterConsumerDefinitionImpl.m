classdef PotableWaterConsumerDefinitionImpl < handle
    %PotableWaterConsumerDefinitionImpl Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        ConsumptionStore
        DesiredFlowRate
        MaxFlowRate
    end
    
    methods %(Static)
        function obj = PotableWaterConsumerDefinitionImpl(store,desiredFlowRate,maxFlowRate)
            if nargin > 0
                
                obj.ConsumptionStore = store;
                obj.DesiredFlowRate = desiredFlowRate;
                obj.MaxFlowRate = maxFlowRate;
            end
        end
        
    end
    
end