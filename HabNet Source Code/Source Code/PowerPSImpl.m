classdef PowerPSImpl
    %PowerPSImpl Summary of this class goes here
    %   By: Sydney Do (sydneydo@mit.edu)
    %   Date Created: 5/15/2014
    %   Last Updated: 5/15/2014
    %
    %   From: BioSim Code
    %   The Power Production System creates power from a generator (say a solar
    %   panel) and stores it in the power store. This provides power to all the
    %   biomodules in the system.
    %   Three options for power production systems are captured here:
    %   - Solar
    %   - Nuclear
    %   - State Machine - we ignore this option here
    
    properties
        Type                            % Type of Power Production System
        UpperPowerGeneration = 500      % Default upper bound on power generation
        
        % Consumer/Producer Definitions
        PowerProducerDefinition
        LightConsumerDefinition        
    end
    
    methods
        %% Constructor
        function obj = PowerPSImpl(type,uppergeneration)
            if ~(strcmpi(type,'Nuclear') ||...
                    strcmpi(type,'Solar'))% ||...
                    %strcmpi(type,'State Machine'))
                error('Type must be declared as one of "Nuclear", "Solar", "State Machine"')
            end
            obj.Type = type;
            obj.UpperPowerGeneration = uppergeneration;
            obj.PowerProducerDefinition = ResourceUseDefinitionImpl;
%             obj.LightConsumerDefinition = SimEnvironmentImpl;
%% TO DO: possibly improve by adding a SimEnvironment as an input to the constructor and using this to declare
% obj.LightConsumerDefinition
        end
        
        %% tick
        % This code is taken from PowerPSImpl.tick
        % When ticked, the PowerPS creates power and places it into the
        % power store
        function tick(obj)
%             currentPowerProduced = calculatePowerProduced
            if strcmpi(obj.Type,'Nuclear')
                currentPowerProduced = obj.UpperPowerGeneration;
            else strcmpi(obj.Type,'Solar')
                if obj.LightConsumerDefinition.ResourceStore.currentLevel > 0
                    currentPowerProduced = obj.UpperPowerGeneration*obj.LightConsumerDefinition.lightIntensity/...
                        obj.LightConsumerDefinition.maxlumens;      % Max power that can be produced is proportional to the max sunlight available
                else
                    error('No light input for Solar Power production system')
                end
            end
            
            % Send currentPowerProduced to power store within
            % PowerProducerDefinition
            obj.PowerProducerDefinition.ResourceStore.add(currentPowerProduced,obj.PowerProducerDefinition);
        end
    end
    
end

