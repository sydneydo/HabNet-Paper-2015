classdef ShelfImpl4 < handle
    %ShelfImpl4 Summary of this class goes here
    %   By: Sydney Do (sydneydo@mit.edu)
    %   Date Created: 12/20/2014
    %   Last Updated: 12/20/2014
    %
    %   This class file combines the PlantImpl, ShelfImpl, and
    %   BiomassPSImpl BioSim java class files
    %
    %   This code currently assumes that the crop is planted at the start
    %   of mission (tick 1).
    
    %% Updated Modifications for Version 3 of Code
    % Implemented constraint that code only runs if concentration of CO2
    % within atmosphere is between 330 and 1300ppm
    % If below 330ppm, zero crop growth occurs, if above 1300ppm, 1300pm
    % CO2 is taken
    
    % Fixed equation for PPFFractionAbsorbed so that it agrees with BVAD
    % Equation 4.2-1
    
    %% Updated Modifications for Version 4 of Code
    % Implemented Modified MEC version of code described in Boscheri et al
    % "Modified Energy Cascade Model adapted for a multicrop Lunar
    % Greenhouse Prototype" so that the model ran correctly with a one hour
    % timestep
  
    properties
        CropName
        Crop
        CropCycleStartTime = 0
        tickcount = 0       % System level tick
        HourlyCanopyTranspirationRate
        WaterFraction
        DailyCarbonGain
        % Shelf Properties
        cropAreaUsed
        cropAreaTotal
        ShelfWaterLevel = 0;
        ShelfWaterNeeded
        ShelfPowerLevel = 0;                     % power used to shine lights on plants
        
        PowerConsumerDefinition
        AirConsumerDefinition
        PotableWaterConsumerDefinition
        GreyWaterConsumerDefinition
        DirtyWaterProducerDefinition    % this doesn't appear to be used within the BioSim PlantImpl or ShelfImpl files
        AirProducerDefinition
        BiomassProducerDefinition
        
        % Plant Properties
        Age = 0;        % Age of current crop group
        hasDied = 0;
        canopyClosed = 0; 
        
        isLightPeriod = 1;      % Flag to determine whether crop is currently within a light (1) or dark (0) period
