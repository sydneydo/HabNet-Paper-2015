classdef AirProducerDefinitionImpl < handle
    %AirProducerDefinitionImpl Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        ProductionStore
        DesiredFlowRate
        MaxFlowRate
    end
    
    methods %(Static)
        function obj = AirProducerDefinitionImpl(sink,desiredFlowRate,maxFlowRate)
            if nargin > 0
                
                obj.ProductionStore = sink;
                obj.DesiredFlowRate = desiredFlowRate;
                obj.MaxFlowRate = maxFlowRate;
            end
        end
        
    end
    
end