classdef BiomassPSImpl < handle
    %BiomassPSImpl Summary of this class goes here
    %   By: Sydney Do (sydneydo@mit.edu)
    %   Date Created: 5/31/2014
    %   Last Updated: 5/31/2014
    %
    %   Original BioSim code comments by Scott Bell
    %   The Biomass RS is essentially responsible for growing plants. The Biomass RS
    %   consists of many ShelfImpls, and inside them, a Plant. The ShelfImpl gathers
    %   water and light for the plant. The plant itself breathes from the atmosphere
    %   and produces biomass. The plant matter (biomass) is fed into the food
    %   processor to create food for the crew. The plants can also (along with the
    %   AirRS) take CO2 out of the air and add O2.
     
    %% You need to implement a ShelfImpl
    
    properties
        Shelves
        currentTick = 0
        PowerConsumerDefinition
        AirConsumerDefinition
        PotableWaterConsumerDefinition
        GreyWaterConsumerDefinition
        DirtyWaterProducerDefinition
        AirProducerDefinition
        BiomassProducerDefinition
%         autoHarvestAndReplant
%         isDeathEnabled
    end
    
%     events
%         InitializeProducersConsumers
%     end
    
    methods
        %% Constructor
        function obj = BiomassPSImpl(shelves)
            
            obj.PowerConsumerDefinition = ResourceUseDefinitionImpl;
            obj.AirConsumerDefinition = ResourceUseDefinitionImpl;
            obj.PotableWaterConsumerDefinition = ResourceUseDefinitionImpl;
            obj.GreyWaterConsumerDefinition = ResourceUseDefinitionImpl;
            obj.DirtyWaterProducerDefinition = ResourceUseDefinitionImpl;
            obj.AirProducerDefinition = ResourceUseDefinitionImpl;
            obj.BiomassProducerDefinition = ResourceUseDefinitionImpl;
            
%             for i = 1:length(shelves)
%                 shelves(i).AirConsumerDefinition.ResourceStore.MaxFlowRate = 
%             end
%             
            obj.Shelves = shelves;
            
        end
        
        %% tick
        % tick each shelf contained within the BiomassPS
        function obj = tick(obj)
           obj.currentTick = obj.currentTick+1; 
           
        end
    end
    
end

