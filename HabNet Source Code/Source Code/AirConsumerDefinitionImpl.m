classdef AirConsumerDefinitionImpl < handle
    %AirConsumerDefinitionImpl Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        ConsumptionStore
        DesiredFlowRate
        MaxFlowRate
    end
    
    methods %(Static)
        function obj = AirConsumerDefinitionImpl(SimEnvironment,desiredFlowRate,maxFlowRate)
            if nargin > 0
                
                obj.ConsumptionStore = SimEnvironment;
                obj.DesiredFlowRate = desiredFlowRate;
                obj.MaxFlowRate = maxFlowRate;
            end
        end
        
    end
    
end

