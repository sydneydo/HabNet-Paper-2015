classdef ISSOGA < handle
    %ISSOGA Simple Implementation of an oxygen generation system
    %   (Using electrolysis - assuming 100% conversion efficiency)
    %   By: Sydney Do (sydneydo@mit.edu)
    %   Date Created: 5/16/2014
    %   Last Updated: 5/16/2014
    
    
    %   Tuning parameters to meet ISS OGA
    %   From: Status of the Regenerative ECLSS Water Recovery and Oxygen Generation Systems: "The measured weight of the OGS in its launch
% configuration is 658 Kg (1447 lb.)"
    
% From: Status of the Regenerative ECLSS Water Recovery and Oxygen Generation Systems:
% "The test-verified average processing power at the maximum oxygen production rate is 2971W"

% pg 89 - Living Together in Space
% The rate of O2 generation is 5.25 HEU, sufficient for four people, biological specimens, 
% and normal atmospheric losses with day/night cycling. During continuous operation (no day/night power cycle)
% the capability to support seven people and biological specimens is provided (8.25 HEU total). (HEU = Human Equivalent Unit)

% From: ISS USOS Oxygen Generation System On-Orbit Operational Experience
% The OGA is designed to generate oxygen at a maximum nominal rate of 5.4 kg/day (12 lb/day) when operated on 
% day/night orbital cycles, and also at a selectable rate between 2.3 and 9.2 kg/day (5.1 and 20.4 lb/day) when 
% operated continuously. At the maximum nominal day/night cycle rate, the OGA can support the oxygen needs for six 
% crew and biological specimens, and atmosphere leakage, while at the maximum continuous rate it can support eleven crew, 
% biological specimens, and atmosphere leakage. The OGS consumes 2971 W when processing at the maximum oxygen production rate 
% and 469 W during standby at  beginning of cell stack membrane life.

% From: "Methodology and Assumptions of Contingency Shuttle Crew Support (CSCS) Calculations Using ISS Environmental Control and Life Support Systems" SAE 2006-01-2061:
% "Oxygen consumption per person per day is 0.8346 kg. This is the agreed to average oxygen consumption rate for one 
% person per day on the ISS." (according to BVAD also)

% From: "ECLSS Design for the International Space Station Nodes 2 and 3":
% "The OGS is designed to produce 5.4 kg/day (12 lb/day) oxygen while operating on day/night orbital
% cycles, or up to 9.1 kg/day (20 lb/day) oxygen when operated continuously"

% From: Status of the Regenerative ECLSS Water Recovery and Oxygen Generation Systems: O2 is vented directly to the cabin
% "The OGA is designed to generate oxygen at a nominal rate of 5.4 kg/day (12 lb/day) when operated on day/night orbital 
% cycles (53 minutes at 100% production, 37 minutes in standby), and also at a selectable rate between 2.3 and 9.2 kg/day 
% (5.1 and 20.4 lb/day) when operated continuously. At the nominal rate, the OGA can support oxygen needs for 4 crew, 
% biological specimens, and atmosphere leakage, while at the maximum rate it can support 7 crew, biological specimens, and atmosphere leakage.

