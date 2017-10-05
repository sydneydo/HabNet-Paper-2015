classdef CO2Injector
    %CO2injector Summary of this class goes here
    %   Injects CO2 into the plant environment to maintain the ideal molar
    %   fraction
    %   We assume that there are no limitations on injection flow rate
    
    properties
        Environment
        CO2Store
        TargetMolarFraction
    end
    
    methods
        %% Constructor
        function obj = CO2Injector(environment,co2Store,targetmolarfraction)
            obj.Environment = environment;
            obj.CO2Store = co2Store;
            obj.TargetMolarFraction = targetmolarfraction;
        end
        
        %% Tick
        function co2injected = tick(obj)
            CO2toInject = (obj.TargetMolarFraction*obj.Environment.totalMoles-obj.Environment.CO2Store.currentLevel)/(1-obj.TargetMolarFraction);
            % Add line to take CO2 from a CO2 store - for Mars, we can asume that CO2 is taken from the local atmospheric environment 
            co2injected = obj.Environment.CO2Store.add(CO2toInject);
        end
    end
    
end

