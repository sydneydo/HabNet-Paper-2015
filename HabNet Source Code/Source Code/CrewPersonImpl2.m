classdef CrewPersonImpl2 < handle
    %CrewPersonImpl Summary of this class goes here
    %   This class definition combines the BioSim CrewPersonImpl and
    %   BaseCrewPersonImpl class files

    properties
        Name
        Age
        Weight
        Gender
        Diet                            % Diet of CrewPerson, specified as % of each crop type eaten (wrt calories)
%         CrewGroup                       % Contains object representing the group that the crew person is a member of
        CurrentTick = 0                 % Current Tick
        Schedule                        % Array of ActivityImpl objects (currently assumes the same set of activities every day)
        TimeOnCurrentActivity = 1       % Time spent on current activity in hours
        CurrentActivity                 % Current activity being performed (this changes over time) [ActivityImpl
        
        % Consumer/Producer Definitions
%         AirConsumerDefinition = AirConsumerDefinitionImpl
%         AirProducerDefinition = AirProducerDefinitionImpl
%         PotableWaterConsumerDefinition = PotableWaterConsumerDefinitionImpl
%         DirtyWaterProducerDefinition = ResourceUseDefinitionImpl
%         GreyWaterProducerDefinition = ResourceUseDefinitionImpl
%         FoodConsumerDefinition = ResourceUseDefinitionImpl
%         DryWasteProducerDefinition = ResourceUseDefinitionImpl
        
        % Physiological Buffers to Measure Crew Wellbeing
        consumedWaterBuffer
        consumedCaloriesBuffer
        consumedCO2Buffer
        consumedLowOxygenBuffer
        highOxygenBuffer
        lowTotalPressureBuffer
        sleepBuffer
        leisureBuffer
    end
    
    properties (SetAccess = private)
        % Properties Corresponding to Crew Resource Production and
        % Consumption
        O2Consumed %
        CO2Produced %
        caloriesConsumed
        foodMassConsumed %
        potableWaterConsumed
        dirtyWaterProduced %
        dryWasteProduced %
        greyWaterProduced %
        O2Needed %
        O2Ratio
        CO2Ratio
        potableWaterNeeded %
        caloriesNeeded %
        vaporProduced %
        % Crew Poor Health States (Boolean values)
        thirsty = 0
        starving = 0
        suffocating = 0
        poisoned = 0
        totalpressureRisked = 0
        fireRisked = 0
        
        % Properties Corresponding to Physiological Buffers
        waterTillDead = 5.3
        waterRecoveryRate = 0.01
        calorieTillDead = 180000
        calorieRecoveryRate = 0.0001
        CO2HighLimit = 0.482633011      % CO2 partial pressure limit in kPa, converted from 0.07psia (According to Table 6.2-6, HIDH)
        CO2HighTillDead = 4
        CO2HighRecoveryRate = 0.005
        O2HighTillDead = 24             % hours exposed at high O2 levels (with fire risk) until dead
        O2HighRecoveryRate = 0.01
        O2LowPartialPressure = 15.168             % kPa, absolute minimum ppO2 that a person should be exposed to - REF- HIDH  pg 324, Table 6.2-5
        O2LowTillDead = 2               % Hours spent in a low O2 level until death occurs (corresponds to amount of internal buffer that the crew has)
        O2LowRecoveryRate = 0.01
        TotalPressureLowLimit = 20.6842719      % Corresponds to 3psi - the absolute lowest total pressure that a cabin can go to (REF: HIDH, pg 319, Table 6.2-3)
        TotalPressureLowTillDead = 1            % Hours spent in a low total pressure condition until death occurs
        leisureTillBurnout = 168        % in hours
        leisureRecoveryRate = 90
        awakeTillExhaustion = 120
        sleepRecoveryRate = 120         % hours of sleeplessness until crew death
        idealGasConstant = 8.314;        % J/K/mol
    end
    
    properties (SetAccess = private)
        % Flag for being alive
        alive = 1;
    end

    methods
        %% Constructor
        function obj = CrewPersonImpl2(name,age,weight,sex,schedule)
            
            obj.Name = name;
            obj.Age = age;
            obj.Weight = weight;
            if ~(strcmpi(sex,'Male') || strcmpi(sex,'Female'))
                error('CrewPersonImpl gender must be set to either "Male" or "Female"')
            end
            obj.Gender = sex;
            
            if nargin > 4
                % Add ID numbers to schedule
                for i = 1:length(schedule)
                    schedule(i).ID = i;
                end
                obj.Schedule = schedule;  
                obj.CurrentActivity = schedule(1);
                
            end
            
%             if nargin > 5
%                 obj.O2LowRatio = O2fractionHypoxicLimit;        % Change default value for O2fraction Hypoxic limit (in the future, we can implement an equation that takes the O2% from the AirConsumerDefinition to calculate this
%             end
                
            % Initialize Physiological Buffers
            obj.consumedWaterBuffer = StoreImpl('Consumed Water Buffer','Material',obj.waterTillDead,obj.waterTillDead);
            obj.consumedCaloriesBuffer = StoreImpl('Consumed Calories Buffer','Material',obj.calorieTillDead,obj.calorieTillDead);
            obj.consumedCO2Buffer = StoreImpl('Consumed CO2 Buffer','Material',obj.CO2HighTillDead*obj.CO2HighLimit...
                ,obj.CO2HighTillDead*obj.CO2HighLimit);
            obj.consumedLowOxygenBuffer = StoreImpl('Consumed Low O2 Buffer','Material',obj.O2LowTillDead,obj.O2LowTillDead);
            obj.highOxygenBuffer = StoreImpl('High O2 Buffer','Material',obj.O2HighTillDead,obj.O2HighTillDead);
            obj.lowTotalPressureBuffer = StoreImpl('Low Total Pressure Buffer','Material',obj.TotalPressureLowTillDead,obj.TotalPressureLowTillDead);
            obj.sleepBuffer = StoreImpl('Sleep Buffer','Material',obj.awakeTillExhaustion,obj.awakeTillExhaustion);
            obj.leisureBuffer = StoreImpl('Leisure Buffer','Material',obj.leisureTillBurnout,obj.leisureTillBurnout);
        end
        
        %% addSchedule
        function addSchedule(obj,schedule)
            % Enforce crewperson to be of class ActivityImpl
            if ~(strcmpi(class(schedule),'ActivityImpl'))
                error('Input must be of type ActivityImpl')
            end
            
            % If obj.schedule is currently empty           
            if isempty(obj.Schedule)
                % Assign ID numbers to schedule objects
                for i = 1:length(schedule)
                    schedule(i).ID = i;
                end
                obj.Schedule = schedule;
                obj.CurrentActivity = schedule(1);      % Initialize CurrentActivity to first activity in schedule
            % Else if there are elements currently within obj.schedule,
            % update ID numbers
            else
                for i = 1:length(schedule)
                    schedule(i).ID = length(obj.Schedule)+i;
                end
                obj.Schedule = [obj.Schedule,schedule];
            end
        end
        
        %% Tick
        % ticks crew member
        % each tick, a crewmember performs activities, which influences
        % their consumption and production patterns
        % consumption involves
        
        % from original BioSim code (BasePersonCrewImpl):
        % 	 * When the CrewGroup ticks the crew member, the member: 1) increases the
        % 	 * time the activity has been performed by 1. (advanceActivity) on the condition that the crew
        % 	 * memeber isn't dead he/she then:. 2) attempts to collect references to
        % 	 * various server (if not already done). 3) possibly advances to the next
        % 	 * activity. 4) consumes air/food/water, exhales and excretes. 5) takes
        % 	 * afflictions from lack of any resources (consumeAndProduceResources). 6) checks whether afflictions (if
        % 	 * any) are fatal.
        
        function obj = tick(obj)
            if obj.alive == 0
                return
            end
            obj.CurrentTick = obj.CurrentTick + 1;      % Update current tick
            advanceActivity(obj);  % Advanced either time spent on activity, or the activity itself
            consumeAndProduceResources(obj);
            afflictCrew(obj);
            healthCheck(obj);    % Check health status of crew - crew is killed here if a health check is failed
            recoverCrew(obj);
            
        end
        
        %% advanceActivity
        % Function to either move time spent on activity forward by one tick, or to switch activities
        function advanceActivity(obj) 
            % If time on current activity > duration of current activity,
            % switch to next activity and reset TimeOnCurrentActivity
            if obj.TimeOnCurrentActivity >= obj.CurrentActivity.Duration
                nextindex = obj.CurrentActivity.ID+1;
                % Cycle to beginning of schedule is reached past last
                % activity
                if nextindex > length(obj.Schedule)
                    nextindex = 1;
                end
                obj.CurrentActivity = obj.Schedule(nextindex);
                obj.TimeOnCurrentActivity = 1;
            else
                obj.TimeOnCurrentActivity = obj.TimeOnCurrentActivity+1;
            end
        end
        
        %% skipActivity
        % Function to skip to next activity
        function skipActivity(obj)
            nextindex = obj.CurrentActivity.ID+1;
            % Cycle to beginning of schedule is reached past last
            % activity
            if nextindex > length(obj.Schedule)
                nextindex = 1;
            end
            obj.CurrentActivity = obj.Schedule(nextindex);
            obj.TimeOnCurrentActivity = 1;
        end
        
        %% Consumes and Produced Resources for this tick
        function consumeAndProduceResources(obj)
            %% Resource consumption requirements
            % TO DO: insert if statement to enforce currentActivity to be of type
            % ActivityImpl
