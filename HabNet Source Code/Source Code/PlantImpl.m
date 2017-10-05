classdef PlantImpl < handle
    %PlantImpl Summary of this class goes here
    %   By: Sydney Do (sydneydo@mit.edu)
    %   Date Created: 6/2/2014
    %   Last Updated: 6/5/2014
    %
    %   This is the parent class of all higher plants grown in the shelves
    %   of the BiomassPS
    
    properties
        CropName
        Crop
        Shelf           % this is of type ShelfImpl - Shelf that the plant is growing in
        Age = 0;        % Age of current crop group
        hasDied = 0;
        canopyClosed = 0;        
        CropArea

        AveragePPF = 0;
        myTotalPPF = 0;
        myNumberOfPPFReadings = 0;
        AverageWaterNeeded = 0;
        TotalWaterNeeded = 0;
        AverageCO2Concentration = 0;
        TotalCO2Concentration = 0;
        NumberOfCO2ConcentrationReadings = 0;
        CurrentWaterInsideInedibleBiomass = 0;
        CurrentWaterInsideEdibleBiomass = 0;
        CurrentTotalWetBiomass = 0;
        CurrentEdibleWetBiomass = 0;
        CurrentEdibleDryBiomass = 0;
        CurrentDryBiomass = 0;
        LastTotalWetBiomass = 0;
        LastEdibleWetBiomass = 0;
        WaterNeeded = 0;
        WaterLevel = 0;
        CQY = 0;      % canopy quantum yield, defined as the ratio of carbon fixed (C-mol) over the total light absorbed (# of photons)
        % (From: SAE 2000-01-2261: CQY: the number of moles of carbon that are fixed in sucrose for each
        % mole of PPF absorbed
        carbonUseEfficiency24 = 0;
        totalO2GramsProduced = 0;
        totalCO2GramsConsumed = 0;
        totalCO2MolesConsumed = 0;
        totalWaterLitersTranspired = 0
        TimeTillCanopyClosure = 0       % in days
        CanopyClosureConstants
        CanopyQuantumYieldConstants
        PPFFractionAbsorbed = 0;
        CanopyClosurePPFValues
        CanopyClosureCO2Values
        ProductionRate = 1;
        MolesOfCO2Inhaled = 0;
    end
    
    properties (Access = private)
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
        function obj = PlantImpl(cropType,cropArea,shelf)
            if ~(strcmpi(class(shelf),'ShelfImpl'))
                error('Input for shelf must be of type "ShelfImpl"');
            end
            
            if nargin > 0
                obj.Crop = cropType;
                obj.CropName = cropType.Name;
                obj.CropArea = cropArea;
                obj.Shelf = shelf;
                
                % Initialize values corresponding to plant-specific
                % characteristics (passed up from subclass)
                obj.CanopyClosureConstants = cropType.CanopyClosureConstants;
                obj.CanopyQuantumYieldConstants = cropType.CanopyQuantumYieldConstants;
                obj.AveragePPF = cropType.initialPPFValue;
                obj.AverageCO2Concentration = cropType.initialCO2Value;
                obj.CanopyClosurePPFValues = cropType.taInitialValue;
                obj.CanopyClosureCO2Values = cropType.taInitialValue;
                obj.carbonUseEfficiency24 = obj.Crop.CarbonUseEfficiency24;     % Initialize here for all plant types. This changes within the growBiomass method if the plant is of type "Legume"
            end
        end
        
        %% Tick
        function obj = tick(obj)
            obj.Age = obj.Age+1;        % ticking forward (in hours)
            if obj.hasDied == 0
                growBiomass(obj);
                obj.TotalWaterNeeded = obj.TotalWaterNeeded + obj.WaterNeeded;
                obj.AverageWaterNeeded = obj.TotalWaterNeeded/obj.Age;
            end
        end
               
        %% growBiomass
        function obj = growBiomass(obj)
            
            %             waterFraction = 0;
            %             litersOfWaterProduced = 0;
            
            % Update total wet and edible wet biomass from previous tick
            obj.LastTotalWetBiomass = obj.CurrentTotalWetBiomass;
            obj.LastEdibleWetBiomass = obj.CurrentEdibleWetBiomass;
            
            daysOfGrowth = obj.Age/24;
            
            %% calculateAverageCO2Concentration
            currentCO2concentration = obj.Shelf.AirConsumerDefinition.ResourceStore.CO2Percentage*1E6;  % Convert current CO2 levels to micromoles of CO2/moles of air
            % Append vector of CanopyClosureCO2Values if canopy is not closed
            if obj.canopyClosed == 0
                obj.CanopyClosureCO2Values = [obj.CanopyClosureCO2Values currentCO2concentration];
            end
            obj.TotalCO2Concentration = obj.TotalCO2Concentration + currentCO2Concentration;
            obj.NumberOfCO2ConcentrationReadings = obj.NumberOfCO2ConcentrationReadings + 1;
            obj.AverageCO2Concentration = obj.TotalCO2Concentration / obj.NumberOfCO2ConcentrationReadings;
            
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
            else
                % This line integrated the calculateDaDt function
                obj.PPFFractionAbsorbed = obj.PPFFractionAbsorbed + ...
                    (obj.TimeTillCanopyClosure>0)*0.93*obj.Crop.N*...
                    (obj.Age/24/obj.TimeTillCanopyClosure)^(obj.Crop.N-1)/...
                    obj.TimeTillCanopyClosure/24;      % This gives a fraction of the PPFFractionAbsorbedMax (0.93) value, scaled by DaDt
            end
            
            %% CALCULATE BIOMASS GROWN DURING THE CURRENT TICK
            molecularWeightOfCarbon = 12.011;
            obj.CQY = calculateCQY(obj);        % Calculate Canopy Quantum Yield
            
            % Determining CarbonUseEfficiency24 depending on type of plant
            % (note special calculation for Legumes, otherwise, default value is decalred in constructor)
            if strcmpi(obj.Crop.Type,'Legume')
                cuemax = obj.Crop.CUEmax;
                timeTillCanopySenescence = obj.Crop.TimeAtCanopySenescence;
                if daysOfGrowth < timeTillCanopySenescence
                    obj.carbonUseEfficiency24 = cuemax;
                else
                    cuemin = obj.Crop.CUEmin;
                    obj.carbonUseEfficiency24 = cuemax-( (cuemax-cuemin)*...
                        (daysOfGrowth-timeTillCanopySenescence)/...
                        (obj.Crop.TimeAtCropMaturity-timeTillCanopySenescence) );
                    obj.carbonUseEfficiency24 = obj.carbonUseEfficiency24*(obj.carbonUseEfficiency24>=0);
                end
            end
            %             else
            %                 obj.carbonUseEfficiency24 = obj.Crop.CarbonUseEfficiency24;
            %             end
            
            
            % calculateDailyCarbonGain (in g/m^2/day)
            dailyCarbonGain = 0.0036*obj.Crop.Photoperiod*obj.carbonUseEfficiency24*...
                obj.PPFFractionAbsorbed*obj.CQY*obj.AveragePPF;
            
            % Add daily carbon gain at the end of every 24hour period
            %             if mod(obj.Age,24) == 0
            %                 obj.totalCO2MolesConsumed = obj.totalCO2MolesConsumed + dailyCarbonGain;
            %             end
            % Faster Implementation of Above Lines
            obj.totalCO2MolesConsumed = obj.totalCO2MolesConsumed + (mod(obj.Age,24)==0)*dailyCarbonGain;
            
            cropGrowthRate = molecularWeightOfCarbon*(dailyCarbonGain/obj.Crop.BCF);        % in grams/day - find out what BCF is!
            
            % Update current dry biomass production rate (in kg/hr)
            obj.CurrentDryBiomass = obj.CurrentDryBiomass + ...
                cropGrowthRate/1000/24*obj.Shelf.cropAreaUsed*obj.ProductionRate;     % NB. that obj.CropArea should correspond to ShelfImpl.CropAreaUsed
            
            % Update current amount of edible dry biomass according to time
            % of organ formation
            %             if daysOfGrowth > obj.Crop.TimeAtOrganFormation
            %                 obj.CurrentEdibleDryBiomass = obj.CurrentEdibleDryBiomass + ...
            %                     cropGrowthRate/1000/24*obj.CropArea*obj.Crop.FractionOfEdibleBiomass;
            %             end
            % Faster Implementation of Above Lines
            obj.CurrentEdibleDryBiomass = obj.CurrentEdibleDryBiomass + ...
                (daysOfGrowth>obj.Crop.TimeAtOrganFormation)*cropGrowthRate/1000/24*obj.Shelf.cropAreaUsed*obj.Crop.FractionOfEdibleBiomass;
            
            % Note that in the below calculations, wet biomass = dry
            % biomass + water content
            
            % Determine amount of water inside edible biomass given total
            % available biomass and water fraction within crop
            obj.CurrentWaterInsideEdibleBiomass = obj.CurrentEdibleDryBiomass*...
                obj.Crop.EdibleFreshBasisWaterContent / (1-obj.Crop.EdibleFreshBasisWaterContent);
            
            % Update current edible wet biomass (= dry biomass + its water
            % content)
            obj.CurrentEdibleWetBiomass = obj.CurrentWaterInsideEdibleBiomass + obj.CurrentEdibleDryBiomass;
            
            CurrentInedibleDryBiomass = obj.CurrentEdibleDryBiomass - obj.CurrentEdibleWetBiomass;
            
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
            obj.WaterLevel = obj.Shelf.takeWater(obj.WaterNeeded);
            
            if obj.WaterNeeded == 0
                waterFraction = 1;
            else
                waterFraction = obj.WaterLevel/obj.WaterNeeded;
            end
            
            if waterFraction < 1
                obj.CurrentDryBiomass = obj.CurrentDryBiomass - (1-waterFraction)*...
                    cropGrowthRate/1000/24*obj.Shelf.cropAreaUsed;
                
                if daysOfGrowth > obj.Crop.TimeAtOrganFormation
                    
                    obj.CurrentEdibleDryBiomass = obj.CurrentEdibleDryBiomass - (1-waterFraction)*...
                        cropGrowthRate/1000/24*obj.Shelf.cropAreaUsed*obj.Crop.FractionOfEdibleBiomass;
                end
                
                obj.CurrentWaterInsideEdibleBiomass = obj.CurrentEdibleDryBiomass*...
                    obj.Crop.EdibleFreshBasisWaterContent/(1-obj.Crop.EdibleFreshBasisWaterContent);
                
                obj.CurrentEdibleWetBiomass = obj.CurrentWaterInsideEdibleBiomass + obj.CurrentEdibleDryBiomass; 
                
                obj.CurrentWaterInsideInedibleBiomass = CurrentInedibleDryBiomass*...
                    obj.Crop.InedibleFreshBasisWaterContent/(1-obj.Crop.InedibleFreshBasisWaterContent);
                
                CurrentInedibleWetBiomass = obj.CurrentWaterInsideInedibleBiomass + CurrentInedibleDryBiomass;
                
                obj.CurrentTotalWetBiomass = CurrentInedibleWetBiomass + obj.CurrentEdibleWetBiomass;
                
            end
            
            %% INHALE AIR
            if waterFraction < 1
                molesOfCO2ToInhale = waterFraction*dailyCarbonGain*obj.Shelf.CropAreaUsed/24;
            else
                molesOfCO2ToInhale = dailyCarbonGain*obj.Shelf.CropAreaUsed/24;
            end
            
            % Take CO2 from Air Consumer store
            obj.MolesOfCO2Inhaled = obj.Shelf.AirConsumerDefinition.ResourceStore.CO2Store.take(molesOfCO2ToInhale);
            
            % Update total grams of CO2 consumed (note that molecular
            % weight of CO2 is taken here to be 44)
            obj.totalCO2GramsConsumed = obj.totalCO2GramsConsumed + obj.MolesOfCO2Inhaled*44;
                
            %% EXHALE AIR
            if waterFraction < 1
                dailyO2MolesProduced = waterFraction*obj.Crop.OPF*dailyCarbonGain*obj.Shelf.CropAreaUsed;
            else
                dailyO2MolesProduced = obj.Crop.OPF*dailyCarbonGain*obj.Shelf.CropAreaUsed;
            end
                
            % Update O2 grams produced (note molecular weight of O2 assumed
            % to be 32grams/mol. We divide by 24 to get the hourly rate of
            % O2 production)
            obj.totalO2GramsProduced = obj.totalO2GramsProduced + dailyO2MolesProduced*32/24;
                
            % Add O2 produced to Air Producer Store (note we divide by 24
            % to get the hourly rate)
            obj.Shelf.AirProducerDefinition.ResourceStore.O2Store.add(dailyO2MolesProduced/24);
            
            %% DETERMINE WATER VAPOR PRODUCED
            if waterFraction < 1
                litersOfWaterProduced = waterFraction*calculateDailyCanopyTranspirationRate(obj)/24 ...
                    *obj.Shelf.CropAreaUsed;
            else
                litersOfWaterProduced = calculateDailyCanopyTranspirationRate(obj)/24 ...
                    *obj.Shelf.CropAreaUsed;
            end            
            
            % Update totalWaterLitersTranspired
            obj.totalWaterLitersTranspired = obj.totalWaterLitersTranspired + litersOfWaterProduced;
            
            % Convert Liters to moles and add resulting vapor to Air
            % Producer Vapor store (assumed: 998.23g/L and 18.01524g/mol)
            molesOfWaterProduced = litersOfWaterProduced*998.23/18.01524;
            
            obj.Shelf.AirProducerDefinition.ResourceStore.VaporStore.add(molesOfWaterProduced);
            
        end
        
        %% calculateTimeTillCanopyClosure
        function timeTillCanopyClosure = calculateTimeTillCanopyClosure(obj)
            
            %% get average for list
            %                 obj.CanopyClosurePPFValues,obj.AveragePPF
            
            %                 totalReal = sum(obj.CanopyClosurePPFValues);
            %                 totalFiller = obj.AveragePPF*(obj.TimeTillCanopyClosure*24-length(obj.CanopyClosurePPFValues));
            %                 output = (totalFiller+totalReal)/(obj.TimeTillCanopyClosure*24);
            
            thePPF = (obj.AveragePPF*(obj.TimeTillCanopyClosure*24-length(obj.CanopyClosurePPFValues))+...
                sum(obj.CanopyClosurePPFValues))/(obj.TimeTillCanopyClosure*24)*...
                obj.Crop.Photoperiod/obj.Crop.NominalPhotoperiod;       % First part of this expression corresponds to teh output of AverageForList(myCanopyClosurePPFValues,AveragePPF)
            
            theCO2 = (obj.AverageCO2Concentration*(obj.TimeTillCanopyClosure*24-length(obj.CanopyClosureCO2Values))+...
                sum(obj.CanopyClosureCO2Values))/(obj.TimeTillCanopyClosure*24);
            
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
            
            timeTillCanopyClosure = round(tA);  % Final time until canopy closure is rounded (according to BioSim PlantImpl code)
            
        end
        
        %% calculateCQY (Canopy Quantum Yield)
        function cqy = calculateCQY(obj)
            % Calculate CQYmax
            thePPF = obj.AveragePPF;
            theCO2 = obj.AverageCO2Concentration;
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
            
            % Continue determining CQY
            %                 timeTillCanopySenescence = obj.Crop.TimeAtCanopySenescence;
            if obj.Age/24 < obj.Crop.TimeAtCanopySenescence
                cqy = CQYmax;
            else
                %                     CQYmin = obj.Crop.CQYMin;
                %                     daysOfGrowth = obj.Age/24;
                %                     timeTillCropMaturity = obj.Crop.TimeAtCropMaturity;
                calculatedCQY = CQYmax - (CQYmax-obj.Crop.CQYMin)*(obj.Age/24-obj.Crop.TimeAtCanopySenescence)/...
                    (obj.Crop.TimeAtCropMaturity-obj.Crop.TimeAtCanopySenescence);
                cqy = calculatedCQY*(calculatedCQY>=0);
            end
        end
        
        %% calculateWaterUptake
        function waterUptake = calculateWaterUptake(obj)
            dailyCanopyTranspirationRate = calculateDailyCanopyTranspirationRate(obj)*obj.Shelf.cropAreaUsed;     % NB. that obj.CropArea should correspond to ShelfImpl.CropAreaUsed
            
            % calculateWetIncorporatedWaterUptake
            CurrentInedibleWetBiomass = max(obj.CurrentTotalWetBiomass - obj.CurrentEdibleWetBiomass,0);
            LastInedibleWetBiomass = max(obj.LastTotalWetBiomass - obj.LastEdibleWetBiomass,0);
            wetIncorporatedWaterUptake = (obj.CurrentEdibleWetBiomass-obj.LastEdibleWetBiomass)*obj.Crop.EdibleFreshBasisWaterContent+...
                (CurrentInedibleWetBiomass-LastInedibleWetBiomass)*obj.Crop.InedibleFreshBasisWaterContent;
            
            % calculateDryIncorporatedWaterUptake
            dryIncorporatedWaterUptake = (dailyCanopyTranspirationRate+wetIncorporatedWaterUptake)/500;
            % Aggregate water uptake sources into a total waterUptake
            waterUptake = (dailyCanopyTranspirationRate/24)+wetIncorporatedWaterUptake+dryIncorporatedWaterUptake;
        end
        
        %% calculateDailyCanopyTranspirationRate
        function dailycanopytranspirationrate = calculateDailyCanopyTranspirationRate(obj)
            airPressure = obj.Shelf.AirProducerDefinition.ResourceStore.pressure;     % Pressure within air producer sink
            vaporPressureDeficit = calculateVaporPressureDeficit(obj);
            
            %% calculateCanopySurfaceConductance
            % calculateCanopyStomatalConductance
            if strcmpi(obj.Crop.Type,'Erectophile')
                % This section of the code is taken from the
                % BioSim Erectophile class file
                relativeHumidity = obj.Shelf.AirProducerDefinition.ResourceStore.RelativeHumidity;
                netCanopyPhotosynthesis = calculateNetCanopyPhotosynthesis(obj);
                canopyStomatalConductance = 0.1389 + 15.32*relativeHumidity*...
                    (netCanopyPhotosynthesis/obj.AverageCO2Concentration);
                
            else % (if planophile or legume)
                % calculateVaporPressureDeficit
                %                     vaporPressureDeficit = calculateVaporPressureDeficit(obj);
                netCanopyPhotosynthesis = calculateNetCanopyPhotosynthesis(obj);
                canopyStomatalConductance = (1.717*obj.Shelf.AirProducerDefinition.ResourceStore.temperature - 19.96 - 10.54*vaporPressureDeficit)*...
                    (netCanopyPhotosynthesis/obj.AverageCO2Concentration);
            end
            
            % calculateAtmosphericAeroDynamicConductance
            if strcmpi(obj.Crop.Type,'Erectophile')
                atmosphericAeroDynamicConductance = 5.5;
            else % (if planophile or legume)
                atmosphericAeroDynamicConductance = 2.5;
            end
            
            canopySurfaceConductance = (atmosphericAeroDynamicConductance * canopyStomatalConductance)...
                / (canopyStomatalConductance + atmosphericAeroDynamicConductance);
            % end calculateCanopyStomatalConductance
            dailycanopytranspirationrate = 3600*obj.Crop.Photoperiod*(18.015/998.23)*...
                canopySurfaceConductance*(vaporPressureDeficit/airPressure);
        end
        
        %% calculateVaporPressureDeficit
        function vaporPressureDeficit = calculateVaporPressureDeficit(obj)
            environmentalTemperature = obj.Shelf.AirProducerDefinition.ResourceStore.temperature;
            saturatedMoistureVaporPressure = 0.611*exp(17.4*environmentalTemperature/(environmentalTemperature+239));
            actualMoistureVaporPressure = obj.Shelf.AirProducerDefinition.ResourceStore.VaporPercentage...
                *obj.Shelf.AirProducerDefinition.ResourceStore.pressure;
            vaporPressureDeficit = saturatedMoistureVaporPressure - actualMoistureVaporPressure;
            vaporPressureDeficit = vaporPressureDeficit*(vaporPressureDeficit>=0);
        end
        
        
        %% calculateNetCanopyPhotosynthesis
        function netCanopyPhotosynthesis = calculateNetCanopyPhotosynthesis(obj)
            plantGrowthDiurnalCycle = 24;
            % calculateGrossCanopyPhotosynthesis
            grossCanopyPhotosynthesis = obj.AveragePPF * obj.CQY * obj.PPFFractionAbsorbed;
            photoperiod = obj.Crop.Photoperiod;
            netCanopyPhotosynthesis = ((plantGrowthDiurnalCycle-photoperiod)/plantGrowthDiurnalCycle + ...
                (photoperiod*obj.carbonUseEfficiency24)/plantGrowthDiurnalCycle)*grossCanopyPhotosynthesis;
        end
        
        %% Kill
        function kill(obj)
            obj.hasDied = 1;
            obj.Age = 0;        % Age of current crop group
            obj.canopyClosed = 0;
            obj.AveragePPF = 0;
            obj.myTotalPPF = 0;
            obj.myNumberOfPPFReadings = 0;
            obj.AverageWaterNeeded = 0;
            obj.TotalWaterNeeded = 0;
            obj.AverageCO2Concentration = 0;
            obj.TotalCO2Concentration = 0;
            obj.NumberOfCO2ConcentrationReadings = 0;
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
            obj.totalO2GramsProduced = 0;
            obj.totalCO2GramsConsumed = 0;
            obj.totalCO2MolesConsumed = 0;
            obj.totalWaterLitersTranspired = 0;
            obj.TimeTillCanopyClosure = 0;       % in days
            obj.PPFFractionAbsorbed = 0;
            obj.ProductionRate = 1;
            obj.MolesOfCO2Inhaled = 0;
        end
        
    end
    
end

