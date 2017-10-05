classdef ISSCRSImpl < handle
    %ISSCRSImpl Summary of this class goes here
    %   By: Sydney Do (sydneydo@mit.edu)
    %   Date Created: 8/11/2014
    %   Last Updated: 8/11/2014
    %   This is a simple implementation of CO2 Reduction System (Sabatier
    %   Reactor)
    
    %   Tuned on 8/13/2014 to match the ISS Sabatier Reactor
    
    %% RAW DATA
    % From: Sabatier Methanation Reactor for Space Exploration (AIAA 2005-2706):
    % "A unique flow control valve is also now in test, which precisely controls the flow rate of carbon dioxide
    % to the reactor to match the delivered rate of hydrogen from the OGA. This valve provides the capability to 
    % maximize water recovery in the CRA by minimizing the amount of unreacted feedstock."
    
    % "The Sabatier CRA receives hydrogen from the OGA, which nominally only performs electrolysis when the 
    % station is in the daylight portion of the orbit. However, the CDRA collects and concentrates carbon dioxide 
    % continuously, requiring storage of the CO2 for maximum system efficiency. Therefore, a simple scheme of 
    % storing the CO2 in an accumulator tank until there is hydrogen available to react with it has been modeled 
    % extensively and is currently being tested with ground-based technology demonstration hardware."

    % "The Sabatier CRA can produce 2000 lb/year of water when a 6 person crew is occupying the station"
    
    % From: Integrated Test and Evaluation of a 4-Bed Molecular Sieve (4BMS) Carbon Dioxide Removal System (CDRA),
    % Mechanical Compressor Engineering Development Unit (EDU), and Sabatier Engineering Development Unit (EDU) (SAE 2005-01-2864)
    % "The result is a highly efficient, robust catalyst with demonstrated conversion efficiency greater 
    % than 99 percent and an estimated life of approximately ten years."
    
    % From: "Development and Integration of the Flight Sabatier Assembly on the ISS"
    % "The chemical reaction efficiency is about 90 percent in the front one-third hot section of the reactor. 
    % By cooling the rear two-thirds of the reactor to roughly 149 ºC (300ºF), an additional chemical reaction 
    % efficiency of about five percent is achieved."
    
    % From: "A Trade Study on Sabatier CO2 Reduction Subsystem for Advanced
    % Missions" SAE 2001-01-2293
    % Sabatier Reactor (Heater) Power: 106W (runs as long as there is H2)
    % CO2 compressor Power: 500W (operates to send CO2 to the accumulator)
    
    % From: Rotary Drum Separator and Pump for the Sabatier Carbon Dioxide
    % Reduction System - SAE2005-01-2863
    % "The new drum design has achieved pumping pressire of 103.4kPa using
    % only 80 Watts"
    
    % From: pg 46-47 "Integrated Evaluation of Closed Loop Air Revitalization
    % System Components"
    % "Day/Night Cycle Times – The day night cycle time for most of the tests was set to 52 minutes day, 
    % 37 minutes night. This corresponds to the longest night duration of the ISS orbit. The length of the night 
    % cycle affects how much the reactor cools off before being restarted."
    
    % "Molar Ratio – Molar ratio is the ratio of hydrogen to carbon dioxide
    % fed to the Sabatier reactor. The stoichimetric ratio is 4 moles hydrogen 
    % to 1 mole CO2. In these tests, the molar ratio was set to 3.5. In the space 
    % station application, CO2 is in excess of hydrogen. The reactor works more efficiently 
    % when the molar ratio is not at the stoichiometric value"
    
    % "Reactor Temperatures – The reactor temperatures indicate the general health 
    % of the Sabatier reaction and vary with different inlet feed rates and molar ratios."
    
    % "Power – Power is consumed by the Sabatier to preheat the reactor and to operate the separator, in addition 
    % to valves and sensors."
    
    % From: Analyses of the Integration of Carbon Dioxide Removal
    % Assembly, Compressor, Accumulator and Sabatier Carbon Dioxide
    % Reduction Assembly SAE 2004-01-2496
    % Regarding Sabatier Operation:
    % "CO2 inlet flow controller set to nominally maintain a molar ratio (MR) of 3.5 moles H2 to 1 mole CO2"
    % "If the accumulator pressure drops below 18 psia, the Sabatier goes to standby and the
    % OGA vents its H2 overboard. The Sabatier returns to Operate when the accumulator reaches 20 psia"
    
    % From: Integrated Evaluation of Closed Loop Air Revitalization System
    % Components - NASA/CR-2010-216451
    % pg 9: "The compressor is cooled with 65°F chilled water representative of the medium temperature loop (MTL) on ISS. 
    % At median pressures of 4 psia suction and 70 psia discharge, the compressor delivers approximately 17.7 scfh (1.9 lb/hr) of CO2."
    
    %% RAW DATA ON CO2 ACCUMULATOR
    % From: "Analyses of the Integration of Carbon Dioxide Removal Assembly, Compressor, Accumulator 
    % and Sabatier Carbon Dioxide Reduction Assembly" SAE 2004-01-2496
    % "CO2 accumulator – The accumulator volume was set at 0.7 ft3, based on an assessment of available
    % space within the OGA rack where the CRA will reside. Mass balance of CO2 pumped in from the
    % compressor and CO2 fed to the Sabatier CO2 reduction system is used to calculate the CO2 pressure.
    % Currently the operating pressure has been set to 20 – 130 psia."
    
    % From SAE 2004-01-2496, on CDRA bed heaters - informs temp of CO2 sent to
    % accumulator
    % "During the first 10 min of the heat cycle, ullage air is pumped out back to the cabin. After this time, the bed is
    % heated to approximately 250 °F and is exposed to space vacuum for desorption of the bed."
    % ...
    % "The heaters were OFF during the “night time”, or when the desorb bed temperature reached its set point
    % of 400 ºF, or when it was an adsorb cycle."
    
    % (Ref: Functional Performance of an Enabling Atmosphere Revitalization Subsystem Architecture for Deep Space Exploration Missions (AIAA 2013-3421)
    % Quote: “Because the commercial compressor discharge pressure was 414 kPa compared to the flight CO2 Reduction Assembly (CRA)
    % compressor’s 827 kPa, the accumulator volume was increased from 19.8 liters to 48.1 liters”
    
    %% NOTES
    % We'll assume a 90% water production efficiency. This is based on the
    % following data:
    % Table 5 - "Integrated Test and Evaluation of a 4-Bed Molecular Sieve (4BMS) Carbon Dioxide Removal System (CDRA),
    % Mechanical Compressor Engineering Development Unit (EDU), and
    % Sabatier Engineering Development Unit (EDU) (SAE 2005-01-2864)"
    % In this table, the water production efficiency measured from testing
    % ranges from 87%-93%
    % "As can be seen in Table 5, the Sabatier water production efficiency ranged from approximately 
    % 87% to 93%, depending on test conditions"
    % "Methane and unreacted reactants will be vented overboard" (REF: A
    % Trade Study on Sabatier CO2 Reduction Subsystem for Advanced Missions
    % - SAE2001-01-2293)
    
    
    
    properties
        % Consumer/Producer Definitions
        CO2ConsumerDefinition
        H2ConsumerDefinition
        PowerConsumerDefinition
        GreyWaterProducerDefinition
        MethaneProducerDefinition
        CO2Accumulator
        CompressorError = 0
        ReactorError = 0
        SeparatorError = 0;
        CO2Vented = 0
%         CH4Vented = 0
        WaterVaporVented = 0
        CompressorOperation = zeros(2,1)
    end
    
    properties (Access = private)
        ReactionH2CO2ratio = 3.5    % REF: Analyses of the Integration of Carbon Dioxide Removal Assembly, Compressor, Accumulator and Sabatier Carbon Dioxide Reduction Assembly (SAE 2004-01-2496)       
        idealGasConstant = 8.314;        % J/K/mol
        CO2AccumulatorStorageTemp = 5/9*(65-32)+273.15 	% Converted to Kelvin from 65F, "The compressor is cooled with 65°F chilled water representative of the medium temperature loop (MTL) on ISS" (REF: Integrated Evaluation of Closed Loop Air Revitalization System Components - NASA/CR-2010-216451)
        CO2accumulatorVolumeInLiters = 19.8                 % in liters, (REF: Functional Performance of an Enabling Atmosphere Revitalization Subsystem Architecture for Deep Space Exploration Missions (AIAA 2013-3421)
        CO2AccumulatorMaxPressureInKPa = 827                % note that 827kPa corresponds to ~120psi (REF: Functional Performance of an Enabling Atmosphere Revitalization Subsystem Architecture for Deep Space Exploration Missions (AIAA 2013-3421)
        ReactorWaterConversionEfficiency = 0.9              % REF: Table 5 - "Integrated Test and Evaluation of a 4-Bed Molecular Sieve (4BMS) Carbon Dioxide Removal System (CDRA), Mechanical Compressor Engineering Development Unit (EDU), and Sabatier Engineering Development Unit (EDU) (SAE 2005-01-2864)"
        CompressorLowerRechargePressure = 172.368932        % Lower bound of CO2 accumulator pressure by which compressor beings to activate (Converted from 25psia - REF: "Analyses of the Integration of Carbon Dioxide Removal Assembly, Compressor, Accumulator and Sabatier Carbon Dioxide Reduction Assembly" SAE 2004-01-2496)
        CompressorFlowRate = 1.9/2.2*1E3/(12.011+2*15.999)  % Average flow rate of CO2 delivered to CO2 accumulator by CO2 compressor, converted from 1.9lb/hr (REF: Integrated Evaluation of Closed Loop Air Revitalization System Components - NASA/CR-2010-216451)
        ReactorHeaterPower = 106        % Watts (Runs when H2 is present to react)
        CO2CompressorPower = 500        % Watts (Runs to fill CO2 store
        SeparatorPower = 80             % Watts
    end
    
    methods
        %% Constructor
        function obj = ISSCRSImpl(H2Source,CO2Source,WaterOutput,CH4Output,PowerSource)
            obj.CO2ConsumerDefinition = ResourceUseDefinitionImpl(CO2Source);
            obj.H2ConsumerDefinition = ResourceUseDefinitionImpl(H2Source);
            obj.PowerConsumerDefinition = ResourceUseDefinitionImpl(PowerSource);
            obj.GreyWaterProducerDefinition = ResourceUseDefinitionImpl(WaterOutput);
            obj.MethaneProducerDefinition = ResourceUseDefinitionImpl(CH4Output);
          
            % Initialize Internal CO2 accumulator (separate from the store
            % currently used to represent CO2 desorbing from the VCCR beds)
            molesInCO2Store = obj.CO2AccumulatorMaxPressureInKPa*obj.CO2accumulatorVolumeInLiters/obj.idealGasConstant/obj.CO2AccumulatorStorageTemp;   % Convert CO2Accumulator volume from liters to moles
            obj.CO2Accumulator = StoreImpl('CO2','Material',molesInCO2Store,0);
        end
        
        %% tick
        function currentH2OProduced = tick(obj)
            
            obj.CompressorOperation = zeros(2,1);  % Add flag to denote operation of compressor (most power intensive operation within CRS)
            currentH2OProduced = 0;
            
            % Only run if there is no system error
            if obj.CompressorError == 0 && obj.ReactorError == 0 && obj.SeparatorError == 0
                
                % Run CO2compressor everytime there is enough CO2 available to
                % fill CO2 store (note that the CO2 store is currently set to
                % fill automatically by the VCCR - here, we just model the
                % power consumption of filling the CO2 store)
                
                
                if obj.CO2ConsumerDefinition.ResourceStore.currentLevel >= obj.CO2Accumulator.currentCapacity && ... %obj.CO2Accumulator.currentLevel == 0
                        obj.CO2Accumulator.currentLevel*obj.idealGasConstant*obj.CO2AccumulatorStorageTemp/obj.CO2accumulatorVolumeInLiters < obj.CompressorLowerRechargePressure  % Accumulator pressure is < 25psi

                    % Run Compressor
                    compressorPowerConsumed = obj.PowerConsumerDefinition.ResourceStore.take(obj.CO2CompressorPower);
                    
                    % Add flag to denote compressor operation to fill
                    % accumulator due to low pressure within accumulator
                    obj.CompressorOperation(1) = 1;
                    
                    if compressorPowerConsumed < obj.CO2CompressorPower
                        disp('No CO2 delivered to CRA due to insufficient power input to CO2 Compressor')
                        obj.CompressorError = 1;
                        currentH2OProduced = 0;
                        return
                    end
                    
                    % Take CO2 from CO2 store (represents desorbing side of
                    % bed) and add to CO2 Accumulator
                    CO2taken = obj.CO2ConsumerDefinition.ResourceStore.take(min([obj.CO2Accumulator.currentCapacity-obj.CO2Accumulator.currentLevel,obj.CompressorFlowRate]));
                    obj.CO2Accumulator.add(CO2taken);
                    
                end
                
                
                % Run Sabatier reactor is there is H2 available to react
                % Follows CO2 + 4H2 --> CH4 + 2H2O
                % Note that the Sabatier reactor is run at 1:3.5 CO2/H2 ratio
                % so that H2 is the limiting reactant and all of the H2 is
                % reacted.
                % So actual reaction given this feedrate:
                % 0.5/4CO2 + 3.5/4CO2 + 3.5H2 --> 3.5/4CH4 + 1.75H2O + 0.5/4CO2
                % (all in gaseous phase)
                % Equivalently:
                % (1/3.5-1/4)CO2 + 1/4CO2 + H2 --> 1/4CH4 + 1/2H2O + (1/3.5-1/4)CO2
                % Since in reality, not all conversion occurs, and some H2O is
                % lost as vapor from an inefficient CHX, we assume only 90% of
                % the 7 moles of H2O is recovered as liquid (see notes above)
                
                
                if obj.H2ConsumerDefinition.ResourceStore.currentLevel > 0
                    % Gather H2
                    H2MolestoReact = obj.H2ConsumerDefinition.ResourceStore.take(obj.H2ConsumerDefinition.ResourceStore.currentLevel);   % Take all H2
                    
                    % Consume power to heat reaction chamber
                    reactorPowerConsumed = obj.PowerConsumerDefinition.ResourceStore.take(obj.ReactorHeaterPower);
                    
                    if reactorPowerConsumed < obj.ReactorHeaterPower
                        disp('Insufficient power to run Sabatier Reactor')
                        obj.ReactorError = 1;
                        currentH2OProduced = 0;
                        return
                    end
                    
                    % Gather CO2 required for Sabatier reaction from CO2
                    % Accumulator (3.5 times the amount of H2 moles available
                    % to correspond with reactant mixture ratio)
                    CO2MolestoReact = obj.CO2Accumulator.take(1/obj.ReactionH2CO2ratio*H2MolestoReact);
                    
                    % If insufficient CO2, refill CO2 accumulator and repeat
                    if CO2MolestoReact < (1/obj.ReactionH2CO2ratio*H2MolestoReact)
                                                
                        % Return CO2MolestoReact back to CO2Accumulator
                        obj.CO2Accumulator.add(CO2MolestoReact);
                        
                        % Run Compressor - possible alternative condition - if
                        % CO2 accumulator pressure < 25psi (which is what is
                        % actually the case based on compressor operating rules - REF: SAE2004-01-2496)
                        compressorPowerConsumed = obj.PowerConsumerDefinition.ResourceStore.take(obj.CO2CompressorPower);
                        
                        % Add flag to denote compressor operation to
                        % retrieve CO2 due to insufficient CO2 for Sabatier
                        % Reaction
                        obj.CompressorOperation(2) = 1;
                        
                        if compressorPowerConsumed < obj.CO2CompressorPower
                            disp('No CO2 delivered to CRA due to insufficient power input to CO2 Compressor')
                            obj.CompressorError = 1;
                            currentH2OProduced = 0;
                            return
                        end
                        
                        % Take CO2 from CO2 store (represents desorbing side of
                        % bed) and add to CO2 Accumulator
                        CO2taken = obj.CO2ConsumerDefinition.ResourceStore.take(min([obj.CO2Accumulator.currentCapacity-obj.CO2Accumulator.currentLevel,obj.CompressorFlowRate])); % Note: obj.CompressorFlowRate should always be > then CO2 required for reaction, so no need to include a checking if statement for insufficient CO2 after the compressor has operated
                        obj.CO2Accumulator.add(CO2taken);
                        
                        CO2MolestoReact = obj.CO2Accumulator.take(1/obj.ReactionH2CO2ratio*H2MolestoReact);
                        
                    end
                    
                    % Operate condensor to separate water from other reaction
                    % products
                    condensorPowerConsumed = obj.PowerConsumerDefinition.ResourceStore.take(obj.SeparatorPower);
                    
                    if condensorPowerConsumed < obj.SeparatorPower
                        disp('Insufficient power delivered to CRA liquid-gas separator - liquid water could not be recovered')
                        obj.SeparatorError = 1;
                        currentH2OProduced = 0;
                        % Vent all products
                        obj.WaterVaporVented = obj.WaterVaporVented + H2MolestoReact/2;
                        obj.CO2Vented = obj.CO2Vented + (CO2MolestoReact-H2MolestoReact/4);
                        obj.MethaneProducerDefinition.ResourceStore.add(H2MolestoReact/4);
                        return
                    end
                    
                    % Send produced H2O to grey water store
                    currentH2OProduced = obj.GreyWaterProducerDefinition.ResourceStore.add(H2MolestoReact/2 * obj.ReactorWaterConversionEfficiency *(2*1.008+15.999)/1000); % Convert from moles to liters
                    
                    % Vent undesired products
                    obj.WaterVaporVented = obj.WaterVaporVented + H2MolestoReact/2 * (1-obj.ReactorWaterConversionEfficiency);
                    obj.CO2Vented = obj.CO2Vented + (CO2MolestoReact-H2MolestoReact/4);
                    
                    % For now, we send methane to a methane store
                    obj.MethaneProducerDefinition.ResourceStore.add(H2MolestoReact/4);
                    
                end
                
            else
                % There is an error in the CRS - no H2O is produced and we
                % skip the tick function
                currentH2OProduced = 0;
                return
                
            end
            
        end
    end
    
end