%             currentActivityIntensity = obj.CurrentActivity.Intensity;

            % Don't breathe if on EVA (we account for breathing separately
            if ~strcmpi(obj.CurrentActivity.Name,'EVA')
            % O2
            obj.O2Needed = calculateO2Needed(obj);
            obj.O2Consumed = obj.CurrentActivity.Location.O2Store.take(obj.O2Needed);
             % CO2
            obj.CO2Produced = obj.calculateCO2Produced(obj.O2Consumed);
            obj.CurrentActivity.Location.CO2Store.add(obj.CO2Produced);                   % Add CO2 to current SimEnvironment
            end
            % Food
            obj.caloriesNeeded = calculateFoodNeeded(obj);
            foodConsumed = getCaloriesFromStore(obj,obj.caloriesNeeded);    % Outputs Food Items Consumed during this tick - this takes food from the foodstore
            % Calculate total food mass and food water content consumed this tick            
            obj.foodMassConsumed = sum([foodConsumed.Mass]);
            obj.caloriesConsumed = sum([foodConsumed.CaloricContent]);
            foodWaterConsumed = sum([foodConsumed.WaterContent]);
            
            % Potable Water
            potableWaterRequired = calculateCleanWaterNeeded(obj);                                                  % Total potable water required by crew person
            obj.potableWaterNeeded = potableWaterRequired-foodWaterConsumed;                                      % Calculate potable water needed to be drunk (accounting for water already taken from food store)
            obj.potableWaterConsumed = obj.CurrentActivity.Location.PotableWaterStore.take(obj.potableWaterNeeded);  % Take potableWaterNeeded to be drunk from potable water store 
            % Vapor
            obj.vaporProduced = obj.calculateVaporProduced(potableWaterRequired);                                       % Calculate vapor produced as a function of potable water consumed
            obj.CurrentActivity.Location.VaporStore.add(obj.vaporProduced);                                                               % Send Vapor Produced to SimEnvironment
            % Dirty Water
            obj.dirtyWaterProduced = obj.calculateDirtyWaterProduced(potableWaterRequired);
            obj.CurrentActivity.Location.DirtyWaterStore.add(obj.dirtyWaterProduced);  % Add dirtyWaterProduced from to Dirty Water store
            % Grey Water
            obj.greyWaterProduced = obj.calculateGreyWaterProduced(potableWaterRequired);
            obj.CurrentActivity.Location.GreyWaterStore.add(obj.greyWaterProduced);  % Add greyWaterProduced from to Grey Water store
            % Dry Waste
            obj.dryWasteProduced = obj.calculateDryWasteProduced(obj.foodMassConsumed);
            obj.CurrentActivity.Location.DryWasteStore.add(obj.dryWasteProduced);  % Add dryWasteProduced from to Dry Waste store
            
        end

        %% Function to gather foodItems from stores within
        % FoodConsumerDefinition
        function foodConsumed = getCaloriesFromStore(obj,caloriesNeeded)
