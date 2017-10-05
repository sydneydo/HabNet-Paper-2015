classdef PLSS
    %PLSS Models different types of PLSS combinations
    %   By: Sydney Do (sydneydo@mit.edu)
    %   Date Created: 8/27/2014
    %   Last Updated: 8/27/2014
    %   All data used in this file was taken from the Hamilton Sundstrand
    %   EMU data book - Section 2.5.2
    %   The METOX canister removes CO2
    
    %   Two PLSS options are selected:
    %   Note that if the METOX system is selected, this implies that a
    %   sublimator is also selected for humidity control
    %   This humidity control function is also modeled here
    %   (Since this same function will be captured in the Rapid Cycle
    %   Amine)
    
    %   We treat the grey water store as the EMU liquid transport circuit
    %   feedwater tanks
    
    %   For now, we ignore the power requirements of the PLSS
    
    properties
        Type
        InputEnvironment        % Typically corresponds to EMU PGA
%         OutputEnvironment
        CO2Store
        HumidityCondensateStore
    end
    
    properties (SetAccess = private)
        METOXmaxAirFlowrate = 7*28.3168*60     % Liters/hour - converted from 7 cfm (cubic feet per minute) flows past the EMU METOX canister (REF: Section 2.5.2.2 EMU Handbook)
        RCAmaxAirFlowRate = 6*28.3168*60     % Liters/hour - converted from 6 cfm (cubic feet per minute) (REF: Section II-C - "Performance Characterization and Simulation of )
        MaxCO2capacity = 1.48*453.592/(12.011+2*15.999)   % moles - converted from 1.48lb - total CO2 removal capacity of the METOX canister (REF: Section 2.5.2.3 EMU Handbook)
        RCAco2SetLevel = 0.285309868;   % kPa - converted from 2.18mmHg ppCO2 - REF: "Performance Characterization and Simulation of Amine-Based Vacuum Swing Sorption Units for Spacesuit Carbon Dioxide and Humidity Control
        TargetVaporPressure = mean([1.2276, 1.7051])*0.4 %kPa,  - Dewpoint temp = 54.5Fahrenheit = 12.5C (ref: Section 2.1.2 EMU Handbook) --> Psat = ppH2O (for dewpoint (ie. RH = 100) )= mean([1.2276, 1.7051])kPa (From Saturated Water Table - Table A-15 Cengal and Turner 2nd Ed.)
        TargetRelativeHumidity = 0.4    % Fraction - from NASA HIDH Section 6.2.3.2
        RCAdewpointSetLevel
        idealGasConstant = 8.314;       % J/K/mol
        METOXcanisterMass = 32*0.453592      % (kg) converted from 32 pounds (REF: Section 2.5.2.1 EMU Handbook)
        SublimatorLeakRate = 0.57           % L/hr - REF: BVAD Section 5.2.2 - (No equivalent value provided in theEMU handbook value)
        SWMEwaterLeakRate = 2.1/7           % L/hr - converted from 2.1kg/7hr EVA, assuming water density of 1kg/L - REF: Impact of Water Recovery from Wastes on the Lunar Surface Mission Water Balance - AIAA 2010-6008
        RCAmass = 7.5                      % kg, REF - Table 3 - ICES-2014-196 Continued Development of the Rapid Cycle Amine System for Advanced Extravehicular Activity Systems
        SWMEmass = 1.87                     % kg, REF - Multifunctional Space Evaporator-Absorber-Radiator - AIAA 2013-3306
        SWMEvolume =  5.955                 % L, REF - Multifunctional Space Evaporator-Absorber-Radiator - AIAA 2013-3306
    end
    
    methods
        %% Constructor
        function obj = PLSS(inputEnvironment,type)
            obj.InputEnvironment = inputEnvironment;        % Input environment must be of type - SimEnvironmentImpl
            %             obj.OutputEnvironment = outputEnvironment;
            if ~(strcmpi(type,'METOX') || strcmpi(type,'RCA'))
                error('Second input must be of type "METOX" or "RCA"')
            end
            obj.Type = type;
            if strcmpi(type,'METOX')
                obj.CO2Store = StoreImpl('METOX CO2 Adsorbed','Material',obj.MaxCO2capacity,0);
                obj.HumidityCondensateStore = inputEnvironment.GreyWaterStore;
            elseif strcmpi(type,'RCA')
                obj.CO2Store = StoreImpl('RCA CO2 Vented','Environmental');
                obj.HumidityCondensateStore = StoreImpl('RCA H2O Vapor Vented','Environmental');
            end
        end
        
        %% Tick
        function CO2MolesAdsorbed = tick(obj)

            switch obj.Type
                
                case 'METOX'
                    
                    %% METOX Canister
                    
                    molesOfAirToTake = obj.InputEnvironment.pressure*obj.METOXmaxAirFlowrate/(obj.idealGasConstant*(273.15+obj.InputEnvironment.temperature));
                    
                    % CO2 moles to take is the minimum of the nominal CO2
                    % adsorption rate, and the amount of CO2 that the METOX
                    % canister can still hold
                    co2molesToTake = min([molesOfAirToTake*obj.InputEnvironment.CO2Percentage,obj.CO2Store.currentCapacity - obj.CO2Store.currentLevel]);
                    
                    % Take CO2 and vapor from molesOfAirToTake
                    CO2MolesAdsorbed = obj.InputEnvironment.CO2Store.take(co2molesToTake);
                                       
                    % Add CO2 to CO2 store
                    obj.CO2Store.add(CO2MolesAdsorbed);
                                        
                    % Warning for if METOX canister has reached its
                    % adsorption capacity
                    if obj.CO2Store.currentLevel >= obj.CO2Store.currentCapacity
                        disp(['EMU METOX Canister has reached its CO2 adsorption capacity at tick: ',...
                            num2str(obj.InputEnvironment.tickcount),...
                            '. No more CO2 can be adsorbed']);
                    end
                    
                    % Leak water (corresponds to sublimator water losses)
                    obj.InputEnvironment.GreyWaterStore.take(obj.SublimatorLeakRate);
                    
                    % Error for if feedwater tank is emptied
                    if obj.InputEnvironment.GreyWaterStore.currentLevel <= 0
                        disp(['EMU Feedwater tank has emptied on tick: ',...
                            num2str(obj.InputEnvironment.tickcount),...
                            '. Crewperson has 30 minutes to return to airlock'])
                    end
                    
                    %% Humidity Control
                    % Lower vapor moles to match target vapor pressure
                    vaporMolesToTake = max([0,obj.InputEnvironment.VaporPercentage*obj.InputEnvironment.pressure-obj.TargetVaporPressure])*...
                        obj.InputEnvironment.volume/(obj.idealGasConstant*(273.15+obj.InputEnvironment.temperature));
                    
                    % Take vapor moles from environment
                    VaporMolesTaken = obj.InputEnvironment.VaporStore.take(vaporMolesToTake);
                    
                    % Convert vapor moles to Liters of water and add to Grey Water
                    % Store
                    obj.HumidityCondensateStore.add(VaporMolesTaken*18.01524/1000);     % 1000g/Liter, 18.01524g/mole
                    
                    
                case 'RCA'
                % RCA code goes here
                % Based on the data in "Performance Characterization and
                % Simulation of Amine-Based Vacuum Swin Sorption Units for
                % Spacesuit Carbon Dioxide and Humidity Control"
                % (AIAA2012-3461), we will model the RCA as a system which
                % maintains a CO2 partial pressure of 2.14mm Hg and a dew
                % point of 2.6degrees F (corresponding to the variable 
                % transient metabolic rate experiment described in the 
                % paper. We will not explicitly model the amine bed 
                % cycling as this occurs over a period of ~4 minutes and 
                % our timestep is an hour long
                
                
                % Calculate CO2 moles to take based on maintaining the
                % ppCO2 at the level found during testing of the RCA
                co2molesToTake = max([0,obj.InputEnvironment.CO2Percentage*obj.InputEnvironment.pressure-obj.RCAco2SetLevel])*...
                    obj.InputEnvironment.volume/(obj.idealGasConstant*(273.15+obj.InputEnvironment.temperature));
                
                % Take co2molesToTake from environment and add them to
                % output CO2 store
                obj.CO2Store.add(obj.InputEnvironment.CO2Store.take(co2molesToTake));

                % Sublimator leak (corresponds to SWME losses)
                obj.InputEnvironment.GreyWaterStore.take(obj.SWMEwaterLeakRate);
                
                % Error for if feedwater tank is emptied
                if obj.InputEnvironment.GreyWaterStore.currentLevel <= 0
                    disp(['EMU Feedwater tank has emptied on tick: ',...
                        num2str(obj.InputEnvironment.tickcount),...
                        '. Crewperson has 30 minutes to return to airlock'])
                end
                
                %% Humidity Control
                % Lower vapor moles to match target vapor pressure
                vaporMolesToTake = max([0,obj.InputEnvironment.VaporPercentage*obj.InputEnvironment.pressure-obj.TargetVaporPressure])*...
                    obj.InputEnvironment.volume/(obj.idealGasConstant*(273.15+obj.InputEnvironment.temperature));
                obj.HumidityCondensateStore.add(obj.InputEnvironment.VaporStore.take(vaporMolesToTake));
            
            end
            
        end
            
    end
    
end

