classdef InjectorImpl
    %InjectorImpl Summary of this class goes here
    %   By: Sydney Do (sydneydo@mit.edu)
    %   Date Created: 5/17/2014
    %   Last Updated: 5/17/2014
    %   This is the same implementation as that of the AccumulatorImpl
    %   In BioSim, both InjectorImpl and AccumulatorImpl reference a parent
    %   class called ResourceMover
    %   Comments within the InjectorImpl class code provide the following
    %   description:
    %   * The basic Accumulator Implementation. Can be configured to take any modules
    %   * as input, and any modules as output. It takes as much as it can (max taken
    %   * set by maxFlowRates) from one module and pushes it into another module.
    %   * Functionally equivalent to an Accumulator at this point.
    
    
    properties
        ResourceConsumerDefinition  % Generic incoming resource
        ResourceProducerDefinition  % Generic outgoing resource
    end
    
    methods
        %% Constructor
        function obj = InjectorImpl
            obj.ResourceConsumerDefinition = ResourceUseDefinitionImpl;
            obj.ResourceProducerDefinition = ResourceUseDefinitionImpl;
        end
        
        %% tick
        function tick(obj)
            % Attempt to get resource from consumer store according to declated
            % maxFlowRate
            resourceGathered = obj.ResourceConsumerDefinition.ResourceStore.take(obj.ResourceConsumerDefinition.MaxFlowRate,...
                obj.ResourceConsumerDefinition);
            
            % Push resourceGathered to producer store
            obj.ResourceProducerDefinition.ResourceStore.add(resourceGathered,obj.ResourceProducerDefinition);
        end
            
    end
    
end

