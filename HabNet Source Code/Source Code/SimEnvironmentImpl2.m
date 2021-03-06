classdef SimEnvironmentImpl2 < handle
    %SimEnvironmentImpl Summary of this class goes here
    %   By: Sydney Do (sydneydo@mit.edu)
    %   Revision History
    %   Last Updated: 8/16/2014
    %   8/16/2014: Modified to contain food, water, and waste stores for
    %   inhabitants to consume from when they are located within this
    %   environment
    %   5/15/2014: Added performLeak method and revised update of tick
    %   4/21/2014: Added tick method

    %% You could probably speed up a lot of the code by having the time 
    % horizon as an input to this class definition and precalculating things like 
    % the light intensity spectrum
    
    properties
        name = 'default SimEnvironment'
        id = 0
        tickcount = 0
        volume                  % in liters
        temperature = 23        % in Celsius
        maxlumens = 50000       % default value declared in Environment.xsd schema file - used for generating solar power
        leakagePercentage = 0;     % 0.05/24 nominal value, according to Table 4.1.1 of BVAD
    end

    properties (Dependent = true, SetAccess = private)
        lightIntensity          % used for solar power collection
        pressure        % in Pa
        RelativeHumidity
        O2Percentage
        CO2Percentage
        N2Percentage
        VaporPercentage
        OtherPercentage
        totalMoles
    end
        
    properties (SetAccess = private)
%         leakRate = 0;   % mol/hr
        
        DangerousOxygenThreshold = 0.3;   % threshold at which O2 molar fraction imposes a danger (fire hazard) - fix this later! (changed from 1 to 0.3 on 8/7/14 - 30% corresponds to EAWG report - Figure 4.1-1 - "Lange's Flammability Limit")
    end
    
    properties
        % Atmospheric Stores
        O2Store% = StoreImpl('O2','Environmental')
        CO2Store% = StoreImpl('CO2','Environmental')
        NitrogenStore% = StoreImpl('N2','Environmental')
        VaporStore% = StoreImpl('H2O Vapor','Environmental')
        OtherStore% = StoreImpl('Other','Environmental')      % Represents trace contaminants   
%         Air = Atmosphere
        PotableWaterStore
        GreyWaterStore
        DirtyWaterStore
        DryWasteStore
        FoodStore
    end
    
    properties (Access = private)