%         AveragePPF = 0;
%         TotalPPF = 0;
%         NumberOfPPFReadings = 0;
        TargetPPF
        CurrentPPF
        AverageWaterNeeded = 0;
        TotalWaterNeeded = 0;
        CurrentCO2Concentration
        CurrentWaterInsideInedibleBiomass = 0;
        CurrentWaterInsideEdibleBiomass = 0;
        CurrentTotalWetBiomass = 0;         % in kg
        CurrentEdibleWetBiomass = 0;        % in kg
        CurrentEdibleDryBiomass = 0;        % in kg
        CurrentDryBiomass = 0;              % in kg
        LastTotalWetBiomass = 0;
        LastEdibleWetBiomass = 0;
        WaterNeeded = 0;
        WaterLevel = 0;
        
        CQY = 0;      % canopy quantum yield, defined as the ratio of carbon fixed (C-mol) over the total light absorbed (# of photons)
        % (From: SAE 2000-01-2261: CQY: the number of moles of carbon that are fixed in sucrose for each
        % mole of PPF absorbed
        carbonUseEfficiency24 = 0;
%         totalO2GramsProduced = 0;
        totalCO2GramsConsumed = 0;
        totalWaterLitersTranspired = 0
        TimeTillCanopyClosure = 0       % in days
        CanopyClosureConstants
        CanopyQuantumYieldConstants
        PPFFractionAbsorbed = 0;
        CanopyClosurePPFValues
        CanopyClosureCO2Values
        MolesOfCO2Inhaled
        MolesOfO2Exhaled
        CropGrowthRate          % for validation testing with data in "Crop Models for Varying Environmental Conditions"
        NetCanopyPhotosynthesis     % in micromoles of carbon/m^2/s - used for validation of CO2 drawdown tests from Wheeler
        HourlyO2Production      % Value defined in Boscheri et al version of MEC
        HourlyO2Consumption     % Value defined in Boscheri et al version of MEC
        VaporTranspired         % Vapor Transpired at current tick (moles)
    end
    
    properties (Access = private)
        % Shelf properties
        waterNeededPerSquareMeter = 50  % Grab up to 50L/m^2 of crops per hour (default value within BioSim)
        powerPerSquareMeter = 1520;     % this is taken from table 4.2.2 of BVAD (Table 4.2.3 indicates a power requiremenrs of 2.1kW/m^2)
        % Lamp Properties
        lampEfficiency = 261;           % for high pressure sodium bulbs
        PSEfficiency = 4.68;            % for high pressure sodium bulbs
        % Plant properties (these don't appear to currently be utilized - plants are treated like crewpersons with their own buffers that sustain them til death)
        WATER_TILL_DEAD = 200;
        WATER_RECOVERY_RATE = 0.005;
        CO2_LOW_TILL_DEAD = 24;
        CO2_LOW_RECOVERY_RATE = 0.005;
        CO2_RATIO_LOW = 500;
        CO2_HIGH_TILL_DEAD = 24;
        CO2_HIGH_RECOVERY_RATE = 0.05;
        CO2_RATIO_HIGH = 20000;
        HEAT_TILL_DEAD = 48;
        HEAT_RECOVERY_RATE = 0.05;
        DANGEROUS_HEAT_LEVEL = 300000;
        LIGHT_TILL_DEAD = 150;
        LIGHT_RECOVERY_RATE = 0.005;
    end
    
    methods
        %% Constructor
        function obj = ShelfImpl4(cropType,cropArea,Environment,GreyWaterSource,PotableWaterSource,PowerSource,BiomassOutput,growthStartTime)
            
            if nargin > 0
                % Shelf specific initialization
                obj.Crop = cropType;
                obj.CropName = cropType.Name;
                obj.cropAreaUsed = cropArea;
                obj.cropAreaTotal = cropArea;
                obj.PowerConsumerDefinition = ResourceUseDefinitionImpl;
                obj.AirConsumerDefinition = ResourceUseDefinitionImpl;
                obj.PotableWaterConsumerDefinition = ResourceUseDefinitionImpl;
                obj.GreyWaterConsumerDefinition = ResourceUseDefinitionImpl;
                obj.DirtyWaterProducerDefinition = ResourceUseDefinitionImpl;
                obj.AirProducerDefinition = ResourceUseDefinitionImpl;
                obj.BiomassProducerDefinition = ResourceUseDefinitionImpl;
                obj.ShelfWaterNeeded = obj.cropAreaUsed*obj.waterNeededPerSquareMeter;  % m^2 * L/m^2 = L
                
                % Initialize values corresponding to plant-specific
                % characteristics (passed up from subclass)
                obj.CanopyClosureConstants = cropType.CanopyClosureConstants;
                obj.CanopyQuantumYieldConstants = cropType.CanopyQuantumYieldConstants;
                obj.CurrentPPF = cropType.initialPPFValue;
                obj.TargetPPF = cropType.initialPPFValue; 
                obj.CurrentCO2Concentration = Environment.CO2Percentage*1E6;
                obj.CanopyClosurePPFValues = [];%cropType.taInitialValue;
                obj.CanopyClosureCO2Values = [];%cropType.taInitialValue;
                
                if ~(strcmpi(cropType.Type,'Legume'))
                    obj.carbonUseEfficiency24 = cropType.CarbonUseEfficiency24;     % Initialize here for all plant types. This changes within the growBiomass method if the plant is of type "Legume"
                end
                
                % Initialize consumer/producer relationships
                defaultLimitingFlowRate = 1000;     % Arbitrarily set - informed by BioSim value for the PlantImpl class
                obj.AirConsumerDefinition = ResourceUseDefinitionImpl(Environment);
                obj.AirProducerDefinition = ResourceUseDefinitionImpl(Environment);
                obj.GreyWaterConsumerDefinition = ResourceUseDefinitionImpl(GreyWaterSource,defaultLimitingFlowRate,defaultLimitingFlowRate);
                obj.PotableWaterConsumerDefinition = ResourceUseDefinitionImpl(PotableWaterSource,defaultLimitingFlowRate,defaultLimitingFlowRate);
                obj.PowerConsumerDefinition = ResourceUseDefinitionImpl(PowerSource,defaultLimitingFlowRate,defaultLimitingFlowRate);
                obj.BiomassProducerDefinition = ResourceUseDefinitionImpl(BiomassOutput);
                
                if nargin > 7
                    obj.CropCycleStartTime = growthStartTime;
                end
            end
        end
        
        % Set Current PPF Value
        function set.CurrentPPF(obj,PPFval)
            obj.CurrentPPF = PPFval;
        end
        
        % Set Target PPF Value
        function set.TargetPPF(obj,PPFval)
            obj.TargetPPF = PPFval;
        end
        
        %% Tick
        function obj = tick(obj)
            
            % Do not run if crop has died
            if obj.hasDied == 1
                return
            end
            
            obj.tickcount = obj.tickcount + 1;  % Update tick
            
            if obj.tickcount >= obj.CropCycleStartTime
                % ShelfImpl.tick
                tryHarvesting(obj);              
                gatherWater(obj);
                
                % PlantImpl.tick
                obj.Age = obj.Age+1;        % ticking forward (in hours)
                
                % Determine whether crop is in light period or dark period
                obj.isLightPeriod = mod(obj.Age,24) <= (obj.Crop.Photoperiod-1);    % Light/dark period calculated based on crop light period first occurring (defined by obj.Crop.Photoperiod), followed by dark period

                gatherPower(obj);
                lightPlants(obj);
                if obj.hasDied == 0
                    growBiomass(obj);
                    obj.TotalWaterNeeded = obj.TotalWaterNeeded + obj.WaterNeeded;
                    obj.AverageWaterNeeded = obj.TotalWaterNeeded/obj.Age;
                end
            end
        end
               
        %% tryHarvesting
        % We assume that autonomous harvesting and replanting is always
        % enabled
        
        function tryHarvesting(obj)
            % Harvest if crop has reached maturity or if crop has died
            if obj.Age/24 >= obj.Crop.TimeAtCropMaturity || obj.hasDied == 1
                inedibleFraction = 1 - obj.CurrentEdibleWetBiomass/obj.CurrentTotalWetBiomass;
                biomassProduced = BioMatter(obj.Crop,obj.CurrentTotalWetBiomass,inedibleFraction,...
                    obj.CurrentWaterInsideEdibleBiomass,obj.CurrentWaterInsideInedibleBiomass);     % Harvest crop
                obj.BiomassProducerDefinition.ResourceStore.add(biomassProduced); % send to biomass store - note that the upper bound from the max and desired flow arets should be divided by the number of shelves (pushFractionalResources)
                reset(obj);         % reset plant
            end
        
        end

        %% gatherPower
        function gatherPower(obj)     
            powerNeeded = obj.powerPerSquareMeter*obj.cropAreaUsed*obj.isLightPeriod;
            obj.ShelfPowerLevel = obj.PowerConsumerDefinition.ResourceStore.take(powerNeeded,obj.PowerConsumerDefinition);   % note that the upper bound from the max and desired flow arets should be divided by the number of shelves (pushFractionalResources)
        end
        
        %% gatherWater
        function gatherWater(obj)
            extraWaterNeeded = max(obj.ShelfWaterNeeded-obj.ShelfWaterLevel,0);   % ensure this value is always >= 0
            
            % Gather grey water from greywater store first. If there is still
            % a water deficit, try to take the remainder from the potable water
            % store
            
            % Gather greywater first
            gatheredGreyWater = obj.GreyWaterConsumerDefinition.ResourceStore.take(extraWaterNeeded,obj.GreyWaterConsumerDefinition);
            
            % Gather remainder from potable water store
            gatheredPotableWater = obj.PotableWaterConsumerDefinition.ResourceStore.take(extraWaterNeeded-gatheredGreyWater,obj.PotableWaterConsumerDefinition);
            
            % Update water level within shelf
            obj.ShelfWaterLevel = obj.ShelfWaterLevel + gatheredGreyWater + gatheredPotableWater;
        
        end
        
        %% lightPlants
        function lightPlants(obj)
            powerToDeliver = max(min(obj.ShelfPowerLevel,obj.isLightPeriod*obj.CurrentPPF*obj.cropAreaUsed/(obj.lampEfficiency*obj.PSEfficiency)),0);        % Always enforce this value being >= 0
            obj.CurrentPPF = powerToDeliver*obj.lampEfficiency*obj.PSEfficiency/obj.cropAreaUsed;       % redefine current PPF according to amount of power available=
        end
               
        %% growBiomass
        function obj = growBiomass(obj)
            
            % Update total wet and edible wet biomass from previous tick
            obj.LastTotalWetBiomass = obj.CurrentTotalWetBiomass;
            obj.LastEdibleWetBiomass = obj.CurrentEdibleWetBiomass;
            
            daysOfGrowth = obj.Age/24;
            
            %% calculateAverageCO2Concentration - modified to be instantaneous current CO2 concentration
            obj.CurrentCO2Concentration = obj.AirConsumerDefinition.ResourceStore.CO2Percentage*1E6;  % Convert current CO2 levels to micromoles of CO2/moles of air
            if obj.CurrentCO2Concentration <= 150
                kill(obj);      % Kill Crop
                disp([obj.Crop.Name, ' crop has been killed at tick ',num2str(obj.tickcount),' due to insufficient [CO2]'])
                
            elseif obj.CurrentCO2Concentration > 1300       % if statement added to ensure that Modified Energy Cascade Model operates within the correct CO2 range (REF: Table 2, "Crop Models for Varying Environmental Conditions" - SAE 2002-01-2520)
                obj.CurrentCO2Concentration = 1300;
            end
            
            %% Determine time til canopy closure
            if obj.canopyClosed == 0
                % Close canopy if age is greater than time till canopy
                % closure (in days) and age of crop is > 1 hour
                if daysOfGrowth >= obj.TimeTillCanopyClosure && obj.Age > 1
                    obj.canopyClosed = 1;
                else
                    obj.TimeTillCanopyClosure = calculateTimeTillCanopyClosure(obj);
                end
            end
            
            %% calculatePPFFractionAbsorbed
            if obj.canopyClosed == 1
                obj.PPFFractionAbsorbed = 0.93;     % 0.93 corresponds to PPFFractionAbsorbedMax ... Most PPF is absorbed when the canopy is closed
            elseif obj.TimeTillCanopyClosure <= 0
                obj.PPFFractionAbsorbed = obj.PPFFractionAbsorbed;
            else
                % This line integrated the calculateDaDt function - this
                % equation is different to that in BVAD, so we assume that
                % it is incorrect
%                 obj.PPFFractionAbsorbed = obj.PPFFractionAbsorbed + ...
%                     (0.93*obj.Crop.N*...
%                     (daysOfGrowth/obj.TimeTillCanopyClosure)^(obj.Crop.N-1)/...
%                     obj.TimeTillCanopyClosure) / 24;      % This gives a fraction of the PPFFractionAbsorbedMax (0.93) value, scaled by DaDt

                obj.PPFFractionAbsorbed = 0.93*(obj.Age/(obj.TimeTillCanopyClosure*24))^obj.Crop.N;
                
            end
            
            %% CALCULATE BIOMASS GROWN DURING THE CURRENT TICK
            molecularWeightOfCarbon = 12.011;   % Move this line into a private property to speed up code in the future
            obj.CQY = calculateCQY(obj);        % Calculate Canopy Quantum Yield
            
            % Determining CarbonUseEfficiency24 depending on type of plant
            % (note special calculation for Legumes, otherwise, default value is decalred in constructor)
            if strcmpi(obj.Crop.Type,'Legume')
                cuemax = obj.Crop.CUEmax;
                timeTillCanopySenescence = obj.Crop.TimeAtCanopySenescence;
                if obj.Age < (timeTillCanopySenescence*24)
                    obj.carbonUseEfficiency24 = cuemax;
                else
                    cuemin = obj.Crop.CUEmin;
                    obj.carbonUseEfficiency24 = cuemax-( (cuemax-cuemin)*...
                        (obj.Age-timeTillCanopySenescence*24)/...
                        (obj.Crop.TimeAtCropMaturity*24-timeTillCanopySenescence*24) );
                    obj.carbonUseEfficiency24 = obj.carbonUseEfficiency24*(obj.carbonUseEfficiency24>=0);
                end
            end            
            
            % calculateDailyCarbonGain (in g/m^2/day)
            hourlyCarbonGain = 0.0036*obj.carbonUseEfficiency24*...
                obj.PPFFractionAbsorbed*obj.CQY*obj.CurrentPPF;                 % amount of carbon absorbed daily = function of photoperiod, carbon use efficieny, CQY (moles of Carbon/m^2/day)
            % From Monje & Bugbee - "Adaptation to high CO2 concentration
            % in an optimal environment, radiation capture, canopy quantum
            % yield, and carbon use efficiency":
            % CQY is related to the quantum yield of single leaves, but is
            % determined from the ratio of canopy gross photosynthesis to
            % the absorbed radiation. CQY measures the photo-chemical
            % conversion efficiency of absorbed radiation into fixed carbon
           
            obj.DailyCarbonGain = hourlyCarbonGain;      % (moles of Carbon/m^2/day)
                        
            cropGrowthRate = molecularWeightOfCarbon*(hourlyCarbonGain/obj.Crop.BCF);        % carbon use in grams/m^2/day, BCF = biomass carbon fraction (ref BVAD and "Crop Models for Varying Environmental Conditions")
            
            obj.CropGrowthRate = cropGrowthRate;
            
            % Update current dry biomass production rate (in kg/hr)
            obj.CurrentDryBiomass = obj.CurrentDryBiomass + ...
                cropGrowthRate/1000*obj.cropAreaUsed;     % NB. that obj.CropArea should correspond to ShelfImpl.CropAreaUsed (in kg)
            
            % Update current amount of edible dry biomass according to time
            % of organ formation
            obj.CurrentEdibleDryBiomass = obj.CurrentEdibleDryBiomass + ...
                (obj.Age>(obj.Crop.TimeAtOrganFormation*24))*cropGrowthRate/1000*obj.cropAreaUsed*obj.Crop.FractionOfEdibleBiomass;
            
            % Note that in the below calculations, wet biomass = dry
            % biomass + water content
            
            % Determine amount of water inside edible biomass given total
            % available biomass and water fraction within crop
            obj.CurrentWaterInsideEdibleBiomass = obj.CurrentEdibleDryBiomass*...
                obj.Crop.EdibleFreshBasisWaterContent / (1-obj.Crop.EdibleFreshBasisWaterContent);  % in kg
            
            % Update current edible wet biomass (= dry biomass + its water
            % content)
            obj.CurrentEdibleWetBiomass = obj.CurrentWaterInsideEdibleBiomass + obj.CurrentEdibleDryBiomass;
            
            CurrentInedibleDryBiomass = obj.CurrentDryBiomass - obj.CurrentEdibleDryBiomass;
            
            % Update CurrentWaterInsideInedibleBiomass
            obj.CurrentWaterInsideInedibleBiomass = CurrentInedibleDryBiomass*...
                obj.Crop.InedibleFreshBasisWaterContent/(1-obj.Crop.InedibleFreshBasisWaterContent);
            
            % Current Inedible Wet Biomass = Water Inside Inedible Biomass
            % + inedible dry biomass)
            CurrentInedibleWetBiomass = obj.CurrentWaterInsideInedibleBiomass + CurrentInedibleDryBiomass;
            
            % Update total wet biomass (edible + inedible)
            obj.CurrentTotalWetBiomass = CurrentInedibleWetBiomass + obj.CurrentEdibleWetBiomass;
            
            %% DETERMINE WATER CONSUMED BY PLANT DURING THE CURRENT TICK
            obj.WaterNeeded = calculateWaterUptake(obj);    % in Liters/day
            obj.WaterLevel = obj.takeWater(obj.WaterNeeded);        % take water from Shelf
            
            if obj.WaterNeeded == 0
                waterFraction = 1;
            else
                waterFraction = obj.WaterLevel/obj.WaterNeeded;
            end
            
            obj.WaterFraction = waterFraction;
            
            if waterFraction < 1
                obj.CurrentDryBiomass = obj.CurrentDryBiomass - (1-waterFraction)*...
                    cropGrowthRate/1000*obj.cropAreaUsed;
                
                if obj.Age > (obj.Crop.TimeAtOrganFormation*24)
                    
                    obj.CurrentEdibleDryBiomass = obj.CurrentEdibleDryBiomass - (1-waterFraction)*...
                        cropGrowthRate/1000*obj.cropAreaUsed*obj.Crop.FractionOfEdibleBiomass;
                end
                
                obj.CurrentWaterInsideEdibleBiomass = obj.CurrentEdibleDryBiomass*...
                    obj.Crop.EdibleFreshBasisWaterContent/(1-obj.Crop.EdibleFreshBasisWaterContent);
                
                obj.CurrentEdibleWetBiomass = obj.CurrentWaterInsideEdibleBiomass + obj.CurrentEdibleDryBiomass; 
                
                obj.CurrentWaterInsideInedibleBiomass = CurrentInedibleDryBiomass*...
                    obj.Crop.InedibleFreshBasisWaterContent/(1-obj.Crop.InedibleFreshBasisWaterContent);
                
                CurrentInedibleWetBiomass = obj.CurrentWaterInsideInedibleBiomass + CurrentInedibleDryBiomass;
                
                obj.CurrentTotalWetBiomass = CurrentInedibleWetBiomass + obj.CurrentEdibleWetBiomass;
                
            end
            
            %% EXHALE AIR
            % Air exhaled is proportional to amount of water available (as
            % compared to water needed)
%             if waterFraction < 1
%                 dailyO2MolesProduced = waterFraction*obj.Crop.OPF*dailyCarbonGain*obj.cropAreaUsed;
%             else
%                 dailyO2MolesProduced = obj.Crop.OPF*dailyCarbonGain*obj.cropAreaUsed;       % [moles/day]
%             end
            

            % Hourly Photosynthetic Oxygen Production (HOP) - This
            % contribution only occurs during the light period
            HOP = waterFraction * hourlyCarbonGain/obj.carbonUseEfficiency24*obj.Crop.OPF*obj.cropAreaUsed;     % [moles]
                        
            % Hourly Oxygen Consumption from Plant (Dark) Respiration (HOC)
            % - this is a constant contribution - regardless of light or
            % dark period
            HOC = waterFraction * 0.0036*(1-obj.carbonUseEfficiency24)*...
                obj.PPFFractionAbsorbed*obj.CQY*obj.TargetPPF*obj.Crop.Photoperiod/24*obj.Crop.OPF*obj.cropAreaUsed;     % [moles];
            
            

%             dailyO2MolesProduced = molesOfCO2ToInhale;      % Line added 12/19 to ensure moles of O2 produced = moles of CO2 consumed
            
            % OPF is the oxygen production fraction in moles of O2 produced
            % per moles of CO2 inhaled (reverse of respiration quotient)
              
            % Update O2 grams produced (note molecular weight of O2 assumed
            % to be 32grams/mol. We divide by 24 to get the hourly rate of
            % O2 production)
%             obj.totalO2GramsProduced = obj.totalO2GramsProduced + dailyO2MolesProduced*32/24;   % [cumulative grams/hour]
                
            % Add O2 produced to Air Producer Store (note we divide by 24
            % to get the hourly rate)
            obj.MolesOfO2Exhaled = HOP-HOC;   % [moles/hour]
            obj.AirProducerDefinition.ResourceStore.O2Store.add(HOP);   % [moles/hour]
            obj.AirProducerDefinition.ResourceStore.O2Store.take(HOC);   % [moles/hour]
            
            
            %% INHALE AIR
            % Air inhaled is proportional to amount of water available (as
            % compared to water needed)
%             if waterFraction < 1
%                 molesOfCO2ToInhale = waterFraction*obj.Crop.OPF*hourlyCarbonGain*obj.cropAreaUsed;    % Line modified on 12/19/2014 to equal O2 produced
%             else
%                 molesOfCO2ToInhale = obj.Crop.OPF*hourlyCarbonGain*obj.cropAreaUsed/24;  % Line modified on 12/19/2014 to equal O2 produced      % [moles/hour]
%             end

            % Equate CO2 consumed to equal to O2 produced
            % *CO2 consumed = O2 produced
            % *CO2 produced = O2 consumed
            molesOfCO2ToInhale = HOP;
            molesOfCO2ToExhale = HOC;
            
            % Take CO2 from Air Consumer store
            obj.MolesOfCO2Inhaled = obj.AirConsumerDefinition.ResourceStore.CO2Store.take(molesOfCO2ToInhale);
            
            % Exhale CO2 to Air Producer Store
            obj.AirProducerDefinition.ResourceStore.CO2Store.add(molesOfCO2ToExhale);
            
            % Update total grams of CO2 consumed (note that molecular
            % weight of CO2 is taken here to be 44)
%             obj.totalCO2GramsConsumed = obj.totalCO2GramsConsumed + obj.MolesOfCO2Inhaled*44;
                            
            %% DETERMINE WATER VAPOR PRODUCED
            if waterFraction < 1
                litersOfWaterProduced = waterFraction*calculateHourlyCanopyTranspirationRate(obj)*obj.cropAreaUsed;
            else
                litersOfWaterProduced = calculateHourlyCanopyTranspirationRate(obj)*obj.cropAreaUsed;
            end            
%             obj.DailyCanopyTranspirationRate = calculateHourlyCanopyTranspirationRate(obj);
            % Update totalWaterLitersTranspired
            obj.totalWaterLitersTranspired = obj.totalWaterLitersTranspired + litersOfWaterProduced;
            
            % Convert Liters to moles and add resulting vapor to Air
            % Producer Vapor store (assumed: 998.23g/L and 18.01524g/mol)
            molesOfWaterProduced = litersOfWaterProduced*998.23/18.01524;
            
            % Record raw moles of water vapor moles transpired
            obj.VaporTranspired = molesOfWaterProduced;
            
            obj.AirProducerDefinition.ResourceStore.VaporStore.add(molesOfWaterProduced);
            
        end
        
        %% calculateTimeTillCanopyClosure
        function timeTillCanopyClosure = calculateTimeTillCanopyClosure(obj)
            
            %% get average for list
            %                 obj.CanopyClosurePPFValues,obj.AveragePPF
            
            %                 totalReal = sum(obj.CanopyClosurePPFValues);
            %                 totalFiller = obj.AveragePPF*(obj.TimeTillCanopyClosure*24-length(obj.CanopyClosurePPFValues));
            %                 output = (totalFiller+totalReal)/(obj.TimeTillCanopyClosure*24);
            
                        
%             if length(obj.CanopyClosurePPFValues) < 2
%                 averageValue = obj.AveragePPF;
                thePPF = obj.CurrentPPF*...
                    obj.Crop.Photoperiod/obj.Crop.NominalPhotoperiod;
%             else
% %                 averageValue = (obj.AveragePPF*(obj.TimeTillCanopyClosure*24-length(obj.CanopyClosurePPFValues))+...
% %                     sum(obj.CanopyClosurePPFValues))/(obj.TimeTillCanopyClosure*24);
%                 thePPF = (obj.AveragePPF*(obj.TimeTillCanopyClosure*24-length(obj.CanopyClosurePPFValues))+...
%                     sum(obj.CanopyClosurePPFValues))/(obj.TimeTillCanopyClosure*24)*...
%                     obj.Crop.Photoperiod/obj.Crop.NominalPhotoperiod;
%             end
            
%             thePPF = averageValue*...
%                 obj.Crop.Photoperiod/obj.Crop.NominalPhotoperiod;       % First part of this expression corresponds to teh output of AverageForList(myCanopyClosurePPFValues,AveragePPF)
            
%             if length(obj.CanopyClosureCO2Values) < 2
                theCO2 = obj.CurrentCO2Concentration;
%             else
%                 theCO2 = (obj.AverageCO2Concentration*(obj.TimeTillCanopyClosure*24-length(obj.CanopyClosureCO2Values))+...
%                     sum(obj.CanopyClosureCO2Values))/(obj.TimeTillCanopyClosure*24);
%             end
            
            tA = obj.CanopyClosureConstants(1) * 1/thePPF * 1/theCO2 ...
                + obj.CanopyClosureConstants(2) * 1/thePPF ...
                + obj.CanopyClosureConstants(3) * 1/thePPF * theCO2...
                + obj.CanopyClosureConstants(4) * 1/thePPF * theCO2^2 ...
                + obj.CanopyClosureConstants(5) * 1/thePPF * theCO2^3 ...
                + obj.CanopyClosureConstants(6) * 1/theCO2 ...
                + obj.CanopyClosureConstants(7) ...
                + obj.CanopyClosureConstants(8) * theCO2 ...
                + obj.CanopyClosureConstants(9) * theCO2^2 ...
                + obj.CanopyClosureConstants(10) * theCO2^3 ...
                + obj.CanopyClosureConstants(11) * thePPF * 1/theCO2 ...
                + obj.CanopyClosureConstants(12) * thePPF ...
                + obj.CanopyClosureConstants(13) * thePPF * theCO2 ...
                + obj.CanopyClosureConstants(14) * thePPF * theCO2^2 ...
                + obj.CanopyClosureConstants(15) * thePPF * theCO2^3 ...
                + obj.CanopyClosureConstants(16) * thePPF^2 * 1/theCO2 ...
                + obj.CanopyClosureConstants(17) * thePPF^2 ...
                + obj.CanopyClosureConstants(18) * thePPF^2 * theCO2 ...
                + obj.CanopyClosureConstants(19) * thePPF^2 * theCO2^2 ...
                + obj.CanopyClosureConstants(20) * thePPF^2 * theCO2^3 ...
                + obj.CanopyClosureConstants(21) * thePPF^3 * 1/theCO2 ...
                + obj.CanopyClosureConstants(22) * thePPF^3 ...
                + obj.CanopyClosureConstants(23) * thePPF^3 * theCO2 ...
                + obj.CanopyClosureConstants(24) * thePPF^3 * theCO2^2 ...
                + obj.CanopyClosureConstants(25) * thePPF^3 * theCO2^3;
                        
            tA = (tA>=0)*tA;    % zero out tA if its value is less than zero
            
            if isnan(tA)
                tA = 0;
            end
            
            timeTillCanopyClosure = round(tA);  % Final time until canopy closure is rounded (according to BioSim PlantImpl code)
            
        end
        
        %% calculateCQY (Canopy Quantum Yield)
        function cqy = calculateCQY(obj)
            % Calculate CQYmax
            thePPF = obj.CurrentPPF;
            theCO2 = obj.CurrentCO2Concentration;
            CQYmax = obj.CanopyQuantumYieldConstants(1) * 1/thePPF * 1/theCO2 ...
                + obj.CanopyQuantumYieldConstants(2) * 1/thePPF ...
                + obj.CanopyQuantumYieldConstants(3) * 1/thePPF * theCO2 ...
                + obj.CanopyQuantumYieldConstants(4) * 1/thePPF * theCO2^2 ...
                + obj.CanopyQuantumYieldConstants(5) * 1/thePPF * theCO2^3 ...
                + obj.CanopyQuantumYieldConstants(6) * 1/theCO2 ...
                + obj.CanopyQuantumYieldConstants(7) ...
                + obj.CanopyQuantumYieldConstants(8) * theCO2 ...
                + obj.CanopyQuantumYieldConstants(9) * theCO2^2 ...
                + obj.CanopyQuantumYieldConstants(10) * theCO2^3 ...
                + obj.CanopyQuantumYieldConstants(11) * thePPF * 1/theCO2 ...
                + obj.CanopyQuantumYieldConstants(12) * thePPF ...
                + obj.CanopyQuantumYieldConstants(13) * thePPF * theCO2 ...
                + obj.CanopyQuantumYieldConstants(14) * thePPF * theCO2^2 ...
                + obj.CanopyQuantumYieldConstants(15) * thePPF * theCO2^3 ...
                + obj.CanopyQuantumYieldConstants(16) * thePPF^2 * 1/theCO2 ...
                + obj.CanopyQuantumYieldConstants(17) * thePPF^2 ...
                + obj.CanopyQuantumYieldConstants(18) * thePPF^2 * theCO2 ...
                + obj.CanopyQuantumYieldConstants(19) * thePPF^2 * theCO2^2 ...
                + obj.CanopyQuantumYieldConstants(20) * thePPF^2 * theCO2^3 ...
                + obj.CanopyQuantumYieldConstants(21) * thePPF^3 * 1/theCO2 ...
                + obj.CanopyQuantumYieldConstants(22) * thePPF^3 ...
                + obj.CanopyQuantumYieldConstants(23) * thePPF^3 * theCO2 ...
                + obj.CanopyQuantumYieldConstants(24) * thePPF^3 * theCO2^2 ...
                + obj.CanopyQuantumYieldConstants(25) * thePPF^3 * theCO2^3;
            
            CQYmax = CQYmax*(CQYmax>=0);        % Enforce CQYmax to be >= 0
            
            if isnan(CQYmax)
                CQYmax = 0;
            end
            
            % Continue determining CQY
            %                 timeTillCanopySenescence = obj.Crop.TimeAtCanopySenescence;
            if obj.Age < (obj.Crop.TimeAtCanopySenescence*24)
                cqy = CQYmax;
            else
                %                     CQYmin = obj.Crop.CQYMin;
                %                     daysOfGrowth = obj.Age/24;
                %                     timeTillCropMaturity = obj.Crop.TimeAtCropMaturity;
                calculatedCQY = CQYmax - (CQYmax-obj.Crop.CQYMin)*(obj.Age-obj.Crop.TimeAtCanopySenescence*24)/...
                    (obj.Crop.TimeAtCropMaturity*24-obj.Crop.TimeAtCanopySenescence*24);
                cqy = calculatedCQY*(calculatedCQY>=0);
            end
        end
        
        %% calculateWaterUptake
        function waterUptake = calculateWaterUptake(obj)
            hourlyCanopyTranspirationRate = calculateHourlyCanopyTranspirationRate(obj)*obj.cropAreaUsed;     % NB. that obj.CropArea should correspond to ShelfImpl.CropAreaUsed
            
            obj.HourlyCanopyTranspirationRate = hourlyCanopyTranspirationRate;
            
            % calculateWetIncorporatedWaterUptake
            CurrentInedibleWetBiomass = max(obj.CurrentTotalWetBiomass - obj.CurrentEdibleWetBiomass,0);
            LastInedibleWetBiomass = max(obj.LastTotalWetBiomass - obj.LastEdibleWetBiomass,0);
            wetIncorporatedWaterUptake = (obj.CurrentEdibleWetBiomass-obj.LastEdibleWetBiomass)*obj.Crop.EdibleFreshBasisWaterContent+...
                (CurrentInedibleWetBiomass-LastInedibleWetBiomass)*obj.Crop.InedibleFreshBasisWaterContent;
            
            % calculateDryIncorporatedWaterUptake --> where does this
            % random additional water uptake come from and what does it
            % represent?
%             dryIncorporatedWaterUptake = (hourlyCanopyTranspirationRate+wetIncorporatedWaterUptake)/500;
            % Aggregate water uptake sources into a total waterUptake
            % water absorbed = water required for transpiration + water
            % absorbed into water content of food
            waterUptake = hourlyCanopyTranspirationRate+wetIncorporatedWaterUptake;%+dryIncorporatedWaterUptake;
        end
        
        %% calculateHourlyCanopyTranspirationRate
        function hourlycanopytranspirationrate = calculateHourlyCanopyTranspirationRate(obj)
            airPressure = obj.AirProducerDefinition.ResourceStore.pressure;     % Pressure within air producer sink
%             vaporPressureDeficit = calculateVaporPressureDeficit(obj);
            
            % BEWARE OF POTENTIAL ERROR WITH CALLING THIS METHOD TOO EARLY
            vaporPressureDeficit = calculateVaporPressureDeficit(obj);
            
            %% calculateCanopySurfaceConductance
            % calculateCanopyStomatalConductance
            if strcmpi(obj.Crop.Type,'Erectophile')
                % This section of the code is taken from the
                % BioSim Erectophile class file
                relativeHumidity = obj.AirProducerDefinition.ResourceStore.RelativeHumidity;
                netCanopyPhotosynthesis = calculateNetCanopyPhotosynthesis(obj);
                canopyStomatalConductance = 0.1389 + 15.32*relativeHumidity*...
                    (netCanopyPhotosynthesis/obj.CurrentCO2Concentration);
                
            else % (if planophile or legume)
                % calculateVaporPressureDeficit
                %                     vaporPressureDeficit = calculateVaporPressureDeficit(obj);
                netCanopyPhotosynthesis = calculateNetCanopyPhotosynthesis(obj);
                canopyStomatalConductance = max((1.717*obj.AirProducerDefinition.ResourceStore.temperature - 19.96 - 10.54*vaporPressureDeficit)*...
                    (netCanopyPhotosynthesis/obj.CurrentCO2Concentration),0);
            end
            
            obj.NetCanopyPhotosynthesis = netCanopyPhotosynthesis;
            
            % calculateAtmosphericAeroDynamicConductance
            if strcmpi(obj.Crop.Type,'Erectophile')
                atmosphericAeroDynamicConductance = 5.5;
            else % (if planophile or legume)
                atmosphericAeroDynamicConductance = 2.5;
            end
            
            canopySurfaceConductance = (atmosphericAeroDynamicConductance * canopyStomatalConductance)...
                / (canopyStomatalConductance + atmosphericAeroDynamicConductance);
            % end calculateCanopyStomatalConductance
                        
            hourlycanopytranspirationrate = 3600*(18.015/998.23)*...
                canopySurfaceConductance*(vaporPressureDeficit/airPressure);
        end
        
        %% calculateVaporPressureDeficit
        function vaporPressureDeficit = calculateVaporPressureDeficit(obj)
            environmentalTemperature = obj.AirProducerDefinition.ResourceStore.temperature;
            
            saturatedMoistureVaporPressure = 0.611*exp(17.4*environmentalTemperature/(environmentalTemperature+239));
            actualMoistureVaporPressure = obj.AirProducerDefinition.ResourceStore.VaporPercentage...
                *obj.AirProducerDefinition.ResourceStore.pressure;      % According to BVAD - this should equal: saturatedMoistureVaporPressure * RelativeHumidity (RH is the mean atmospheric relative humidity as a fraction bounded between 0 and 1, inclusive.)
            vaporPressureDeficit = saturatedMoistureVaporPressure - actualMoistureVaporPressure;
            vaporPressureDeficit = vaporPressureDeficit*(vaporPressureDeficit>=0);
        end
        
        
        %% calculateNetCanopyPhotosynthesis
        function netCanopyPhotosynthesis = calculateNetCanopyPhotosynthesis(obj)
%             plantGrowthDiurnalCycle = 24;
            % calculateGrossCanopyPhotosynthesis
            netCanopyPhotosynthesis = obj.CurrentPPF * obj.CQY * obj.PPFFractionAbsorbed;
%             photoperiod = obj.Crop.Photoperiod;
%             netCanopyPhotosynthesis = ((plantGrowthDiurnalCycle-photoperiod)/plantGrowthDiurnalCycle + ...
%                 (photoperiod*obj.carbonUseEfficiency24)/plantGrowthDiurnalCycle)*grossCanopyPhotosynthesis;
        end
        
        %% takeWater
        function waterTaken = takeWater(obj,waterNeeded)
            % If water level is less than what is desired to be taken
            if waterNeeded > obj.ShelfWaterLevel
                waterTaken = obj.ShelfWaterLevel;
                obj.ShelfWaterLevel = 0;         % reset obj.waterLevel to zero
            else
                % nominal case where there is enough water available to
                % support the waterNeeded
                obj.ShelfWaterLevel = obj.ShelfWaterLevel - waterNeeded;
                waterTaken = waterNeeded;
            end
        end
        
        %% Reset
        function reset(obj)
            obj.Age = 0;        % Age of current crop group
            obj.hasDied = 0;
            obj.canopyClosed = 0;
            obj.CurrentPPF = obj.Crop.initialPPFValue;
%             obj.TotalPPF = 0;
%             obj.NumberOfPPFReadings = 0;
            obj.AverageWaterNeeded = 0;
            obj.TotalWaterNeeded = 0;
%             obj.AverageCO2Concentration = obj.Crop.initialCO2Value;
%             obj.TotalCO2Concentration = 0;
%             obj.NumberOfCO2ConcentrationReadings = 0;
            obj.CurrentWaterInsideInedibleBiomass = 0;
            obj.CurrentWaterInsideEdibleBiomass = 0;
            obj.CurrentTotalWetBiomass = 0;
            obj.CurrentEdibleWetBiomass = 0;
            obj.CurrentEdibleDryBiomass = 0;
            obj.CurrentDryBiomass = 0;
            obj.LastTotalWetBiomass = 0;
            obj.LastEdibleWetBiomass = 0;
            obj.WaterNeeded = 0;
            obj.WaterLevel = 0;
            obj.CQY = 0;
            obj.carbonUseEfficiency24 = 0;
%             obj.totalO2GramsProduced = 0;
            obj.totalCO2GramsConsumed = 0;
            obj.totalWaterLitersTranspired = 0;
            obj.TimeTillCanopyClosure = 0;       % in days
            obj.PPFFractionAbsorbed = 0;
            obj.MolesOfCO2Inhaled = 0;
            
            % Reinitialize carbon use efficiency
            if ~(strcmpi(obj.Crop.Type,'Legume'))
                obj.carbonUseEfficiency24 = obj.Crop.CarbonUseEfficiency24;     % Initialize here for all plant types. This changes within the growBiomass method if the plant is of type "Legume"
            end
            
        end
        
        %% Kill
        function kill(obj)
            reset(obj);
            obj.hasDied = 1;
        end
        
    end
    
end