%             gatheredFoodMatterArrays = [];
            currentTotalFoodItems = 0;
            for j = 1:length(obj.CurrentActivity.Location.FoodStore)
                currentTotalFoodItems = currentTotalFoodItems+length(obj.CurrentActivity.Location.FoodStore(j).foodItems);
            end

%             gatheredFoodMatterArrays = FoodMatter.empty(0,length(obj.CurrentActivity.Location.FoodStore));
            gatheredFoodMatterArrays = FoodMatter.empty(0,currentTotalFoodItems);
            count = 1;
            gatheredCalories = 0;
           
            % Order food stores by preference from which food is first
            % taken - if not enough calories available in first store, the
            % crew moves to the next store to look for food to consume
%             for i = 1:length(obj.FoodConsumerDefinition.ResourceStore) % corresponds to vector of FoodConsumerDefinition
            for i = 1:length(obj.CurrentActivity.Location.FoodStore)    % Cycle through food stores within current environment
                
                if ~isempty(obj.CurrentActivity.Location.FoodStore(i).foodItems)
                    
                    for j = 1:length(obj.CurrentActivity.Location.FoodStore(i).foodItems)
                        
                        if gatheredCalories < caloriesNeeded
                            
                            %                     limitingMassFactor = min(obj.FoodConsumerDefinition.MaxFlowRate,...
                            %                         obj.FoodConsumerDefinition.DesiredFlowRate);    % from FoodConsumerDefinitionImpl.getCaloriesFromStore, referred to in CrewPersonImpl.eatFood()
                            
                            %                     takenMatter = obj.FoodConsumerDefinition.ResourceStore(i)...
                            %                         .takeFoodMatterCalories(caloriesNeeded,limitingMassFactor); % from FoodStoreImpl.takeFoodMatterCalories, outputs food taken from FoodStoreImpl
                            
                            takenMatter = obj.CurrentActivity.Location.FoodStore(i)...
                                .takeFoodMatterCalories(caloriesNeeded-gatheredCalories);
                            
                            %                     gatheredFoodMatterArrays = [gatheredFoodMatterArrays takenMatter];
                            if ~isempty(takenMatter)
                                gatheredFoodMatterArrays(count:(count-1+length(takenMatter))) = takenMatter;
                                count = count+length(takenMatter);
                            end
                            
                            %                     for j = 1:length(takenMatter)
                            %                         gatheredCalories = gatheredCalories + takenMatter(j).CaloricContent;
                            %                     end
                            gatheredCalories = gatheredCalories + sum([takenMatter.CaloricContent]);
                        end
                        % Break out of for loop if we have enough calories
                        if gatheredCalories >= caloriesNeeded
                            break
                        end
                    end
                end
                
                if gatheredCalories >= caloriesNeeded
                    break
                end
                
            end
            foodConsumed = gatheredFoodMatterArrays; 
        end

        %% Calculate O2Needed in L/hr (according to "Top Level Modeling of
        % Crew Component of ALSS" by Goudarzi & Ting, SAE 1999-01-2042)
        function O2needed = calculateO2Needed(obj)
            currentActivityIntensity = obj.CurrentActivity.Intensity;
            if currentActivityIntensity < 0
                O2needed = 0;
            else
                heartRate = currentActivityIntensity*30 + 15;   % later, implement more accurate model based on paper
                a = 0.223804;
                b = 5.64E-7;
                resultinLiters = (a + b*heartRate^3) * 60;  %in L/hr    Correct version
%                 resultinLiters = a + b*heartRate^3 * 60;  %in L/hr    INCORRECT version currently implemented within BioSim
%                 molarVolume = 22.4;        % in L/mol of air - value based from: http://en.wikipedia.org/wiki/Molar_volume
                %% TO DO: implement more accurate version of this based on partial pressures within SimEnvironment
%                 resultinMoles = resultinLiters / molarVolume;  % this is  the number of moles of O2 required per hour
                
                O2needed = resultinLiters*obj.CurrentActivity.Location.pressure*...
                    obj.CurrentActivity.Location.O2Percentage/...
                    (obj.idealGasConstant*(obj.CurrentActivity.Location.temperature+273.15));   % O2 needed in moles
                
%                 O2needed = resultinMoles;
            end
        end
                
        %% Calculate potableWaterNeeded in L/hr 
        % NB. BioSim assumes this to be fixed at 0.1667L/hr regardless of
        % the activity intensity level
        function potableWaterNeeded = calculateCleanWaterNeeded(obj)
            potableWaterNeeded = 0.1667*(obj.CurrentActivity.Intensity >= 0);
        end
        
        %% Calculate Food Needed in Calories/hr (actually kcal)
        % is a function of activity intensity and is derived from the model
        % decribed in "Top Level Modeling of Crew Component of ALSS" by
        % Goudarzi & Ting, SAE 1999-01-2042
        function caloriesNeeded = calculateFoodNeeded(obj)
            if obj.CurrentActivity.Intensity < 0
                caloriesNeeded = 0;
            else
                activityCoefficient = 0.5*(obj.CurrentActivity.Intensity-1)+1;  % corresponds to activity factor within paper (scales the value to the appropriate range)
                
                % Calculate kilojoules needed per person per day based on
                % gender and age
                if strcmpi(obj.Gender,'Male') % if male
                    if obj.Age < 30 % if male and less than 30 years of age
                        % SAE 1999-01-2042 Equation
                        kJneeded = 106*obj.Weight + 5040*activityCoefficient;
                        
%                         % BVAD Equation
%                         kJneeded = 1.7*(64.02*obj.Weight + 2841);
                        
                    else % if male and above 30 years of age
                        kJneeded = 86*obj.Weight + 5990*activityCoefficient;
                    end
                else % if female
                    if obj.Age < 30 % if female and less than 30 years of age
%                         kJneeded = 106*obj.Weight + 3200*activityCoefficient;   % Incorrect version of equation used in BioSim
                        kJneeded = 100*obj.Weight + 3200*activityCoefficient;   % Correct version from SAE paper
                    else % if female and above 30 years of age
%                         kJneeded = 106*obj.Weight + 6067*activityCoefficient;   % Incorrect version of equation used in BioSim
                        kJneeded = 50*obj.Weight + 6066.7*activityCoefficient;	% Correct version from SAE paper
                    end
                end
                caloriesNeeded = kJneeded/24/4.184;   % Convert from kJ/person/day to calories/person/hour (a more accurate conversion factor would be 4.184) (actually this should be in kcal)
            end          
           
        end
            
        %% AfflictCrew
        % Function to damage the crewmember if not all required resources
        % are consumed
        function obj = afflictCrew(obj)
            obj.sleepBuffer.take(1);        % take one hour away from crew sleepBuffer (shouldn't it be if they are awake?)
            obj.leisureBuffer.take(1);      % take one hour away from crew leisureBuffer (shouldn't it be if they are working?)
            
            % Starving Check
            obj.consumedCaloriesBuffer.take(obj.caloriesNeeded - obj.caloriesConsumed);     % Take calorie deficit from CalorieBuffer (or add Calorie profit to CalorieBuffer)
            % If calorie deficit is > 100 (per tick), set status of 
            % crewperson to starving
%             if (obj.caloriesNeeded - obj.caloriesConsumed) > 100
%                 obj.starving = 1;
%                 disp([obj.Name,' is starving with a caloric deficit of: ',...
%                     num2str(obj.caloriesNeeded - obj.caloriesConsumed)]);
%             else
%                 obj.starving = 0;
%             end
            obj.starving = ((obj.caloriesNeeded - obj.caloriesConsumed) > 100);
            if obj.starving == 1
                disp([obj.Name,' is currently starving on tick: ', num2str(obj.CurrentTick)])
            end
            
            % Thirsty Check
            obj.consumedWaterBuffer.take(obj.potableWaterNeeded - obj.potableWaterConsumed);    % Take potable water deficit from consumedWaterBuffer (or add potable water profit to consumedWaterBuffer)
            obj.thirsty = (obj.potableWaterNeeded - obj.potableWaterConsumed) > 0;
            if obj.thirsty == 1
                disp([obj.Name,' is currently dehydrated on tick: ', num2str(obj.CurrentTick)])
            end            
            
            % Inhaled O2 Ratio (hypoxia check)
            if ~strcmpi(obj.CurrentActivity.Name,'EVA')
                currentPPO2 = obj.CurrentActivity.Location.O2Percentage*obj.CurrentActivity.Location.pressure;
                if currentPPO2 < obj.O2LowPartialPressure
                    obj.consumedLowOxygenBuffer.take(1);%obj.O2LowRatio-currentO2Ratio);    % Take an hour of survival time away from crewperson
                    obj.suffocating = 1;
                    disp([obj.Name,' is currently suffocating on tick: ', num2str(obj.CurrentTick),' in module: ',obj.CurrentActivity.Location.name])
                else
                    obj.suffocating = 0;
                end
%             end
            
            % Fire Hazard and Hyperoxia Check (only check when crew is not
            % on EVA)
%             if ~strcmpi(obj.CurrentActivity.Name,'EVA')   % this if
%             condition is always here
                if obj.CurrentActivity.Location.O2Percentage > obj.CurrentActivity.Location.DangerousOxygenThreshold
                    obj.highOxygenBuffer.take(1);%currentO2Ratio-...        % Take one hour away from buffer
                    %                     obj.AirConsumerDefinition.ConsumptionStore.DangerousOxygenThreshold);       % Remove time in hyperoxic state from buffer
                    obj.fireRisked = 1;
                    disp([obj.Name,' is currently in a fire risked state on tick: ', num2str(obj.CurrentTick),' in module: ',obj.CurrentActivity.Location.name])
                else
                    obj.fireRisked = 0;
                end
%             end
            
            % Total Pressure Check
%             if ~strcmpi(obj.CurrentActivity.Name,'EVA')
                if obj.CurrentActivity.Location.pressure < obj.TotalPressureLowLimit
                    obj.lowTotalPressureBuffer.take(1); % Take one hour away from buffer
                    obj.totalpressureRisked = 1;
                    disp([obj.Name,' is currently in a low total ambient pressure risked state on tick: ', num2str(obj.CurrentTick),' in module: ',obj.CurrentActivity.Location.name])
                else
                    obj.totalpressureRisked = 0;
                end
%             end
            
            % CO2 Poisoning Check
%             if ~strcmpi(obj.CurrentActivity.Name,'EVA')
                currentPPCO2 = obj.CurrentActivity.Location.pressure*obj.CurrentActivity.Location.CO2Percentage;
                if currentPPCO2 > obj.CO2HighLimit
                    obj.consumedCO2Buffer.take(currentPPCO2 - obj.CO2HighLimit);
                    obj.poisoned = 1;
                    disp([obj.Name,' is currently experiencing CO2 poisoning on tick: ', num2str(obj.CurrentTick),' in module: ',obj.CurrentActivity.Location.name])
                else
                    obj.poisoned = 0;
                end
%             % Alternative faster code
%             obj.consumedCO2Buffer.take((currentCO2Ratio > obj.CO2HighRatio)*(currentCO2Ratio - obj.CO2HighRatio));
%             obj.poisoned = (currentCO2Ratio > obj.CO2HighRatio);
            end
        end

        %% HealthCheck
        function healthCheck(obj)
            randomNumber = rand(1);     % Random number generated to test for crew death, based on risk value generated using the calculateRisk function
            
            % Determine current risk values for each death possibility
            calorieRiskReturn = obj.calculateRisk(obj.consumedCaloriesBuffer);
            waterRiskReturn = obj.calculateRisk(obj.consumedWaterBuffer);
            oxygenLowRiskReturn = obj.calculateRisk(obj.consumedLowOxygenBuffer);
            oxygenHighRiskReturn = obj.calculateRisk(obj.highOxygenBuffer);
            totalpressureLowRiskReturn = obj.calculateRisk(obj.lowTotalPressureBuffer);
            CO2RiskReturn = obj.calculateRisk(obj.consumedCO2Buffer);
%             sleepRiskReturn = obj.calculateRisk(obj.sleepBuffer);
            
            % Check for risk due to starvation
            if calorieRiskReturn > randomNumber
                disp([obj.Name,' has died from starvation on tick: ', num2str(obj.CurrentTick),...
                    ' with a risk value of: ', num2str(calorieRiskReturn)])
                kill(obj)
            % Check for risk due to dehydration
            elseif waterRiskReturn > randomNumber
                disp([obj.Name,' has died from dehydration on tick: ', num2str(obj.CurrentTick),...
                    ' with a risk value of: ', num2str(waterRiskReturn)])
                kill(obj)
            % Check for risk due to hypoxia
            elseif oxygenLowRiskReturn > randomNumber
                disp([obj.Name,' has died from lack of oxygen (hypoxia) on tick: ', num2str(obj.CurrentTick),...
                    ' with a risk value of: ', num2str(oxygenLowRiskReturn)])
                kill(obj)
            % Check for risk due to hyperoxia
            elseif oxygenHighRiskReturn > randomNumber
                disp([obj.Name,' has died from oxygen flammability on tick: ', num2str(obj.CurrentTick),...
                    ' with a risk value of: ', num2str(oxygenHighRiskReturn)])
                kill(obj)
            % Check for risk due to low total ambient pressure
            elseif totalpressureLowRiskReturn > randomNumber
                disp([obj.Name,' has died from low total ambient pressure exposure on tick: ', num2str(obj.CurrentTick),...
                    ' with a risk value of: ', num2str(totalpressureLowRiskReturn)])
                kill(obj)
            % Check for risk due to CO2 poisoning
            elseif CO2RiskReturn > randomNumber
                disp([obj.Name,' has died from CO2 poisoning on tick: ', num2str(obj.CurrentTick),...
                    ' with a risk value of: ', num2str(CO2RiskReturn)])
                kill(obj)
            % Check for risk due to sleep deprivation (TO DO: correlate
            % this with crew activities)
%             elseif sleepRiskReturn > randomNumber
%                 kill(obj)
%                 disp([obj.Name,' has died from sleep deprivation on tick: ', num2str(obj.CurrentTick),...
%                     ' with a risk value of: ', num2str(sleepRiskReturn)])
            end
        end
        
        %% Kill CrewPerson
        % Method to kill CrewPerson if they have failed one of their
        % healthCheck criteria
        function kill(obj)
            disp([obj.Name,' has been killed'])
            obj.alive = 0;
            obj.O2Consumed = 0;
            obj.CO2Produced = 0;
            obj.caloriesConsumed = 0;
            obj.potableWaterConsumed = 0;
            obj.dirtyWaterProduced = 0;
            obj.dryWasteProduced = 0;
            obj.greyWaterProduced = 0;
        end
        
        %% Recover CrewPerson
        % This method increases the level within the CrewPerson's
        % physiological buffers each time step by a fraction of its
        % capacity. This represents the human body's self repair
        % mechanism
        
        % Modification on 9/2/2014
        % We only repair if enough resources were supplied for the given
        % tick - it makes no sense to repair if the crewperson is still
        % receiving insufficient resources
        function recoverCrew(obj)
            if obj.alive == 0
                return
            end
            % Recover consumedCaloriesBuffer only if caloriesConsumed >=
            % caloriesNeeded
            obj.consumedCaloriesBuffer.add((obj.caloriesConsumed>=obj.caloriesNeeded)*obj.calorieRecoveryRate*obj.consumedCaloriesBuffer.currentCapacity);
            % Recover consumedWaterBuffer only if potableWaterConsumed >=
            % potableWaterNeeded
            obj.consumedWaterBuffer.add((obj.potableWaterConsumed>=obj.potableWaterNeeded)*obj.waterRecoveryRate*obj.consumedWaterBuffer.currentCapacity);
            % Recover consumedLowOxygenBuffer only if atmospheric ppO2 is
            % above low ppO2 threshold
            obj.consumedLowOxygenBuffer.add(((obj.CurrentActivity.Location.O2Percentage*obj.CurrentActivity.Location.pressure)>obj.O2LowPartialPressure)*...
                obj.O2LowRecoveryRate*obj.consumedLowOxygenBuffer.currentCapacity);
            % Recover consumedCO2Buffer only if current ppCO2 is < high ppCO2 threshold 
            obj.consumedCO2Buffer.add(((obj.CurrentActivity.Location.pressure*obj.CurrentActivity.Location.CO2Percentage)<obj.CO2HighLimit)*...
                obj.CO2HighRecoveryRate*obj.consumedCO2Buffer.currentCapacity);
        end
    end
    
    %% Static Methods
    methods (Static) %Static method because it doesn't depend on an object (instance of the class)
        %% Calculate CO2 produced based on O2 needed (respiratory quotient)
        function CO2produced = calculateCO2Produced(O2Consumed)
            RQ = 0.86;  % Respiratory Quotient
            CO2produced = O2Consumed*RQ;
        end
        
        %% Calculate Vapor Produced in L/hr
        % BioSim assumes that vapor produced is always at 17.5% of the
        % potable water consumed (which is fixed at 0.1667L/hr)
        function vaporProduced = calculateVaporProduced(potableWaterConsumed)
            waterLitersToMolesConversion = 1000/18.01524;   % 1000g/Liter, 18.01524g/mole
            vaporProduced = 0.175*potableWaterConsumed*waterLitersToMolesConversion;
        end
        
        %% Calculate Dirty Water Produced in L/hr
        % BioSim assumes that dirty water (corresponds to urine) produced is always at 36.25% of the
        % potable water consumed (which is fixed at 0.1667L/hr)
        % This is the value recorded in SAE 1999-01-2042
        function dirtyWaterProduced = calculateDirtyWaterProduced(potableWaterConsumed)
            dirtyWaterProduced = 0.3625*potableWaterConsumed;
        end
        
        %% Calculate Grey Water Produced in L/hr
        % BioSim assumes that grey water produced is always at 53.75% of the
        % potable water consumed (which is fixed at 0.1667L/hr)
        function greyWaterProduced = calculateGreyWaterProduced(potableWaterConsumed)
            greyWaterProduced = 0.5375*potableWaterConsumed;
        end
        
        %% Calculate Dry Water Produced in kg/hr
        % BioSim assumes that dry waste produced is always at 2.2% of the
        % food mass consumed
        function dryWasteProduced = calculateDryWasteProduced(foodMassConsumed)
            dryWasteProduced = 0.022*foodMassConsumed;
        end
        
        %% CalculateRisk
        % Function that calculates risk of death for a particular risk
        % factor given a fullness level of the corresponding SimpleBuffer
        % Here, risk is calculated from the positive segment of a sigmoid
        % function (which corresponds to the cdf of a logistic pdf)
        % This sigmoid function is calibrated such that in the nominal case
        % (where the SimpleBuffer is full), the risk of death is 1 in 10^6
        function risk = calculateRisk(SimpleBuffer)
            % Check to ensure that input is of type StoreImpl
            if ~(strcmpi(class(SimpleBuffer),'StoreImpl'))
                error('Input must be of type StoreImpl')
            end
            percentagefull = SimpleBuffer.currentLevel/SimpleBuffer.currentCapacity;
            risk = 1/(1+10^(6*percentagefull));
        end
    end
    
end

