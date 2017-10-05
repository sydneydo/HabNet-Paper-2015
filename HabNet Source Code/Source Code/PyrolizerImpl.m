classdef PyrolizerImpl
    %PyrolizerImpl Summary of this class goes here
    %   By: Sydney Do (sydneydo@mit.edu)
    %   Date Created: 5/16/2014
    %   Last Updated: 5/16/2014
    %   Pyrolisis system that recovers hydrogen from methane
    
    properties
        % Consumer/Producer Definitions
        PowerConsumerDefinition
        MethaneConsumerDefinition
        H2ProducerDefinition
        DryWasteProducerDefinition
    end
    
    methods
        %% Constructor
        function obj = PyrolizerImpl
            obj.PowerConsumerDefinition = ResourceUseDefinitionImpl;
            obj.MethaneConsumerDefinition = ResourceUseDefinitionImpl;
            obj.H2ProducerDefinition = ResourceUseDefinitionImpl;
            obj.DryWasteProducerDefinition = ResourceUseDefinitionImpl;
        end
        
        %%tick
        function tick(obj)
            
        end
    end
    
end

