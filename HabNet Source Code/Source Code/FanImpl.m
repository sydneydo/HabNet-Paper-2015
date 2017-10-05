classdef FanImpl
    %Fan Summary of this class goes here
    %   The basic fan implementation
    %   The fan moves moles of air from one environment to another
    %   By: Sydney Do (sydneydo@mit.edu)
    %   Date Created: 5/15/2014
    %   Last Updated: 5/15/2014
    
    properties
        % Consumer/Producer Definitions
        AirConsumerDefinition% = ResourceUseDefinitionImpl
        AirProducerDefinition% = ResourceUseDefinitionImpl
        PowerConsumerDefinition% = ResourceUseDefinitionImpl
    end
    
    properties (SetAccess = private)
        ISS_IMV_FlowRate = 3964*60      % 3964L/min according Section 2, Chapter 3.2.6, Living Together in Space...
        idealGasConstant = 8.314
    end
    
    methods
        %% Constructor
        function obj = FanImpl
            obj.AirConsumerDefinition = ResourceUseDefinitionImpl;
            obj.AirProducerDefinition = ResourceUseDefinitionImpl;
            obj.PowerConsumerDefinition = ResourceUseDefinitionImpl;
        end
        
        %% tick
        function tick(obj)
            % The code written below follows the FanImpl.getAndPushAir method 
            currentPowerConsumed = obj.PowerConsumerDefinition.ResourceStore.take(obj.PowerConsumerDefinition.MaxFlowRate,obj.PowerConsumerDefinition);     % Take power
            currentMolesOfAirConsumed = obj.calculateAirToConsume(currentPowerConsumed);        % in moles
            AirToTake = min([currentMolesOfAirConsumed,obj.AirConsumerDefinition.DesiredFlowRate,obj.AirConsumerDefinition.MaxFlowRate]);
            
            AirMolesToTake = obj.ISS_IMV_FlowRate*obj.AirConsumerDefinition.ResourceStore.pressure/obj.idealGasConstant/(obj.AirConsumerDefinition.ResourceStore.temperature+273.15);
                        
            % Define molar percentages internally to avoid errors from
            % auto updating after taking constituents
            O2percentage =  obj.AirConsumerDefinition.ResourceStore.O2Percentage;
            CO2percentage = obj.AirConsumerDefinition.ResourceStore.CO2Percentage;
            N2percentage = obj.AirConsumerDefinition.ResourceStore.N2Percentage;
            Vaporpercentage = obj.AirConsumerDefinition.ResourceStore.VaporPercentage;
            Otherpercentage = obj.AirConsumerDefinition.ResourceStore.OtherPercentage;
            
            % Get air from AirConsumerDefinition.ResourceStore
            currentO2Consumed = obj.AirConsumerDefinition.ResourceStore.O2Store.take(AirToTake*...
                O2percentage);
            currentCO2Consumed = obj.AirConsumerDefinition.ResourceStore.CO2Store.take(AirToTake*...
                CO2percentage);
            currentN2Consumed = obj.AirConsumerDefinition.ResourceStore.NitrogenStore.take(AirToTake*...
                N2percentage);
            currentVaporConsumed = obj.AirConsumerDefinition.ResourceStore.VaporStore.take(AirToTake*...
                Vaporpercentage);
            currentOtherConsumed = obj.AirConsumerDefinition.ResourceStore.OtherStore.take(AirToTake*...
                Otherpercentage);
            
            % Push air to AirProducerDefinition.ResourceStore
            obj.AirProducerDefinition.ResourceStore.O2Store.add(currentO2Consumed);
            obj.AirProducerDefinition.ResourceStore.CO2Store.add(currentCO2Consumed);
            obj.AirProducerDefinition.ResourceStore.NitrogenStore.add(currentN2Consumed);
            obj.AirProducerDefinition.ResourceStore.VaporStore.add(currentVaporConsumed);
            obj.AirProducerDefinition.ResourceStore.OtherStore.add(currentOtherConsumed);
            
        end
    end
    
    %% Static Methods
    methods (Static)
        function airMolesConsumed = calculateAirToConsume(powerConsumed)
            airMolesConsumed = 4*powerConsumed;
        end
    end
    
end

