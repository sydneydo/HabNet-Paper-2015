classdef ISSFanImpl2 < handle
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
    
%% Notes
    
% NB. Under normal power consumption conditions, the ISS IMV fan moves 
% approx. 6791 moles of air every hour
% As a result, we modify the max and desired molar flow rates to meet this
% number
% Desired is rounded up to 6800moles/hr, and the max corresponds to the max
% volumetric flow rate of 4106L/min indicated within Section 2, Chapter
% 3.2.6 of "Living Together In Space"
% 4106L/min*60min/hr*70.3kPa/(8.314J/K/mol*296.15K) = 7034mol/hr (we round
% this up to 7035mol/hr)

%% Code
    
    properties
        % Consumer/Producer Definitions
        Environment1
        Environment2
        PowerConsumerDefinition
    end
    
    properties (SetAccess = private)
        ISS_IMV_VolFlowRate = 3964*60       % 3964L/min*60 = L/hr according Section 2, Chapter 3.2.6, Living Together in Space... (note. PV: kPA*L = Pa*m^3)
        ISS_IMV_PowerConsumption = 55       % in watts, continuous
        idealGasConstant = 8.314            % J/K/mol
%         nominalCabinPressure = 70.3
    end
    
    methods
        %% Constructor
        function obj = ISSFanImpl2(environment1,environment2,PowerSource)
            
            if ~(strcmpi(class(environment1),'SimEnvironmentImpl') || strcmpi(class(environment2),'SimEnvironmentImpl'))
                error('First two inputs must be of type "SimEnvironmentImpl"')
            elseif ~strcmpi(class(PowerSource),'StoreImpl')
                error('Third input must be of type "StoreImpl"')
            end
            
            obj.Environment1 = environment1;
            obj.Environment2 = environment2;
            obj.PowerConsumerDefinition = ResourceUseDefinitionImpl(PowerSource);
        end
        
        %% tick
        function AirToExchange = tick(obj)
            
            % Identify air from Environment 1 to move to Environment 2
            Environment1CurrentPowerConsumed = obj.PowerConsumerDefinition.ResourceStore.take(obj.ISS_IMV_PowerConsumption);     % Take power
            Environment1MolesOfAirConsumed = calculateAirToConsume(obj,Environment1CurrentPowerConsumed,obj.Environment1);        % in moles
            
            % Identify air from Environment 2 to move to Environment 1
            Environment2CurrentPowerConsumed = obj.PowerConsumerDefinition.ResourceStore.take(obj.ISS_IMV_PowerConsumption);     % Take power
            Environment2MolesOfAirConsumed = calculateAirToConsume(obj,Environment2CurrentPowerConsumed,obj.Environment2);        % in moles
            
            AirToExchange = min([Environment1MolesOfAirConsumed,Environment2MolesOfAirConsumed]);
                        
            %% Define molar percentages internally to avoid errors from
            % auto updating after taking constituents
            
            % Environment 1
            O2percentageEnv1 =  obj.Environment1.O2Percentage;
            CO2percentageEnv1 = obj.Environment1.CO2Percentage;
            N2percentageEnv1 = obj.Environment1.N2Percentage;
            VaporpercentageEnv1 = obj.Environment1.VaporPercentage;
            OtherpercentageEnv1 = obj.Environment1.OtherPercentage;
            
            % Environment 2
            O2percentageEnv2 =  obj.Environment2.O2Percentage;
            CO2percentageEnv2 = obj.Environment2.CO2Percentage;
            N2percentageEnv2 = obj.Environment2.N2Percentage;
            VaporpercentageEnv2 = obj.Environment2.VaporPercentage;
            OtherpercentageEnv2 = obj.Environment2.OtherPercentage;
            
            %% Take air from environmental stores
            
            % Environment 1
            currentO2ConsumedEnv1 = obj.Environment1.O2Store.take(AirToExchange*O2percentageEnv1);
            currentCO2ConsumedEnv1 = obj.Environment1.CO2Store.take(AirToExchange*CO2percentageEnv1);
            currentN2ConsumedEnv1 = obj.Environment1.NitrogenStore.take(AirToExchange*N2percentageEnv1);
            currentVaporConsumedEnv1 = obj.Environment1.VaporStore.take(AirToExchange*VaporpercentageEnv1);
            currentOtherConsumedEnv1 = obj.Environment1.OtherStore.take(AirToExchange*OtherpercentageEnv1);
            
            % Environment 2
            currentO2ConsumedEnv2 = obj.Environment2.O2Store.take(AirToExchange*O2percentageEnv2);
            currentCO2ConsumedEnv2 = obj.Environment2.CO2Store.take(AirToExchange*CO2percentageEnv2);
            currentN2ConsumedEnv2 = obj.Environment2.NitrogenStore.take(AirToExchange*N2percentageEnv2);
            currentVaporConsumedEnv2 = obj.Environment2.VaporStore.take(AirToExchange*VaporpercentageEnv2);
            currentOtherConsumedEnv2 = obj.Environment2.OtherStore.take(AirToExchange*OtherpercentageEnv2);
            
            %% Push collected air to adjacent Environment
            
            % Push air collected from Environment 1 to Environment 2
            obj.Environment2.O2Store.add(currentO2ConsumedEnv1);
            obj.Environment2.CO2Store.add(currentCO2ConsumedEnv1);
            obj.Environment2.NitrogenStore.add(currentN2ConsumedEnv1);
            obj.Environment2.VaporStore.add(currentVaporConsumedEnv1);
            obj.Environment2.OtherStore.add(currentOtherConsumedEnv1);
            
            % Push air collected from Environment 2 to Environment 1
            obj.Environment1.O2Store.add(currentO2ConsumedEnv2);
            obj.Environment1.CO2Store.add(currentCO2ConsumedEnv2);
            obj.Environment1.NitrogenStore.add(currentN2ConsumedEnv2);
            obj.Environment1.VaporStore.add(currentVaporConsumedEnv2);
            obj.Environment1.OtherStore.add(currentOtherConsumedEnv2);
            
        end
    end
    
    %% Methods
    methods %(Static)
        % We rewrite this function to correspond to the ISS Intermodule
        % Ventilation Fans to produce a nominal flowrate of 3964L/min
        % at 55W continuous power consumption
        function airMolesConsumed = calculateAirToConsume(obj,powerConsumed,environment)
%             airMolesConsumed = 4*powerConsumed;       % Original
            
%             cabinPressure = obj.AirConsumerDefinition.ResourceStore.pressure;        % in kPa
            cabinTempInKelvin = environment.temperature+273.15;     % in Kelvin
            
            
            %   pv = nRT
            %   n = PV/RT
            % Apply ideal gas law to find number of moles based on 
            % volumetric flow rate and scale air moles consumed by power 
            % consumed
            fanMolesConsumed = powerConsumed/obj.ISS_IMV_PowerConsumption*...
                (environment.pressure*obj.ISS_IMV_VolFlowRate/(obj.idealGasConstant*cabinTempInKelvin));
            
            % Under normal power consumption conditions, approx. 6791 moles
            % of air are moved every hour
                        
            % airMolesConsumed is the minimum between that calculated by
            % the nominal ISS fan, and the totalMoles available within the
            % environment
            airMolesConsumed = min([fanMolesConsumed,environment.totalMoles]);
            
            
        end
    end
    
end