%         o2Percentage
        idealGasConstant = 8.314;   % J/K/mol
        dayLength = 24;             % Length of day in hours - used to simulate light cycle for solar power collection. 24hours is the default value declared in Environment.xsd schema file
        hourOfDayStart = 0;         % Start hour of day - used to simulate light cycle for solar power collection. 0hours is the default value declared in Environment.xsd schema file 
    end
    
    methods
        function obj = SimEnvironmentImpl2(name,pressure,volume,o2Percentage,co2Percentage,nitrogenPercentage,waterPercentage,...
                otherPercentage,leakPercentage,potablewaterstore,greywaterstore,dirtywaterstore,drywastestore,foodstore)
            
            if nargin > 0
                
                obj.name = name;
                %             obj.pressure = pressure;
                obj.volume = volume;        % this is input in Liters
                obj.O2Store = StoreImpl('O2','Environmental');
                obj.CO2Store = StoreImpl('CO2','Environmental');
                obj.NitrogenStore = StoreImpl('N2','Environmental');
                obj.VaporStore = StoreImpl('H2O Vapor','Environmental');
                obj.OtherStore = StoreImpl('Other','Environmental');
                
                obj.O2Store.currentLevel = CalculateMoles(obj,o2Percentage, pressure, volume);
                obj.CO2Store.currentLevel = CalculateMoles(obj,co2Percentage, pressure, volume);
                obj.NitrogenStore.currentLevel = CalculateMoles(obj,nitrogenPercentage, pressure, volume);
                obj.VaporStore.currentLevel = CalculateMoles(obj,waterPercentage, pressure, volume);
                obj.OtherStore.currentLevel = CalculateMoles(obj,otherPercentage, pressure, volume);
                
                % Set current capacities of StoreImpl objects to equal their
                % current levels - i.e. can't take more from store than what's
                % already there, but you can add more than what's there
                % Enforce this constraint for every time step
                obj.O2Store.currentCapacity = obj.O2Store.currentLevel;
                obj.CO2Store.currentCapacity = obj.CO2Store.currentLevel;
                obj.NitrogenStore.currentCapacity = obj.NitrogenStore.currentLevel;
                obj.VaporStore.currentCapacity = obj.VaporStore.currentLevel;
                obj.OtherStore.currentCapacity = obj.OtherStore.currentLevel;
            
                if nargin > 8
                    obj.leakagePercentage = leakPercentage;
                end
                
                if nargin > 9
                    % Check for correct input class for water, food, and waste
                    % stores
                    if ~strcmpi(class(potablewaterstore),'StoreImpl') || ...
                            ~strcmpi(class(greywaterstore),'StoreImpl') || ...
                            ~strcmpi(class(dirtywaterstore),'StoreImpl') || ...
                            ~strcmpi(class(drywastestore),'StoreImpl')                       
                        error('Tenth to Thirteenth inputs to SimEnvironmentImpl must be of class "StoreImpl"');
                    elseif ~strcmpi(class(foodstore),'FoodStoreImpl')
                        error('Fourteenth input to SimEnvironmentImpl must be of class "FoodStoreImpl"');
                    end
                    
                    obj.PotableWaterStore = potablewaterstore;
                    obj.GreyWaterStore = greywaterstore;
                    obj.DirtyWaterStore = dirtywaterstore;
                    obj.DryWasteStore = drywastestore;
                    obj.FoodStore = foodstore;
                    
                end
            
            end

 
        end
        
        % Calculates total moles in SimEnvironment
        function totalmoles = get.totalMoles(obj)
            totalmoles = obj.O2Store.currentLevel+obj.CO2Store.currentLevel+obj.NitrogenStore.currentLevel+...
                obj.VaporStore.currentLevel+obj.OtherStore.currentLevel;
        end
        
        % Calculates current light intensity within SimEnvironment
        % Assumes that the light intensity follows a Sine squared profile
        % we can adjust this later on to get a better representation 
        function light = get.lightIntensity(obj)
            light = obj.maxlumens*sin(pi/obj.dayLength*(obj.tickcount - obj.hourOfDayStart))^2;
        end
            
        % Calculates total pressure in SimEnvironment (using ideal gas law)
        function pres = get.pressure(obj)
            pres = obj.totalMoles*obj.idealGasConstant*(obj.temperature + 273.15)/obj.volume;
        end
        
        % Calculates relative humidity within SimEnvironment
        function relativeHumidity = get.RelativeHumidity(obj)
            saturatedVaporPressure = 0.611*exp(17.4*obj.temperature/(obj.temperature+273.15));      % Is there a unit conversion issue here?
            VaporPartialPressure = obj.VaporPercentage*obj.pressure;
            relativeHumidity = VaporPartialPressure/saturatedVaporPressure;
        end
        
        % Calculates O2 molar percentage within SimEnvironment
        function o2percentage = get.O2Percentage(obj)
            o2percentage = obj.O2Store.currentLevel/(obj.O2Store.currentLevel+obj.CO2Store.currentLevel+obj.NitrogenStore.currentLevel+...
                obj.VaporStore.currentLevel+obj.OtherStore.currentLevel);
        end
        
        % Calculates CO2 molar percentage within SimEnvironment
        function co2percentage = get.CO2Percentage(obj)
            co2percentage = obj.CO2Store.currentLevel/(obj.O2Store.currentLevel+obj.CO2Store.currentLevel+obj.NitrogenStore.currentLevel+...
                obj.VaporStore.currentLevel+obj.OtherStore.currentLevel);
        end
        
        % Calculates N2 molar percentage within SimEnvironment
        function N2percentage = get.N2Percentage(obj)
            N2percentage = obj.NitrogenStore.currentLevel/(obj.O2Store.currentLevel+obj.CO2Store.currentLevel+obj.NitrogenStore.currentLevel+...
                obj.VaporStore.currentLevel+obj.OtherStore.currentLevel);
        end
        
        % Calculates water vapor molar percentage within SimEnvironment
        function vaporpercentage = get.VaporPercentage(obj)
            vaporpercentage = obj.VaporStore.currentLevel/(obj.O2Store.currentLevel+obj.CO2Store.currentLevel+obj.NitrogenStore.currentLevel+...
                obj.VaporStore.currentLevel+obj.OtherStore.currentLevel);
        end
        
        % Calculates other molar percentage within SimEnvironment
        function otherpercentage = get.OtherPercentage(obj)
            otherpercentage = obj.OtherStore.currentLevel/(obj.O2Store.currentLevel+obj.CO2Store.currentLevel+obj.NitrogenStore.currentLevel+...
                obj.VaporStore.currentLevel+obj.OtherStore.currentLevel);
        end
        
        % Calculate Moles
        function numMoles = CalculateMoles(obj, FractionalPercentage, TotalPressure, Volume)
            numMoles = (FractionalPercentage*TotalPressure*Volume)/(obj.idealGasConstant*(obj.temperature+273.15));
        end
        
        % Set Leakage Percentage
        function set.leakagePercentage(obj,inputPercentage)
            obj.leakagePercentage = inputPercentage;
        end
        
        %% PerformLeak
        function performLeak(obj)
            % Based on a leakage percentage
            obj.O2Store.take(obj.O2Store.currentLevel*obj.leakagePercentage/100);
            obj.CO2Store.take(obj.CO2Store.currentLevel*obj.leakagePercentage/100);
            obj.NitrogenStore.take(obj.NitrogenStore.currentLevel*obj.leakagePercentage/100);
            obj.VaporStore.take(obj.VaporStore.currentLevel*obj.leakagePercentage/100);
            obj.OtherStore.take(obj.OtherStore.currentLevel*obj.leakagePercentage/100);
        end
        
    end
        
    % Method to track ticks in SimEnvironment
    methods %(Static)
        function obj = tick(obj)
            % Update system tick
            obj.tickcount = obj.tickcount + 1;
%             % Update tickcounts of stores (using value from previous line)
%             obj.O2Store.tickcount = obj.tickcount;
%             obj.CO2Store.tickcount = obj.tickcount;
%             obj.NitrogenStore.tickcount = obj.tickcount;
%             obj.VaporStore.tickcount = obj.tickcount;
%             obj.OtherStore.tickcount = obj.tickcount;
            
            % Store.tick (accounts for resupply)          
            obj.O2Store = obj.O2Store.tick(obj.tickcount);
            obj.CO2Store = obj.CO2Store.tick(obj.tickcount);
            obj.NitrogenStore = obj.NitrogenStore.tick(obj.tickcount);
            obj.VaporStore = obj.VaporStore.tick(obj.tickcount);
            obj.OtherStore = obj.OtherStore.tick(obj.tickcount);
            
            % Update SimEnvironment Pressure
            % Perform Leak
            performLeak(obj)
            % Airlock operations and leakage
            
        end
        
    end
    
    
end

