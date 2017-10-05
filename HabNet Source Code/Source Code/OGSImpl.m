classdef OGSImpl < handle
    %OGSImpl Simple Implementation of an oxygen generation system
    %   (Using electrolysis - assuming 100% conversion efficiency)
    %   By: Sydney Do (sydneydo@mit.edu)
    %   Date Created: 5/16/2014
    %   Last Updated: 5/16/2014
    
    properties
%         ProductionRate = 1;         % BioSim has a ProductionRate value
%         which is a multiplier on the amount of O2 generated. This is not
%         included here as this breaks the mass conservation (production
%         becomes independent of input flow rate)
        PowerConsumerDefinition
        PotableWaterConsumerDefinition
        O2ProducerDefinition
        H2ProducerDefinition
    end
    
    methods
        %% Constructor
        function obj = OGSImpl
            obj.PowerConsumerDefinition = ResourceUseDefinitionImpl;
            obj.PotableWaterConsumerDefinition = ResourceUseDefinitionImpl;
            obj.O2ProducerDefinition = ResourceUseDefinitionImpl;
            obj.H2ProducerDefinition = ResourceUseDefinitionImpl;
        end
        
        %% tick
        function tick(obj)
            % gatherPower()
            currentPowerConsumed = obj.PowerConsumerDefinition.ResourceStore.take(obj.PowerConsumerDefinition.MaxFlowRate,obj.PowerConsumerDefinition);     % Take power
            
            % gatherWater()
            % This is tuned to requiring 75 Watts to process 0.04167L of
            % water
            waterToConsume = (currentPowerConsumed / 75) * 0.04167;
            
            % Take H2O from potable water store (in liters)
            currentH2OConsumed = obj.PotableWaterConsumerDefinition.ResourceStore.take(waterToConsume,obj.PotableWaterConsumerDefinition);
            
            % pushGasses()
            % Follows stoichiometric ratio: 2H2O --> 2H2 + O2
            molesOfWater = (currentH2OConsumed * 1000) / 18.01524; %1000g/liter, 18.01524g/mole
%             currentO2Produced = molesOfWater/2;
%             currentH2Produced = molesOfWater;
            
            % Push to Stores (note that capacity in these stores is
            % measures in moles)
            obj.O2ProducerDefinition.ResourceStore.add(molesOfWater/2,obj.O2ProducerDefinition);
            obj.H2ProducerDefinition.ResourceStore.add(molesOfWater,obj.H2ProducerDefinition);
            
        end
    end
    
end

