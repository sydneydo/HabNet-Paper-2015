classdef ISSFanImpl < handle
    %Fan Summary of this class goes here
    %   Implementation of the ISS Intermodule Ventilation (IMV) Fan
    %   The fan moves moles of air from one environment to another
    %   Data for the ISS IMV fan is taken from "Living Together in Space"
    %   Section 2, Chapter 3.2.6
    %   Key data is that the IMV flow rate ranges from 3823-4106L/min,
    %   nominally at 3964L/min, consuming 55W power continuously (for a
    %   1 atm environment). 
    %   Max flow rate is 4106L/min
    %
    %   We assume the same flow rate in a 70.3kPa
    %   environment for Mars One
    %
    %   By: Sydney Do (sydneydo@mit.edu)
    %   Date Created: 8/4/2014
    %   Last Updated: 8/4/2014
    
    properties
        % Consumer/Producer Definitions
        AirConsumerDefinition
        AirProducerDefinition
        PowerConsumerDefinition
    end
    
    properties (SetAccess = private)
        ISS_IMV_VolFlowRate = 3964*60       % 3964L/min*60 = L/hr according Section 2, Chapter 3.2.6, Living Together in Space... (note. PV: kPA*L = Pa*m^3)
        ISS_IMV_PowerConsumption = 55       % in watts, continuous
        idealGasConstant = 8.314            % J/K/mol
        nominalCabinPressure = 70.3
    end
    
    methods
        %% Constructor
        function obj = ISSFanImpl
            obj.AirConsumerDefinition = ResourceUseDefinitionImpl;
            obj.AirProducerDefinition = ResourceUseDefinitionImpl;
            obj.PowerConsumerDefinition = ResourceUseDefinitionImpl;
        end
        
        %% tick
        function tick(obj)
            % The code written below follows the FanImpl.getAndPushAir method 
            currentPowerConsumed = obj.PowerConsumerDefinition.ResourceStore.take(obj.PowerConsumerDefinition.MaxFlowRate,obj.PowerConsumerDefinition);     % Take power
            currentMolesOfAirConsumed = calculateAirToConsume(obj,currentPowerConsumed);        % in moles
            AirToTake = min([currentMolesOfAirConsumed,obj.AirConsumerDefinition.DesiredFlowRate,obj.AirConsumerDefinition.MaxFlowRate]);
                        
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
    methods %(Static)
        % We rewrite this function to correspond to the ISS Intermodule
        % Ventilation Fans to produce a nominal flowrate of 3964L/min
        % at 55W continuous power consumption
        function airMolesConsumed = calculateAirToConsume(obj,powerConsumed)
%             airMolesConsumed = 4*powerConsumed;       % Original
            
%             cabinPressure = obj.AirConsumerDefinition.ResourceStore.pressure;        % in kPa
            cabinTempInKelvin = obj.AirConsumerDefinition.ResourceStore.temperature+273.15;     % in Kelvin
            
            
            %   pv = nRT
            %   n = PV/RT
            % Apply ideal gas law to finc number of moles based on 
            % volumetric flow rate and scale air moles consumed by power 
            % consumed
            airMolesConsumed = powerConsumed/obj.ISS_IMV_PowerConsumption*...
                (obj.nominalCabinPressure*obj.ISS_IMV_VolFlowRate/(obj.idealGasConstant*cabinTempInKelvin));
            
            % Under normal power consumption conditions, approx. 6791 moles
            % of air are moved every hour
            
        end
    end
    
end

