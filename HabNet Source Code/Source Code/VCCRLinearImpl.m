classdef VCCRLinearImpl
    %VCCRLinearImpl Summary of this class goes here
    %   By: Sydney Do (sydneydo@mit.edu)
    %   Date Created: 5/15/2014
    %   Last Updated: 5/15/2014
    %   Simplified linear version of the VCCR Implementation
    %   VCCR = Variable Configuration CO2 Removal
    %   This represents a 4BMS with a CO2 Store
    %   From Scott Bell: 
    %   Regarding the VCCR, the current default is just a linear model that
    %   takes 25.625 watts to scrub 1.2125 moles of air per tick (roughly 
    %   0.02844 moles of CO2 per tick). Boosting the power will make the 
    %   VCCR work harder.
    
    %   Note, this implementation assumes 100% CO2 removal efficiency
    
    properties
        % Consumer/Producer Definitions
        AirConsumerDefinition
        AirProducerDefinition
        CO2ProducerDefinition
        PowerConsumerDefinition
    end
    
    methods
        %% Constructor
        function obj = VCCRLinearImpl
            obj.AirConsumerDefinition = ResourceUseDefinitionImpl;
            obj.AirProducerDefinition = ResourceUseDefinitionImpl;
            obj.CO2ProducerDefinition = ResourceUseDefinitionImpl;
            obj.PowerConsumerDefinition = ResourceUseDefinitionImpl;
        end
        
        %% tick
        function tick(obj)
           % The code written below follows the VCCRLinearImpl.tick method 
           currentPowerConsumed = obj.PowerConsumerDefinition.ResourceStore.take(obj.PowerConsumerDefinition.MaxFlowRate,obj.PowerConsumerDefinition);     % Take power
           
%            % Error source
%            if currentPowerConsumed == 0
%                disp('VCCR has switched off due to zero power draw')
%            end
           
           %gatherCO2(obj);
           molesAirNeeded = (currentPowerConsumed / 25.625)*1.2125*100; % moles of air taken from environment is tuned to 25.625watts for 1.2125 moles of air per tick
           
           % Define molar percentages internally to avoid errors from
           % auto updating after taking constituents
           O2percentage =  obj.AirConsumerDefinition.ResourceStore.O2Percentage;
           CO2percentage = obj.AirConsumerDefinition.ResourceStore.CO2Percentage;
           N2percentage = obj.AirConsumerDefinition.ResourceStore.N2Percentage;
           Vaporpercentage = obj.AirConsumerDefinition.ResourceStore.VaporPercentage;
           Otherpercentage = obj.AirConsumerDefinition.ResourceStore.OtherPercentage;
           
           % Get air from AirConsumerDefinition.ResourceStore
           currentO2Consumed = obj.AirConsumerDefinition.ResourceStore.O2Store.take(molesAirNeeded*...
               O2percentage,obj.AirConsumerDefinition);
           currentCO2Consumed = obj.AirConsumerDefinition.ResourceStore.CO2Store.take(molesAirNeeded*...
               CO2percentage,obj.AirConsumerDefinition);
           currentN2Consumed = obj.AirConsumerDefinition.ResourceStore.NitrogenStore.take(molesAirNeeded*...
               N2percentage,obj.AirConsumerDefinition);
           currentVaporConsumed = obj.AirConsumerDefinition.ResourceStore.VaporStore.take(molesAirNeeded*...
               Vaporpercentage,obj.AirConsumerDefinition);
           currentOtherConsumed = obj.AirConsumerDefinition.ResourceStore.OtherStore.take(molesAirNeeded*...
               Otherpercentage,obj.AirConsumerDefinition);
           
           % Push air constituents (minus CO2) to AirProducerDefinition.ResourceStore
           obj.AirProducerDefinition.ResourceStore.O2Store.add(currentO2Consumed);
           obj.AirProducerDefinition.ResourceStore.NitrogenStore.add(currentN2Consumed);
           obj.AirProducerDefinition.ResourceStore.VaporStore.add(currentVaporConsumed);
           obj.AirProducerDefinition.ResourceStore.OtherStore.add(currentOtherConsumed);
           
           % Push CO2 to CO2 Store
           obj.CO2ProducerDefinition.ResourceStore.add(currentCO2Consumed,obj.CO2ProducerDefinition);
        end
    end
    
end

