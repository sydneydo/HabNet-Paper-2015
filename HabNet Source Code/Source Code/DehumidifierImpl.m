classdef DehumidifierImpl
    %DehumidifierImpl Summary of this class goes here
    %   By: Sydney Do (sydneydo@mit.edu)
    %   Date Created: 5/16/2014
    %   Last Updated: 5/16/2014
    
    
    %% Notes to convert to ISS CCAA
    % Peak power draw: 705W (BVAD Appendix A)
    % Average operational power draw: 469W (Corresponds to max fan (inlet
    % ORU) power consumption (REF: BVAD Appendix A)
    % From calculations of data given from pg 105 of Living Together in
    % Space:
    % Original quote:"For 12,716 L/min (430 cfm) airflow, the minimum by-pass flow is 850L/min (30 cfm) and the minimum HX flow is 1,444 L/min (51 cfm)."
    % Minimum flow through CCAA CHX is 1444L/min
    % Maximum flow through CCAA CHX is 12716-850 = 11866L/min
    
    % CCAA fan flow rate ranges from 8490L/min to 14150L/min
    
    properties
        % Consumer/Producer Definitions
        AirConsumerDefinition   % ResourceStore here is set to a SimEnvironment
        PowerConsumerDefinition     % Power to drive CCAA Inlet (Fan) ORU
        DirtyWaterProducerDefinition
    end
    
    properties (Access = private)
        optimal_moisture_concentration = 0.0218910; %in kPA assuming 101 kPa total pressure and air temperature of 23C and relative humidity of 80%
    end
    
    methods
        %% Constructor
        function obj = DehumidifierImpl
            obj.AirConsumerDefinition = ResourceUseDefinitionImpl;
            obj.PowerConsumerDefinition = ResourceUseDefinitionImpl;
            obj.DirtyWaterProducerDefinition = ResourceUseDefinitionImpl;
        end
        
        %% tick
        % this function followsthe DehumidifierImpl.dehumidifyEnvironment
        % method
        function tick(obj)
            
            % This line follows that of the calculateMolesNeededToRemove
            % method
            currentWaterMolesInEnvironment = obj.AirConsumerDefinition.ResourceStore.VaporStore.currentLevel;
            totalMolesInEnvironment = obj.AirConsumerDefinition.ResourceStore.totalMoles;
%             if obj.AirConsumerDefinition.ResourceStore.VaporPercentage > obj.optimal_moisture_concentration
%                 % Moles to remove = total vapor moles available - vapor
%                 % moles making up optimal vapor concentration in
%                 % environment
%                 molesNeededToRemove = currentWaterMolesInEnvironment-(totalMolesInEnvironment-currentWaterMolesInEnvironment)...
%                     *obj.optimal_moisture_concentration/(1-obj.optimal_moisture_concentration);
%                 
%                 % This assumes optimal vapor concentration to remove is fixed
%                 % according to a fixed ratio of atmospheric vapor to
%                 % remaining atmospheric gas (ie. total moles -vapor moles)
%             else
%                 molesNeededToRemove = 0;
%             end
            
%% Explanation for the above equation
% The moles calculated to be removed is such that after the moles are
% removed, the optimal concentration is obtained. We explain this further
% as follows:
% Let's assign variables to a few parameters
% V = current vapor moles
% T = current total moles
% dV = amount of vapor moles to be removed
% x = optimal moisture molar fraction = 0.0218910

% To obtain the optimal moisture ratio after some amount of vapor moles are
% removed, we want the following relationship to hold:
% x = (V-dV) / (T-dV)

% Solving for dV yields:
% dV = (V-Tx)/(1-x)

% We can put this in the form that is present in BioSim via the following
% algebraic manipulations:
% dV = (V-Vx+Vx-Tx)/(1-x)
% dV = (V(1-x)-x(T-V))/(1-x)
% dV = V - (T-V)x/(1-x) ... which is the BioSim form of this equation


%% Code continued

% Current dehumidifier code assumes no limitations on humidifier itself

            % Faster implementation of above if statement
            molesNeededToRemove = ((currentWaterMolesInEnvironment/totalMolesInEnvironment) > obj.optimal_moisture_concentration)*...
                (currentWaterMolesInEnvironment-(totalMolesInEnvironment-currentWaterMolesInEnvironment)...
                    *obj.optimal_moisture_concentration/(1-obj.optimal_moisture_concentration));
                
            % Currently this file coded to take air from only one environment
            % Take moles from SimEnvironment
            vaporMolesRemoved = obj.AirConsumerDefinition.ResourceStore.VaporStore.take(molesNeededToRemove,...
                obj.AirConsumerDefinition);
                
%             vaporMolesRemoved = 0;      % INCORRECT implementation that is currently used within BioSim
            
            % Push humidity condensate to dirty water store (note that we
            % convert from water moles to water liters here)
            obj.DirtyWaterProducerDefinition.ResourceStore.add(vaporMolesRemoved*18.01524/1000,...
                obj.DirtyWaterProducerDefinition);
            
        end
    end
    
end