%% My Notes
%   90min/53min * 5.4kg/day = 9.17kg when operating continuously
%   A sample run of the current Simulation Configuration (in open loop mode
%   for the Mars One case) indicates a crew consumption of approx. 1.05kg
%   of O2 per day, which is > the 0.835kg specified in BVAD. Note that
%   0.835kg is for nominal IVA, whereas our 1.05kg value accounts for
%   Exercise (but EVA wasn't factored into this)

%   For Mars, we will assume a continuous operating mode

%   For the OGA implementation, we will use 9.2kg/24hr O2 production rate 
%   at 2971W as the maximum operating point
%   The minimum operating point will be 0kg/hr O2 production at 469W
%   (the standby mode described above)

%   Note that OGA operates at set points in 25% capacity increments
%   REF: Status of the Regenerative ECLSS Water Recovery and Oxygen Generation Systems
%   From the data we have, we can infer that:
%   25% = 2.3kg O2/day
%   50% = 4.6kg O2/day
%   75% = 6.9kg O2/day
%   100% = 9.2kg O2/day
%   This inference is further supported by the discussion in:
%   "Investigation into the High-Voltage Shutdown of the Oxygen
%   Generation System Aboard the International Space Station" (AIAA 2012-3613)

%   O2 is vented directly to the cabin

%   Since feedwater is recycled within a loop in the OGA, it is reasonable
%   to assume that all feedwater input into the OGA will eventually become
%   O2 and H2. That is, it is reasonable to assume that the OGA 
%   electrolysis process is 100% efficient - we will make this assumption

%   We probably want some type of controller to prevent too much O2 from
%   being produced, thereby pushing the O2 molar fraction towards a fire
%   risked state (30%O2) (and forcing more gases to be expelled and vented
%   by the PCA to control for this)

%   We assume that the OGA is nominally off until it is sensed that O2 is
%   needed. The appropriate setting is then automatically made based on a
%   measured O2 deficit
%   The practical feasibility of this is based on the fact that the OGA
%   operates in day/night cycles (ie. it switches on and off regularly)

    properties
%         ProductionRate = 1;         % BioSim has a ProductionRate value
%         which is a multiplier on the amount of O2 generated. This is not
%         included here as this breaks the mass conservation (production
%         becomes independent of input flow rate)
        Environment                               % of type "SimEnvironmentImpl"
        TargetTotalPressure      % Target absolute pressure to be maintained within cabin
        TargetO2PartialPressure        % Target O2 partial pressure (in kPa)
        TargetO2MolarFraction         % Target O2 molar fraction
        CommandedO2ProductionSetting
        PowerConsumerDefinition
        PotableWaterConsumerDefinition
        O2ProducerDefinition
        H2ProducerDefinition
        Error = 0
    end
    
    properties (SetAccess = private)
        OGA_ProductionRateSettings = 2.3*(0:4)/24 * 1e3 / (2*15.999)        % in mol/hr (converted from 2.3*(1:4) kg O2/day)
        idealGasConstant = 8.314;        % J/K/mol
        OGA_Max_PowerConsumption = 2971                         % Watts
        OGA_Min_PowerConsumption = 469                          % Watts
    end
    
    methods
        %% Constructor
        function obj = ISSOGA(targetTotalPressure,targetO2molarFraction,O2outputEnvironment,WaterSource,PowerSource,H2output)
            
            % Initialize atmospheric target conditions
            obj.TargetTotalPressure = targetTotalPressure;
            obj.TargetO2MolarFraction = targetO2molarFraction;
            obj.TargetO2PartialPressure = targetO2molarFraction*targetTotalPressure;
            
            % Ensure that o2outlet used in O2ProducerDefinition is of type
            % StoreImpl
%             if strcmpi(class(O2output),'SimEnvironmentImpl')
%                 o2outlet = O2output.O2Store;
%             else
%                 o2outlet = O2output;
%             end
            
            obj.PowerConsumerDefinition = ResourceUseDefinitionImpl(PowerSource,obj.OGA_Max_PowerConsumption,obj.OGA_Max_PowerConsumption);
            obj.PotableWaterConsumerDefinition = ResourceUseDefinitionImpl(WaterSource);        % no flow rates input as relative to the production rates, flow rate will not be limited from the water source
            obj.Environment = O2outputEnvironment;
            obj.O2ProducerDefinition = ResourceUseDefinitionImpl(O2outputEnvironment.O2Store,obj.OGA_ProductionRateSettings(4),obj.OGA_ProductionRateSettings(4));
            obj.H2ProducerDefinition = ResourceUseDefinitionImpl(H2output,2*obj.OGA_ProductionRateSettings(4),2*obj.OGA_ProductionRateSettings(4));       % 2*O2 production rates due to stoichiometry           
            
        end
        
        %% tick
        function molesOfO2Produced = tick(obj)
            
            % Only run if there is no system error
            if obj.Error == 0
            
                % Determine production rate based on cabin measurements
                % Assume some form of cabin sensing that informs the production
                % of O2 from water
                % Currently, it appears that the OGA is commanded from the
                % ground (based on discussion in: "International Space Station United States Orbital Segment
                % Oxygen Generation System On-orbit Operational Experience" SAE 2008-01-1962
                
                % We will assume ideal control - we need information on the
                % cabin atmospheric composition
                
                % Note: tick the OGA before the PCA to minimize expenditure of
                % gaseous reserves
                
                % OGA runs continuously until powered off (since there is a
                % warm up time requirement)
                
                
                % Default setting for O2 production percentage is 0% (Setting 1)
                obj.CommandedO2ProductionSetting = obj.OGA_ProductionRateSettings(1);
                
                % Change O2 production rate based on cabin ppO2 need (we ignore
                % the bounding box here as the PCA's job is to take care of
                % this)
                if obj.Environment.O2Percentage < obj.TargetO2MolarFraction %(obj.Environment.pressure*obj.Environment.O2Percentage) < obj.TargetO2PartialPressure     % in kPa
                    
                    % We calculate makeupO2MolesRequired by solving for:
                    % obj.TargetO2MolarFraction = (makeupO2MolesRequired + currentO2moles) / (makeupO2MolesRequired + currentTotalMoles)
                    makeupO2MolesRequired = (obj.TargetO2MolarFraction*obj.Environment.totalMoles-obj.Environment.O2Store.currentLevel)/...
                        (1-obj.TargetO2MolarFraction);
                    
                    % Set commanded O2 production to the minimum setting value
                    % just above current O2 mole deficit. The wrapping min
                    % command is for scenarios where the makeupO2MolesRequired
                    % is greater than the maximum production rate of O2
                    % possible by the OGA (i.e. in this case, the OGA is set to
                    % the maximum possible O2 production rate)
                    % (Note that this law might change when multiple modules are connected to each other)
                    obj.CommandedO2ProductionSetting = min([min(obj.OGA_ProductionRateSettings(obj.OGA_ProductionRateSettings>=makeupO2MolesRequired)),obj.OGA_ProductionRateSettings(4)]);
                end
                
                
                % gatherPower()
                % Power to consume is determined by a linear law connecting the
                % two operating points listed in the notes section above. These
                % are listed again below:
                
                %   For the OGA implementation, we will use 9.2kg/24hr O2 production rate
                %   at 2971W as the maximum operating point
                %   The minimum operating point will be 0kg/hr O2 production at 469W
                %   (the standby mode described above)
                powerToConsume = (obj.OGA_Max_PowerConsumption - obj.OGA_Min_PowerConsumption)/obj.OGA_ProductionRateSettings(4)...
                    *(obj.CommandedO2ProductionSetting) + obj.OGA_Min_PowerConsumption;
                
                currentPowerConsumed = obj.PowerConsumerDefinition.ResourceStore.take(powerToConsume,obj.PowerConsumerDefinition);     % Take power from power source
                
                % Error for if there is inadequate power to operate
                if currentPowerConsumed < powerToConsume
                    % return power to power store
                    obj.PowerConsumerDefinition.ResourceStore.add(currentPowerConsumed);
                    disp('OGA shut down due to inadequate power input')
                    obj.Error = 1;
                    molesOfO2Produced = 0;  % nothing produced by OGA
                    return
                end
                
                % Calculate O2 produced as a function of power that is actually
                % consumed (max function to ensure value is always positive)
                o2MolesProduced = max([obj.OGA_ProductionRateSettings(4)/(obj.OGA_Max_PowerConsumption - obj.OGA_Min_PowerConsumption)*...
                    (currentPowerConsumed-obj.OGA_Min_PowerConsumption),0]);
                
                % Determine water desired to be consumed based on
                % stoichiometry (assuming 100% efficient electrolysis  -
                % rationale for this assumption is discussed in "My Notes")
                % 2H2O --> 2H2 + O2
                
                % Water
                molesOfWaterRequired = 2*o2MolesProduced;
                litersOfWaterRequired = molesOfWaterRequired*18.01524/1000;   %1000g/liter, 18.01524g/mole
                litersOfH2OConsumed = obj.PotableWaterConsumerDefinition.ResourceStore.take(litersOfWaterRequired);     % Take H2O from potable water store (in liters)
                
                % Since it is possible for currentH2OConsumed to not correspond
                % to o2MolesProduced (due to an emptying store), we go through
                % stoichiometry again to determine the O2 and H2 moles actually
                % produced
                
                % pushGasses()
                % Follows stoichiometric ratio: 2H2O --> 2H2 + O2
                molesOfH2OConsumed = (litersOfH2OConsumed * 1000) / 18.01524; %1000g/liter, 18.01524g/mole
                %             currentO2Produced = molesOfWater/2;
                %             currentH2Produced = molesOfWater;
                
                % Push to Stores (note that capacity in these stores is
                % measures in moles)
                molesOfO2Produced = obj.O2ProducerDefinition.ResourceStore.add(molesOfH2OConsumed/2,obj.O2ProducerDefinition);
                obj.H2ProducerDefinition.ResourceStore.add(molesOfH2OConsumed,obj.H2ProducerDefinition);
            
            else
                % There is an error in the OGS - no O2 is produced and we
                % skip the tick function
                molesOfO2Produced = 0;
                return
                
            end
        end
    end
    
end

