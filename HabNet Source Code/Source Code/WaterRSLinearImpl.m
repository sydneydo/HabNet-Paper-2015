classdef WaterRSLinearImpl
    %WaterRSLinear Summary of this class goes here
    %   By: Sydney Do (sydneydo@mit.edu)
    %   Date Created: 5/16/2014
    %   Last Updated: 5/16/2014
    %   This is a simple implementation of a water processing system
    %   Taken from comments in BioSim code:
    %   The Water Recovery System takes grey (humidity condensate)/dirty 
    %   (urine) water and refines it to potable water for the crew members 
    %   and grey water for the crops.. 
    %   Class modeled after the paper:. "Intelligent Control of a Water 
    %   Recovery System: Three Years in the Trenches" by Bonasso, 
    %   Kortenkamp, and Thronesbery
    
    %   Note this implementation assumes 100% water processing efficiency
    
    %% Notes to tune to the ISS UPA and WPA
    % From: "ECLSS Design for the International Space Station Nodes 2 and 3":
    % Urine is plumbed from the W&HC's urinal to the Urine Processor Assembly (UPA) portion of the WRS. 
    % The product distillate from this process is combined with other wastewater and further processed 
    % by the Water Processor Assembly (WPA). The WPA processes up to 93.4 kg/day (206 lb/day) wastewater [5]

    % From ISS Water Balance Operations:
    % UPA feeds about 4.5L of urine condensate per day to the WPA

    % From: Status of ISS Water Management and Recovery 2012
    % "The UPA was designed to process a nominal load of 9 kg/day (19.8 lbs/day) of wastewater consisting 
    % of urine and flush water. This is the equivalent of a 6-crew load on ISS, though in reality the UPA typically processes only the urine generated in the US Segment. Product water from the UPA has been evaluated on the ground to verify it meets the requirements for conductivity, pH, ammonia, particles, and total organic carbon. The UPA was designed to recover 85% of the water content from the pretreated urine, though issues with urine quality encountered in 2009 have required the recovery to be dropped to 70%."
    
    % From: Status of the Regenerative ECLSS Water Recovery and Oxygen Generation Systems:
    % "The WPA operates in batch mode, processing water nominally at 5.9 Kg/hr (13 lb/hr) consuming an 
    % average of 320 W-hr/hr when processing and 133 W-hr/hr while in standby."
    
    % From: Status of the Regenerative ECLSS Water Recovery and Oxygen Generation Systems (2006):
    % The UPA is designed to process a nominal load of 8.4kg/day (18.6 lbs/day) of wastewater consisting 
    % of urine, flush water, and a small amount of waste from Environmental Health System water samples. 
    % At a maximum load, the UPA can process 13.6 kg (30 lbs) of wastewater over an 18-hour period per day. 
    % Like the WPA, it operates in a batch mode, consuming a maximum average power of 315 W when processing,
    % and 56 W during standby. Product water from the UPA must meet specification quality requirements for 
    % conductivity, pH, ammonia, particles, and total organic carbon. It must recover a minimum of 85% of 
    % the water content in the specified wastewater stream.
    
    properties
        % Consumer/Producer Definitions
        GreyWaterConsumerDefinition
        DirtyWaterConsumerDefinition
        PowerConsumerDefinition
        PotableWaterProducerDefinition
    end
    
    methods
        %% Constructor
        function obj = WaterRSLinearImpl
            obj.GreyWaterConsumerDefinition = ResourceUseDefinitionImpl;
            obj.DirtyWaterConsumerDefinition = ResourceUseDefinitionImpl;
            obj.PowerConsumerDefinition = ResourceUseDefinitionImpl;
            obj.PotableWaterProducerDefinition = ResourceUseDefinitionImpl;
        end
        
        %% tick
        function tick(obj)
            % gatherPower()
            currentPowerConsumed = obj.PowerConsumerDefinition.ResourceStore.take(obj.PowerConsumerDefinition.MaxFlowRate,obj.PowerConsumerDefinition);     % Take power
            
            % gatherWater()
            % This is tuned to requiring 1540 Watts to process 4.26L of
            % water
            waterNeeded = (currentPowerConsumed/1540) * 4.26;
            % Take water from dirty water store first, then if this is not
            % enough, take remainder from grey water store
            currentDirtyWaterConsumed = obj.DirtyWaterConsumerDefinition.ResourceStore.take(waterNeeded,obj.DirtyWaterConsumerDefinition);
            
            % Take remainder of water needed from GreyWater Store (if
            % required)
%             currentGreyWaterConsumed = obj.GreyWaterConsumerDefinition.ResourceStore.take(...
%                 (waterNeeded > currentDirtyWaterConsumed)*(waterNeeded - currentDirtyWaterConsumed),...
%                 obj.GreyWaterConsumerDefinition);
            % Alternative
            currentGreyWaterConsumed = obj.GreyWaterConsumerDefinition.ResourceStore.take(...
                waterNeeded - currentDirtyWaterConsumed,obj.GreyWaterConsumerDefinition);
            
            % Push Potable Water to Potable Water Store
            obj.PotableWaterProducerDefinition.ResourceStore.add(...
                currentDirtyWaterConsumed+currentGreyWaterConsumed,obj.PotableWaterProducerDefinition);
            
        end
        
    end
    
end

