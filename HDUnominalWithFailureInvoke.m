%%  Habitation Development Unit / Human Exploration Research Analog Default Simulation Case
%   By: Sydney Do (sydneydo@mit.edu)
%   Date Created: 2/7/2015
%   Last Updated: 4/18/2015
%
%   Simulation Notes: 
%   Code to model baseline architecture for the ICES2015 paper entitled:
%   Benefits of In-Situ Manufacturing for Mars Exploration
%   This simulation models four crew inhabitating the HDU for 26 months
%   (one Martian synodic period). The desired output is the rate of
%   resupply required over time, as well as the survival time of the crew
%   when a failure of a particular system occurs
%
%   UPDATE 4/18/2015
%   Added pressure balancer code and restructured time loop to accomodate
%   this code
%
%   UPDATE 2/23/2015
%   - Turned off fan between suitlock and lab to prevent air exchange
%   - Modified code so that Suitlock PCA and CCAA were only operated when
%   no crew were on EVA
%
%   UPDATE 2/21/2015
%   - Code added to invoke a failure at a desired time within the
%   simulation time horizon
%
%   UPDATE 12/21/2014
%   - Corrected plant model code (ShelfImpl3.m - updated 12/20/2014) incorporated
%   - Updated plant growth profile incorporated (calculated 12/21/2014 - see Modified
%   Energy Cascade Low CO2 Correction.docx for details)
%
%   
%%  Simulation Notes
%   Time Horizon: 26 months (time between resupply) (approx. 19000 hours)
%   calculated from 2*365*24 + 2*31*24 (ie. 2 years + 2 months)
%   Crew Size: 4 persons
%   
%   Minimum-Pressure Atmosphere: 52.4kPa, 32% O2
%   (Corresponds to EAWG Recommendation for Mars Habitats)
%
%% CODE
clear all
clc
% close all

tic

%% Key Mission Parameters
missionDurationInHours = 19000;%19000;
numberOfEVAdaysPerWeek = 5;
numberOfCrew = 4;
missionDurationInWeeks = ceil(missionDurationInHours/24/7);

TotalAtmPressureTargeted = 55;      % EAWG recommended atmosphere for Mars surface habitats 70.3;        % targeted total atmospheric pressure, in kPa
O2FractionHypoxicLimit = 0.305;     % lower bound for a 55kPa atm based on EAWG Fig 4.1.1 and Advanced Life Support Requirements Document Fig 4-3
TargetO2MolarFraction = 0.32; 
o2fireRiskMolarFraction = 0.6;      % overwrite default value of 0.3 since target O2 fraction is 0.32. We set to 0.6 as this corresponds roughly to the hyperoxia limit for a 55kPA atmosphere (REF: Fig 6.2-2 HIDH)
idealGasConstant = 8.314;           % J/K/mol

% TotalPPO2Targeted = TargetO2MolarFraction*TotalAtmPressureTargeted;               % targeted O2 partial pressure, in kPa (converted from 26.5% O2)

%% Invoke One-At-A-Time Failure at Given Tick
FailureTick = 1;

ErrorList = {'LabPCA','LoftPCA','PCMPCA','SuitlockPCA','PLMPPRV',...
    'LabCCAA','LoftCCAA','PCMCCAA','SuitlockCCAA','mainvccr','ogs',...
    'crs.CompressorError','crs.ReactorError','crs.SeparatorError',...
    'waterRS.WPAerror','waterRS.UPAerror','Lab2PCMFan','PLM2PCMFan',...
    'Loft2PCMFan','Lab2AirlockFan'};

SystemToFail = [];%1:5;%[1,12,5,14];

% Determine failure command based on type of technology

FailCommand = cell(1,length(SystemToFail));
failcount = 0;
for j = 1:length(SystemToFail)
    if SystemToFail(j) == 12 || SystemToFail(j) == 13 || ...
            SystemToFail(j) == 14 || SystemToFail(j) == 15 || ...
            SystemToFail(j) == 16
        FailCommand{j} = [ErrorList{SystemToFail(j)},'=1;'];
    else
        FailCommand{j} = [ErrorList{SystemToFail(j)},'.Error=1;'];
    end
end

%% ISRU Production Rates
isruAddedWater = 0;      % Liters/hour
isruAddedCropWater = 0;  % Liter/hour
isruAddedO2 = 0;            % moles/hour
isruAddedN2 = 0;          % moles/hour

%% EMU
EMUco2RemovalTechnology = 'RCA';  % options are RCA or METOX
EMUurineManagementTechnology = 'UCTA';  % options are MAG or UCTA

%% Initialize Stores
% Potable Water Store within Life Support Units (note water store capacity
% measured in liters)

initialWaterLevel = 2960; %1500
PotableWaterStore = StoreImpl('Potable H2O','Material',initialWaterLevel,initialWaterLevel);      % Assume 1500L of water initially - note that ATV transports 840L of water while HTV carries 600L in 14 CWC-Is
% PotableWaterStore = StoreImpl('Potable H2O','Material',56.7,56.7);      %
% WPA Product Water tank has a capacity of 56.7L (ref: SAE 2008-01-2007).
% Note that on ISS, the WPA Product Water Tank feeds the Potable Water
% Dispenser, the OGA, and the WHC flush and hygiene hose.

% O2 Store within Life Support Units (note O2 capacity measured in moles)
initialO2TankCapacityInKg = 670; %3*91; %120; %100.2;  % Corresponds to three O2 tanks currently located on exterior of Quest airlock (REF: ISS ECLSS Status 2010-11)
o2MolarMass = 2*15.999; % g/mol
initialO2StoreMoles = initialO2TankCapacityInKg*1E3/o2MolarMass;
O2Store = StoreImpl('O2 Store','Material',initialO2StoreMoles,initialO2StoreMoles);

% Dirty water corresponds to Humidity Condensate and Urine 
DirtyWaterStore = StoreImpl('Dirty H2O','Material',18/2.2*1.1,0);        % Corresponds to the UPA waste water tank - 18lb capacity (we increase volume by 10% to avoid loss of dirty water when running UPA in batch mode)

% Grey water corresponds to wash water - it is included for the purposes of
% modeling a biological water processor
GreyWaterStore = StoreImpl('Grey H2O','Material',100/2.2,0);
% Note that WPA waste water tank has a 100lb capacity, but is nominally
% operated at 65lb capacity
% Lab Condensate tank has a working capacity of 45.5L

% Gas Stores

H2Store = StoreImpl('H2 Store','Material',10000,0);     % H2 store for output of OGS - note that currently on the ISS, there is no H2 store, it is sent directly to the Sabatier reactor 
% CO2Store = StoreImpl('CO2 Store','Material',1000,0);    % CO2 store for VCCR - refer to accumulator attached to CDRA

% From: "Analyses of the Integration of Carbon Dioxide Removal Assembly, Compressor, Accumulator 
% and Sabatier Carbon Dioxide Reduction Assembly" SAE 2004-01-2496
% "CO2 accumulator � The accumulator volume was set at 0.7 ft3, based on an assessment of available 
% space within the OGA rack where the CRA will reside. Mass balance of CO2 pumped in from the 
% compressor and CO2 fed to the Sabatier CO2 reduction system is used to calculate the CO2 pressure. 
% Currently the operating pressure has been set to 20 � 130 psia."

% From SAE 2004-01-2496, on CDRA bed heaters - informs temp of CO2 sent to
% accumulator
% "During the first 10 min of the heat cycle, ullage air is pumped out back to the cabin. After this time, the bed is
% heated to approximately 250 �F and is exposed to space vacuum for desorption of the bed."
% ...
% "The heaters were OFF during the �night time�, or when the desorb bed temperature reached its set point
% of 400 �F, or when it was an adsorb cycle."

% (Ref: Functional Performance of an Enabling Atmosphere Revitalization Subsystem Architecture for Deep Space Exploration Missions (AIAA 2013-3421)
% Quote: �Because the commercial compressor discharge pressure was 414 kPa compared to the flight CO2 Reduction Assembly (CRA)
% compressor�s 827 kPa, the accumulator volume was increased from 19.8 liters to 48.1 liters�

% CO2StoreTemp = 5/9*(400-32)+273.15;        % Converted to Kelvin from 400F, here we assume isothermal compression by the compressor
% CO2accumulatorVolumeInLiters = 19.8;
% CO2AccumulatorMaxPressureInKPa = 827;                  % note that 827kPa corresponds to ~120psi
% molesInCO2Store = CO2AccumulatorMaxPressureInKPa*CO2accumulatorVolumeInLiters/8.314/CO2StoreTemp;
CO2Store = StoreImpl('CO2 Store','Environmental');    % CO2 store for VCCR - refer to accumulator attached to CDRA (volume of 19.8L) - convert this to moles! - tank pressure is 827kPa (see spreadsheet)
MethaneStore = StoreImpl('CH4 Store','Environmental');    % CH4 store for output of CRS (Sabatier) - note CH4 is currently vented directly to space on ISS
% Look at option of including a pyrolyzer?

% N2 Store
% Corresponds to 2x high pressure N2 tanks currently mounted on exterior of Quest airlock on ISS (each holds 91kg of N2)
% This is subject to change based on requirements
numberOfN2Tanks = 2;% Corresponds to the number of N2 tanks on ISS
initialN2TankCapacityInKg = 38; %numberOfN2Tanks*91;
n2MolarMass = 2*14.007; %g/mol;
initialN2StoreMoles = initialN2TankCapacityInKg*1E3/n2MolarMass;
% initialN2StoreMoles = 1260;
N2Store = StoreImpl('N2 Store','Material',initialN2StoreMoles,initialN2StoreMoles);     

% Power Stores
MainPowerStore = StoreImpl('Power','Material',1000000,1000000);

% Waste Stores
DryWasteStore = StoreImpl('Dry Waste','Material',1000000,0);    % Currently waste is discarded via logistics resupply vehicles on ISS

%% Food Stores
% carry along 120days worth of calories - initial simulations show an
% average crew metabolic rate of 3040.1 Calories/day
% Note that 120 days is equivalent to the longest growth cycle of all the
% plants grown
CarriedFood = Wheat;
AvgCaloriesPerCrewPerson = 3040.1;
StockedDaysOfFood = ceil(19000/24)+14; % Days worth of food to carry - we initially assume that all food is carried along + 14 days buffer
CarriedCalories = numberOfCrew*AvgCaloriesPerCrewPerson*StockedDaysOfFood;    % one synodic period's worth of calories
CarriedTotalMass = CarriedCalories/CarriedFood.CaloriesPerKilogram; % Note that calories per kilogram is on a wet mass basis

initialfood = FoodMatter(Wheat,CarriedTotalMass,CarriedFood.EdibleFreshBasisWaterContent*CarriedTotalMass); % xmlFoodStoreLevel is declared within the createFoodStore method within SimulationInitializer.java

CarriedFoodStore = FoodStoreImpl(CarriedTotalMass,initialfood);

LocallyGrownFoodStore = FoodStoreImpl(15000);

%% Initialize SimEnvironments
% Convert daily leakage rate to hourly leakage rate
dailyLeakagePercentage = 0.05;      % Based on BVAD Table 4.1.1 for percentage of total gas mass lost per day 
% Let H = hourLeakagePercentage and initial total moles of gas = n_init
% Therefore we want:
% n_init*(1-dailyLeakagePercentage/100) = n_init*(1-H/100)^24
% Solving for H yields:
% H = 100*(1-(1-dailyLeakagePercentage/100)^(1/24))

% Using the above derived equation:
hourlyLeakagePercentage = 100*(1-(1-dailyLeakagePercentage/100)^(1/24));

Lab = SimEnvironmentImpl('Laboratory - Pressurized Excursion Module',55,56000,0.32,0.003,0.676,0,0.001,hourlyLeakagePercentage,PotableWaterStore,GreyWaterStore,DirtyWaterStore,DryWasteStore,[LocallyGrownFoodStore,CarriedFoodStore],o2fireRiskMolarFraction);     %Note volume input is in Liters. Volume reference - CxP Scenario 12.1
Loft = SimEnvironmentImpl('Loft',55,60000,0.32,0.003,0.676,0,0.001,hourlyLeakagePercentage,PotableWaterStore,GreyWaterStore,DirtyWaterStore,DryWasteStore,[LocallyGrownFoodStore,CarriedFoodStore],o2fireRiskMolarFraction);        % Volume reference - X-Hab Solicitation 2010
PCM = SimEnvironmentImpl('Pressurized Core Module',55,56000,0.32,0.003,0.676,0,0.001,hourlyLeakagePercentage,PotableWaterStore,GreyWaterStore,DirtyWaterStore,DryWasteStore,[LocallyGrownFoodStore,CarriedFoodStore],o2fireRiskMolarFraction);   % All ECLSS technologies are located here
PLM = SimEnvironmentImpl('Pressurized Logistics Module',55,56000,0.32,0.003,0.676,0,0.001,hourlyLeakagePercentage,PotableWaterStore,GreyWaterStore,DirtyWaterStore,DryWasteStore,[LocallyGrownFoodStore,CarriedFoodStore],o2fireRiskMolarFraction);   % All ECLSS technologies are located here

%% Airlock Environment
% This environment is modeled to represent airlock depressurization losses
% and O2 consumed during EVA prebreathe

% Include airlock PCA (to recharge airlock)
% Remember to vent airlock for only first tick of EVA
% Remove this amount of air from the hab everytime an EVA occurs

airlockFreegasVolume = 7.4*1E3; %Obtained from "A Dual Chamber Hybrid Inflatable Suitlock for Planetary Surfaces or Deep Space" %3.7*1E3;     % L (converted from 3.7m^3) REF: BVAD Section 5.2.1 - this is equivalent to shuttle airlock - total volume is 4.25m^3 (pg 230 - The New Field of Space Architecture)
Suitlock = SimEnvironmentImpl('Suitlock',55,airlockFreegasVolume,0.32,0.003,0.676,0,0.001);      % We assume that the suitlock does not leak

suitlockAirLossVolume = 0.97*0.72*0.0254; % Assumed suitlock loss volume based on suitlock plate dimensions (assuming a 1 inch air gap). REF: Lunar Habitat Airlock/Suitlock (also refer to Space Architecture Book)
suitlockCycleLoss = Suitlock.pressure*suitlockAirLossVolume/(idealGasConstant*(273.15+Suitlock.temperature));    % REF: ISS Airlock depress pump is operated down to 13.8kPa, so the rest of the air is vented overboard - REF: "Trending of Overboard Leakage of ISS Cabin Atmosphere" (AIAA 2011-5149)

%% Set up EVA environment
% Size EVA for two people - include airlock losses when EVA is executed

% Currently, CrewPersonImpl is only configured to exchange air with
% the environment that their activity is in

% EVAs last for eight hours continuously

% EVA essentially consumes gases from the O2 storage tank - since these
% recharge the PLSS tanks

%% EVA Consumable Consumption
% EVAs occur over eight ticks
numberOfEVAcrew = 2;
O2molarMass = 2*15.999;          % g/mol
EMUpressure = 29.6; % in kPa - equates to 4.3psi - same as Shuttle EMU and is quoted in EAWG Section 5.1 for dexterous tasks
EMUvolume = 2*28.3168*numberOfEVAcrew; % Generally between 1.5 and 2 cubic feet [L] - EMU Handbook Section 1.5.5      % in Liters, for two crew members
EMUtotalMoles = EMUpressure*EMUvolume/(idealGasConstant*(273.15+23));   % Total moles within both EMUs
% EMUleakmoles = 0.005*1E3/O2molarMass;       % From BVAD Section 5.2.2 - EMU leakage is 0.005kg/h (which is higher than the value quoted within Figure 1.8 of the Hamilton Sundstand EMU Handbook (36.2cubic cm/min)
Vleakrate = 36.2*1E-3*60;   % (L/hr) Maximum volumetric leakage rate of the PGA is calculated as 36.2 cubic cm/min (Figure 1.8) [2] [L/hr]
EMUleakmoles = EMUpressure*Vleakrate/(idealGasConstant*(273.15+23));      % Maximum mass leakage rate of the PGA [kg/s]
EMUleakPercentage = EMUleakmoles*numberOfEVAcrew/EMUtotalMoles;

% EMUco2RemovalTechnology = 'METOX';  % other option is RCA
% EMUurineManagementTechnology = 'UCTA';  % other option is MAG

load EVAPLSSoutput

% Define end of EVA EMU gaseous parameters
if strcmpi(EMUco2RemovalTechnology,'METOX')
    finalEMUo2level = emuO2levelMETOX*numberOfEVAcrew;
    finalEMUco2level = emuCO2levelMETOX*numberOfEVAcrew;
    finalFeedwaterTanklevel = plssfeedwatertanklevelMETOX*numberOfEVAcrew;    % also corresponds to total humidity level consumed, this captures any thermal control leakage
    plssO2TankLevel = plssO2TanklevelMETOX*numberOfEVAcrew;        % set corresponding StoreImpl.currentLevel to this value
    totalCO2removed = plssCO2removedlevelMETOX*numberOfEVAcrew;
    METOXregeneratorLoad = StoreImpl('METOX adsorbed CO2','Environmental');
    metoxCO2regenRate = totalCO2removed/10;         % 10 hours to completely regenerate a METOX canister
elseif strcmpi(EMUco2RemovalTechnology,'RCA')
    finalEMUo2level = emuO2levelRCA*numberOfEVAcrew;
    finalEMUco2level = emuCO2levelRCA*numberOfEVAcrew;
    finalFeedwaterTanklevel = plssfeedwatertanklevelRCA*numberOfEVAcrew;
    plssO2TankLevel = plssO2TanklevelRCA*numberOfEVAcrew;        % set corresponding StoreImpl.currentLevel to this value
    totalCO2removed = plssCO2removedlevelRCA*numberOfEVAcrew;
end
finalEMUvaporlevel = emuVaporlevelcommon*numberOfEVAcrew;

 
% Thermal control = {sublimator,radiator,cryogenic} = water usage = [0.57kg/hr,0.19kg/h,0]      REF:
% BVAD Section 5.2.2
% Note: Cryogenic cooling refers to cryogenic storage of O2
% O2 use: metabolic + leakage - 0.076kg/h, Note: O2 leakage alone is
% 0.005kg/h - REF BVAD Section 5.2.2 (compare this with EMU data)
% EVAco2removal = [METOX, Amine Swingbed]
% Amine Swingbed O2 loss rate is 0.15kg/h


% EMUdrinkbagVolume = 32*0.0295735;  % L, converted from 32 ounces (REF: Section 1.3.9 EMU Handbook)
% EMUinsuitDrinkBag = StoreImpl('EMU Drink Bag','Material',EMUdrinkbagVolume*numberOfEVAcrew,0);

EMUfeedwaterCapacity = 10*0.453592;  % (L), converted from 10 pounds of water, assuming a water density of 1000kg/m^3 = 1kg/L, REF - Section 2.1.4 EMU Handbook
EMUfeedwaterReservoir = StoreImpl('PLSS Feedwater Reservoir','Material',EMUfeedwaterCapacity*numberOfEVAcrew,0);

% Two options for liquid metabolic waste - either throw it away (as in the
% EMU MAG), or collect urine and feed it back into the UPA - as in Apollo
% EMU - find a reference for this!)
if strcmpi(EMUurineManagementTechnology,'UCTA')
    EVAenvironment = SimEnvironmentImpl('EVA Environment',EMUpressure,EMUvolume,1,0,0,0,0,EMUleakPercentage,PotableWaterStore,EMUfeedwaterReservoir,DirtyWaterStore,DryWasteStore,[LocallyGrownFoodStore,CarriedFoodStore]);
elseif strcmpi(EMUurineManagementTechnology,'MAG')
    EMUmetabolicWaste = StoreImpl('EVA MAG','Environmental');       % This is to replace the dirty water store if water is collected within the MAG
    EVAenvironment = SimEnvironmentImpl('EVA Environment',EMUpressure,EMUvolume,1,0,0,0,0,EMUleakPercentage,PotableWaterStore,EMUfeedwaterReservoir,EMUmetabolicWaste,DryWasteStore,[LocallyGrownFoodStore,CarriedFoodStore]);
end

EMUo2TankCapacity = 1.217*453.592/O2molarMass;      % moles, Converted from 1.217lbs - REF: Section 2.1.3 EMU Handbook
EMUo2Tanks = StoreImpl('EMU O2 Bottles','Material',EMUo2TankCapacity*numberOfEVAcrew,0);

% % EMU PCA
% EMUPCA = ISSinjectorImpl(EMUpressure,1,EMUo2Tanks,[],EVAenvironment,'EMU');

% Note: EMU Food bar is no longer flown (REF:
% http://spaceflight.nasa.gov/shuttle/reference/faq/eva.html)

%% EMU Prebreathe per CrewPerson
% This is the same as that employed for the space shuttle (going from a
% 70.3kPa 26.5% O2 atmosphere to a 29.6kPa 100% O2 atmosphere
% - Prebreathe lasts for 40 minutes and is performed in suit (REF: Table
% 3.1-1 EAWG Report)
% On ISS, an in-suit prebreath lasts 240 minutes (REF: Table 3.1-1 EAWG
% Report) and consumes 4.53kg per EVA (REF: Methodology and Assumptions
% of Contingency Shuttle Crew Support (CSCS) Calculations Using ISS ECLSS -
% SAE 2006-01-2061)

% Modified value according to more updated data:
% A typical suit purge on the ISS will achieve ? 95% O2 after 8 minutes and requires about 0.65 lb of O2."
% REF: Fifteen-minute EVA Prebreathe Protocol Using NASA's Exploration
% Atmosphere - AIAA2013-3525 - 0.65lb O2 used per EMU (includes inflation)
prebreatheO2 = 0.65*453.592/O2molarMass*numberOfEVAcrew;   % moles of O2... supplied from O2 tanks

%% Initialize Pressure Balancer
% Adjacency Matrix to represent connectivity between modules
Modules = [PCM,Lab,Loft,Suitlock,PLM];
AdjacencyMatrix = zeros(length(Modules));
AdjacencyMatrix(1,[2,3,5]) = 1;
AdjacencyMatrix(2,1) = 1;
AdjacencyMatrix(3,[1,4]) = 1;
AdjacencyMatrix(4,3) = 1;
AdjacencyMatrix(5,1) = 1;
PressureFlow = PressureDistribute(Modules,AdjacencyMatrix);

%% Initialize Key Activity Parameters

% Baseline Activities and Location Mappings
lengthOfExercise = 2;                       % Number of hours spent on exercise activity

% Generate distribution of habitation options from which IVA activities
% will take place
HabDistribution = [repmat(Lab,1,2),repmat(Loft,1,2),PCM,PLM];

IVAhour = ActivityImpl('IVA',2,1,HabDistribution);          % One hour of IVA time (corresponds to generic IVA activity)
Sleep = ActivityImpl('Sleep',1,8,Loft);          % Sleep period
Exercise = ActivityImpl('Exercise',5,lengthOfExercise,PCM);    % Exercise period
EVA = ActivityImpl('EVA',4,8,EVAenvironment);              % EVA - fixed length of 8 hours

% Vector of baseline activities:
ActivityList = [IVAhour,Sleep,Exercise,EVA];

% Auto-Generate Crew Schedule
[crewSchedule, missionEVAschedule,crewEVAScheduleLogical] = CrewScheduler(numberOfEVAdaysPerWeek,numberOfCrew,missionDurationInWeeks,ActivityList);

%% Initialize CrewPersons
astro1 = CrewPersonImpl2('Male 1',35,75,'Male',[crewSchedule{1,:}]);%,O2FractionHypoxicLimit);
astro2 = CrewPersonImpl2('Female 1',35,55,'Female',[crewSchedule{2,:}]);
astro3 = CrewPersonImpl2('Male 2',35,75,'Male',[crewSchedule{3,:}]);
astro4 = CrewPersonImpl2('Female 2',35,55,'Female',[crewSchedule{4,:}]);

%% Clear crewSchedule to save ~2MB memory
clear crewSchedule

%% Biomass Stores
BiomassStore = BiomassStoreImpl(100000);
% Set more crop type for FoodMatter somewhere later on

%% Initialize crop shelves

CropWaterStore = StoreImpl('Grey Crop H2O','Material',100000,100000);   % Initialize a 9200L water buffer

% WhitePotatoShelf = ShelfImpl3(WhitePotato,5,Loft,CropWaterStore,CropWaterStore,MainPowerStore,BiomassStore);
% PeanutShelf = ShelfImpl3(Peanut,72.68,Loft,CropWaterStore,CropWaterStore,MainPowerStore,BiomassStore);
% SoybeanShelf = ShelfImpl3(Soybean,39.7,Loft,CropWaterStore,CropWaterStore,MainPowerStore,BiomassStore);
% SweetPotatoShelf = ShelfImpl3(SweetPotato,9.8,Loft,CropWaterStore,CropWaterStore,MainPowerStore,BiomassStore);
% WheatShelf = ShelfImpl3(Wheat,72.53,Loft,CropWaterStore,CropWaterStore,MainPowerStore,BiomassStore);

LettuceGrowthArea = 8*8*0.102^2;        % Growth area for atrium within HDU (REF: Plant Atrium System for Food Production in NASA's DSH Tests)
LettuceShelf = ShelfImpl3(Lettuce,LettuceGrowthArea,Loft,CropWaterStore,CropWaterStore,MainPowerStore,BiomassStore);    % Grow this shelf all together (since total area is <1m^2)

% Initialize Staggered Shelves
% WhitePotatoShelves = ShelfStagger(WhitePotatoShelf,WhitePotatoShelf.Crop.TimeAtCropMaturity,0);
% PeanutShelves = ShelfStagger(PeanutShelf,PeanutShelf.Crop.TimeAtCropMaturity,0);
% SoybeanShelves = ShelfStagger(SoybeanShelf,SoybeanShelf.Crop.TimeAtCropMaturity,0);
% SweetPotatoShelves = ShelfStagger(SweetPotatoShelf,SweetPotatoShelf.Crop.TimeAtCropMaturity,0);
% WheatShelves = ShelfStagger(WheatShelf,WheatShelf.Crop.TimeAtCropMaturity,0);

%% Initialize FoodProcessor
FoodProcessor = FoodProcessorImpl;
FoodProcessor.BiomassConsumerDefinition = ResourceUseDefinitionImpl(BiomassStore,1000,1000);
FoodProcessor.PowerConsumerDefinition = ResourceUseDefinitionImpl(MainPowerStore,1000,1000);
FoodProcessor.FoodProducerDefinition = ResourceUseDefinitionImpl(LocallyGrownFoodStore,1000,1000);
FoodProcessor.WaterProducerDefinition = ResourceUseDefinitionImpl(CropWaterStore,1000,1000);        % FoodProcessor now outputs back to crop water store
FoodProcessor.DryWasteProducerDefinition = ResourceUseDefinitionImpl(DryWasteStore,1000,1000);

%% Initialize (Intermodule Ventilation) Fans

% NB. Under normal power consumption conditions, the ISS IMV fan moves 
% approx. 6791 moles of air every hour
% As a result, we modify the max and desired molar flow rates to meet this
% number
% Desired is rounded up to 6800moles/hr, and the max corresponds to the max
% volumetric flow rate of 4106L/min indicated within Section 2, Chapter
% 3.2.6 of "Living Together In Space"
% 4106L/min*60min/hr*70.3kPa/(8.314J/K/mol*296.15K) = 7034mol/hr (we round
% this up to 7035mol/hr)

% IMV between Lab (PEM) and PCM
Lab2PCMFan = ISSFanImpl2(Lab,PCM,MainPowerStore);

% IMV between PLM and PCM
PLM2PCMFan = ISSFanImpl2(PLM,PCM,MainPowerStore);

% IMV between Loft and PCM
Loft2PCMFan = ISSFanImpl2(Loft,PCM,MainPowerStore);

% IMV between Lab (PEM) and Airlock
Lab2AirlockFan = ISSFanImpl2(Lab,Suitlock,MainPowerStore);

%% Initialize Injectors (Models ISS Pressure Control Assemblies)
% See accompanying word doc for rationale behind PCA locations

% Lab (PEM) PCA
LabPCA = ISSinjectorImpl(TotalAtmPressureTargeted,TargetO2MolarFraction,O2Store,N2Store,Lab);
LabPCA.UpperPPO2PercentageLimit = o2fireRiskMolarFraction;

% Loft PCA 
LoftPCA = ISSinjectorImpl(TotalAtmPressureTargeted,TargetO2MolarFraction,O2Store,N2Store,Loft);
LoftPCA.UpperPPO2PercentageLimit = o2fireRiskMolarFraction;

% PCM PCA
PCMPCA = ISSinjectorImpl(TotalAtmPressureTargeted,TargetO2MolarFraction,O2Store,N2Store,PCM);
PCMPCA.UpperPPO2PercentageLimit = o2fireRiskMolarFraction;

% Suitlock PCA
SuitlockPCA = ISSinjectorImpl(TotalAtmPressureTargeted,TargetO2MolarFraction,O2Store,N2Store,Suitlock);
SuitlockPCA.UpperPPO2PercentageLimit = o2fireRiskMolarFraction;

% PLM PPRV
PLMPPRV = ISSinjectorImpl(TotalAtmPressureTargeted,TargetO2MolarFraction,O2Store,N2Store,PLM,'PPRV');
PLMPPRV.UpperPPO2PercentageLimit = o2fireRiskMolarFraction;

%% Initialize Temperature and Humidity Control (THC) Technologies
% Insert CCAA within Lab, Loft, PCM, and Suitlock
% Placement of CCAAs is based on modules with a large period of continuous
% human presence (i.e. large sources of humidity condensate)

% Lab (PEM) CCAA
LabCCAA = ISSDehumidifierImpl(Lab,GreyWaterStore,MainPowerStore);

% Loft CCAA
LoftCCAA = ISSDehumidifierImpl(Loft,GreyWaterStore,MainPowerStore);

% PCM CCAA
PCMCCAA = ISSDehumidifierImpl(PCM,GreyWaterStore,MainPowerStore);

% Suitlock
SuitlockCCAA = ISSDehumidifierImpl(Suitlock,GreyWaterStore,MainPowerStore);

%% Initialize Air Processing Technologies

% Initialize Main VCCR (Linear)

cropsTargetCO2 = 1200;      % Ideal CO2 PPM level for lettuce crops
mainvccr = ISSVCCRLinearImpl(PCM,PCM,CO2Store,MainPowerStore,cropsTargetCO2);       % When there is a 5th element within the constructor for ISSVCCRLinearImpl, the CDRA is set to a reduced mode, where it only operates to reach a target CO2 level

% Initialize OGS
ogs = ISSOGA(TotalAtmPressureTargeted,TargetO2MolarFraction,PCM,PotableWaterStore,MainPowerStore,H2Store);

% Initialize CRS (Sabatier Reactor)
crs = ISSCRSImpl(H2Store,CO2Store,GreyWaterStore,MethaneStore,MainPowerStore);

% % Initialize Oxygen Removal Assembly
% inflatableORA = O2extractor(Loft,TotalAtmPressureTargeted,TargetO2MolarFraction,O2Store,'Molar Fraction');
% 
% % Initialize CO2 Injector
% targetCO2conc = 1200*1E-6;
% co2Injector = CO2Injector(Loft,CO2Store,targetCO2conc);
% 
% % lifeSupportUnitORA = O2extractor(LifeSupportUnit1,TotalAtmPressureTargeted,TargetO2MolarFraction,O2Store);
% 
% % Condensed Water Removal System
% inflatable2WaterExtractor = CondensedWaterRemover(Loft,CropWaterStore);

%% Initialize Water Processing Technologies

% Initialize WaterRS (Linear)
waterRS = ISSWaterRSLinearImpl(DirtyWaterStore,GreyWaterStore,GreyWaterStore,DryWasteStore,PotableWaterStore,MainPowerStore);


%% Initialize Power Production Systems
% We assume basically unlimited power here
% Initialize General Power Producer
powerPS = PowerPSImpl('Nuclear',500000);
powerPS.PowerProducerDefinition = ResourceUseDefinitionImpl(MainPowerStore,1E6,1E6);
powerPS.LightConsumerDefinition = Lab;

%% Time Loop

simtime = missionDurationInHours;
% t = 1:simtime;

o2storelevel = zeros(1,simtime);
co2storelevel = zeros(1,simtime);
n2storelevel = zeros(1,simtime);
h2storelevel = zeros(1,simtime);
ch4storelevel = zeros(1,simtime);
potablewaterstorelevel = zeros(1,simtime);
dirtywaterstorelevel = zeros(1,simtime);
greywaterstorelevel = zeros(1,simtime);
drywastestorelevel = zeros(1,simtime);
carriedfoodstorelevel = zeros(1,simtime);
grownfoodstorelevel = zeros(1,simtime);
dryfoodlevel = zeros(1,simtime);
caloriccontent = zeros(1,simtime);
biomassstorelevel = zeros(1,simtime);
cropwaterstorelevel = zeros(1,simtime);
powerlevel = zeros(1,simtime);
metoxregenstore = zeros(1,simtime);
dumpedEVAdirtywater = zeros(1,simtime);
plssfeedwatertanklevel = zeros(1,simtime);
plsso2tanklevel = zeros(1,simtime);
reservoirFillLevel = zeros(1,simtime);

LabPressure = zeros(1,simtime);
LabO2level = zeros(1,simtime);
LabCO2level = zeros(1,simtime);
LabN2level = zeros(1,simtime);
LabVaporlevel = zeros(1,simtime);
LabOtherlevel = zeros(1,simtime);
LabTotalMoles = zeros(1,simtime);

LoftPressure = zeros(1,simtime);
LoftO2level = zeros(1,simtime);
LoftCO2level = zeros(1,simtime);
LoftN2level = zeros(1,simtime);
LoftVaporlevel = zeros(1,simtime);
LoftOtherlevel = zeros(1,simtime);
LoftTotalMoles = zeros(1,simtime);
LoftCondensedVaporMoles = zeros(1,simtime);

PCMPressure = zeros(1,simtime);
PCMO2level = zeros(1,simtime);
PCMCO2level = zeros(1,simtime);
PCMN2level = zeros(1,simtime);
PCMVaporlevel = zeros(1,simtime);
PCMOtherlevel = zeros(1,simtime);
PCMTotalMoles = zeros(1,simtime);

PLMPressure = zeros(1,simtime);
PLMO2level = zeros(1,simtime);
PLMCO2level = zeros(1,simtime);
PLMN2level = zeros(1,simtime);
PLMVaporlevel = zeros(1,simtime);
PLMOtherlevel = zeros(1,simtime);
PLMTotalMoles = zeros(1,simtime);

SuitlockPressure = zeros(1,simtime);
SuitlockO2level = zeros(1,simtime);
SuitlockCO2level = zeros(1,simtime);
SuitlockN2level = zeros(1,simtime);
SuitlockVaporlevel = zeros(1,simtime);
SuitlockOtherlevel = zeros(1,simtime);
SuitlockTotalMoles = zeros(1,simtime);

ogsoutput = zeros(1,simtime);
LabPCAaction = zeros(4,simtime+1);
LoftPCAaction = zeros(4,simtime+1);
PCMPCAaction = zeros(4,simtime+1);
SuitlockPCAaction = zeros(4,simtime+1);
PLMPPRVaction = zeros(4,simtime+1);

LabCCAAoutput = zeros(1,simtime);
LoftCCAAoutput = zeros(1,simtime);
PCMCCAAoutput = zeros(1,simtime);
SuitlockCCAAoutput = zeros(1,simtime);

% condensedWaterRemoved = zeros(1,simtime);
% co2injected = zeros(1,simtime);

% lettuceShelfWaterLevel = zeros(1,simtime);
% peanutShelfWaterLevel = zeros(1,simtime);
% soybeanShelfWaterLevel = zeros(1,simtime);
% sweetPotatoShelfWaterLevel = zeros(1,simtime);
% wheatShelfWaterLevel = zeros(1,simtime);

crsH2OProduced = zeros(1,simtime);
crsCompressorOperation = zeros(2,simtime);
co2accumulatorlevel = zeros(1,simtime);
co2removed = zeros(1,simtime);

suitlockGasVented = zeros(1,simtime);

hoursOnEVA = zeros(1,simtime);     % Flag to indicate whether or not the Airlock should be depressurized
currentEVAcrew = zeros(1,4);    % Current crewpersons on EVA

h = waitbar(0,'Please wait...');

toc

%% Time Loop

tic

timestamp = datestr(clock);
timestamp(timestamp==':') = '-';
% Start recording command window
diary(['HabNet Log ',timestamp,'.txt'])
disp(['Simulation Run Started: ',datestr(clock)]);
disp('Baseline Simulation Run - With Lettuce & All ISRU')

for i = 1:simtime
        
    if astro1.alive == 0 || astro2.alive == 0 || astro3.alive == 0 || astro4.alive == 0 ||...
            LettuceShelf.hasDied >= 1

%             sum([WhitePotatoShelves.Shelves.hasDied]) >= 1 ||...
%             sum([PeanutShelves.Shelves.hasDied]) >= 1 || ...
%             sum([SoybeanShelves.Shelves.hasDied]) >= 1 || ...
%             sum([SweetPotatoShelves.Shelves.hasDied]) >= 1 || ...
%             sum([WheatShelves.Shelves.hasDied]) >= 1
        
        % Remove all trailing zeros from recorded data vectors
        o2storelevel = o2storelevel(1:(i-1));
        co2storelevel = co2storelevel(1:(i-1));
        n2storelevel = n2storelevel(1:(i-1));
        h2storelevel = h2storelevel(1:(i-1));
        ch4storelevel = ch4storelevel(1:(i-1));
        potablewaterstorelevel = potablewaterstorelevel(1:(i-1));
        dirtywaterstorelevel = dirtywaterstorelevel(1:(i-1));
        greywaterstorelevel = greywaterstorelevel(1:(i-1));
        drywastestorelevel = drywastestorelevel(1:(i-1));
        carriedfoodstorelevel = carriedfoodstorelevel(1:(i-1));
        cropwaterstorelevel = cropwaterstorelevel(1:(i-1));
        powerlevel = powerlevel(1:(i-1));
        if strcmpi(EMUco2RemovalTechnology,'METOX')
            metoxregenstore = metoxregenstore(1:(i-1));
        end
        
        if strcmpi(EMUurineManagementTechnology,'MAG')
            dumpedEVAdirtywater = dumpedEVAdirtywater(1:(i-1));
        end
        plssfeedwatertanklevel = plssfeedwatertanklevel(1:(i-1));
        plsso2tanklevel = plsso2tanklevel(1:(i-1));
        
        hoursOnEVA = hoursOnEVA(1:(i-1));
    
        % Record Inflatable Unit Atmosphere
        LabPressure = LabPressure(1:(i-1));
        LabO2level = LabO2level(1:(i-1));
        LabCO2level = LabCO2level(1:(i-1));
        LabN2level = LabN2level(1:(i-1));
        LabVaporlevel = LabVaporlevel(1:(i-1));
        LabOtherlevel = LabOtherlevel(1:(i-1));
        LabTotalMoles = LabTotalMoles(1:(i-1));
                
        LoftPressure = LoftPressure(1:(i-1));
        LoftO2level = LoftO2level(1:(i-1));
        LoftCO2level = LoftCO2level(1:(i-1));
        LoftN2level = LoftN2level(1:(i-1));
        LoftVaporlevel = LoftVaporlevel(1:(i-1));
        LoftOtherlevel = LoftOtherlevel(1:(i-1));
        LoftTotalMoles = LoftTotalMoles(1:(i-1));
        LoftCondensedVaporMoles = LoftCondensedVaporMoles(1:(i-1));
    
        % Record Living Unit Atmosphere
        PCMPressure = PCMPressure(1:(i-1));
        PCMO2level = PCMO2level(1:(i-1));
        PCMCO2level = PCMCO2level(1:(i-1));
        PCMN2level = PCMN2level(1:(i-1));
        PCMVaporlevel = PCMVaporlevel(1:(i-1));
        PCMOtherlevel = PCMOtherlevel(1:(i-1));
        PCMTotalMoles = PCMTotalMoles(1:(i-1));
        
        % Record Cargo Unit Atmosphere
        PLMPressure = PLMPressure(1:(i-1));
        PLMO2level = PLMO2level(1:(i-1));
        PLMCO2level = PLMCO2level(1:(i-1));
        PLMN2level = PLMN2level(1:(i-1));
        PLMVaporlevel = PLMVaporlevel(1:(i-1));
        PLMOtherlevel = PLMOtherlevel(1:(i-1));
        PLMTotalMoles = PLMTotalMoles(1:(i-1));
        
        % Record Airlock Atmosphere
        SuitlockPressure = SuitlockPressure(1:(i-1));
        SuitlockO2level = SuitlockO2level(1:(i-1));
        SuitlockCO2level = SuitlockCO2level(1:(i-1));
        SuitlockN2level = SuitlockN2level(1:(i-1));
        SuitlockVaporlevel = SuitlockVaporlevel(1:(i-1));
        SuitlockOtherlevel = SuitlockOtherlevel(1:(i-1));
        SuitlockTotalMoles = SuitlockTotalMoles(1:(i-1));
        
        ogsoutput = ogsoutput(1:(i-1));
        
        % Common Cabin Air Assemblies
        LabCCAAoutput = LabCCAAoutput(1:(i-1));
        LoftCCAAoutput = LoftCCAAoutput(1:(i-1));
        PCMCCAAoutput = PCMCCAAoutput(1:(i-1));
        SuitlockCCAAoutput = SuitlockCCAAoutput(1:(i-1));
        
        % Pressure Control Assemblies
        LabPCAaction = LabPCAaction(:,1:(i-1));
        LoftPCAaction = LoftPCAaction(:,1:(i-1));
        PCMPCAaction = PCMPCAaction(:,1:(i-1));
        SuitlockPCAaction = SuitlockPCAaction(:,1:(i-1));
        PLMPPRVaction = PLMPPRVaction(:,1:(i-1));
        
        % Run Waste Processing ECLSS Hardware
        co2removed = co2removed(1:(i-1));
        crsH2OProduced = crsH2OProduced(1:(i-1));
        co2accumulatorlevel = co2accumulatorlevel(1:(i-1));
        
        suitlockGasVented = suitlockGasVented(1:(i-1));
        
        t = 1:(length(o2storelevel));
        
        toc
        
        % Record and save command window display
        disp(['Simulation Run Ended: ',datestr(clock)]);
        diary off
        
        close(h)
        return
    end

    %% Invoke Fail
    if i == FailureTick
        for ii = 1:length(FailCommand)
            eval(FailCommand{ii});
            disp(['Failure invoked in ',ErrorList{SystemToFail(ii)},' at tick ',num2str(i)])
        end
    end
    
    %% Record Data
    % Resource Stores
    o2storelevel(i) = O2Store.currentLevel;
    co2storelevel(i) = CO2Store.currentLevel;
    n2storelevel(i) = N2Store.currentLevel;
    h2storelevel(i) = H2Store.currentLevel;
    ch4storelevel(i) = MethaneStore.currentLevel;
    potablewaterstorelevel(i) = PotableWaterStore.currentLevel;
    dirtywaterstorelevel(i) = DirtyWaterStore.currentLevel;
    greywaterstorelevel(i) = GreyWaterStore.currentLevel;
    drywastestorelevel(i) = DryWasteStore.currentLevel;
    biomassstorelevel(i) = BiomassStore.currentLevel;
    powerlevel(i) = MainPowerStore.currentLevel;
    if strcmpi(EMUco2RemovalTechnology,'METOX')
        metoxregenstore(i) = METOXregeneratorLoad.currentLevel;
    end
    
    if strcmpi(EMUurineManagementTechnology,'MAG')
        dumpedEVAdirtywater(i) = EMUmetabolicWaste.currentLevel;
    end

    % Record PLSS Tanks
    plssfeedwatertanklevel(i) = EMUfeedwaterReservoir.currentLevel;
    plsso2tanklevel(i) = EMUo2Tanks.currentLevel;
    
    % Record Inflatable Unit Atmosphere
    LabPressure(i) = Lab.pressure;
    LabO2level(i) = Lab.O2Store.currentLevel;
    LabCO2level(i) = Lab.CO2Store.currentLevel;
    LabN2level(i) = Lab.NitrogenStore.currentLevel;
    LabVaporlevel(i) = Lab.VaporStore.currentLevel;
    LabOtherlevel(i) = Lab.OtherStore.currentLevel;
    LabTotalMoles(i) = Lab.totalMoles;
    
    % Record Inflatable2 Unit Atmosphere
    LoftPressure(i) = Loft.pressure;
    LoftO2level(i) = Loft.O2Store.currentLevel;
    LoftCO2level(i) = Loft.CO2Store.currentLevel;
    LoftN2level(i) = Loft.NitrogenStore.currentLevel;
    LoftVaporlevel(i) = Loft.VaporStore.currentLevel;
    LoftOtherlevel(i) = Loft.OtherStore.currentLevel;
    LoftTotalMoles(i) = Loft.totalMoles;
    
    % Record Living Unit Atmosphere
    PCMPressure(i) = PCM.pressure;
    PCMO2level(i) = PCM.O2Store.currentLevel;
    PCMCO2level(i) = PCM.CO2Store.currentLevel;
    PCMN2level(i) = PCM.NitrogenStore.currentLevel;
    PCMVaporlevel(i) = PCM.VaporStore.currentLevel;
    PCMOtherlevel(i) = PCM.OtherStore.currentLevel;
    PCMTotalMoles(i) = PCM.totalMoles;
    
    % Record Living Unit 2 Atmosphere
    PLMPressure(i) = PLM.pressure;
    PLMO2level(i) = PLM.O2Store.currentLevel;
    PLMCO2level(i) = PLM.CO2Store.currentLevel;
    PLMN2level(i) = PLM.NitrogenStore.currentLevel;
    PLMVaporlevel(i) = PLM.VaporStore.currentLevel;
    PLMOtherlevel(i) = PLM.OtherStore.currentLevel;
    PLMTotalMoles(i) = PLM.totalMoles;
    
    % Record Suitlock Atmosphere
    SuitlockPressure(i) = Suitlock.pressure;
    SuitlockO2level(i) = Suitlock.O2Store.currentLevel;
    SuitlockCO2level(i) = Suitlock.CO2Store.currentLevel;
    SuitlockN2level(i) = Suitlock.NitrogenStore.currentLevel;
    SuitlockVaporlevel(i) = Suitlock.VaporStore.currentLevel;
    SuitlockOtherlevel(i) = Suitlock.OtherStore.currentLevel;
    SuitlockTotalMoles(i) = Suitlock.totalMoles;
    
    %% Tick Modules
    
    % Leak Modules
    Lab.tick;
    Loft.tick;
    PCM.tick;
    PLM.tick;
    Suitlock.tick;
    
    % Run Fans
    Lab2PCMFan.tick;
    PLM2PCMFan.tick;
    Loft2PCMFan.tick;
    Lab2AirlockFan.tick;
    
    % Equalize Pressures Across Modules (always put this line directly
    % after fan ticks)
    PressureFlow.tick;
    
    % Run Power Supply
    powerPS.tick; 
    
    % Run ECLSS Hardware       
    ogsoutput(i) = ogs.tick;
    
    % Tick ORA
%     inflatableO2extracted(i) = inflatableORA.tick;
    
    % Pressure Control Assemblies
    LabPCAaction(:,i+1) = LabPCA.tick(LabPCAaction(:,i));
    LoftPCAaction(:,i+1) = LoftPCA.tick(LoftPCAaction(:,i));
    PCMPCAaction(:,i+1) = PCMPCA.tick(PCMPCAaction(:,i));
    SuitlockPCAaction(:,i+1) = SuitlockPCA.tick(SuitlockPCAaction(:,i));
    PLMPPRVaction(:,i+1) = PLMPPRV.tick(PLMPPRVaction(:,i));
    
    % Common Cabin Air Assemblies
    LabCCAAoutput(i) = LabCCAA.tick;
    LoftCCAAoutput(i) = LoftCCAA.tick;
    PCMCCAAoutput(i) = PCMCCAA.tick;
    SuitlockCCAAoutput(i) = SuitlockCCAA.tick;
          
    % Run Waste Processing ECLSS Hardware
    co2removed(i) = mainvccr.tick;
    crsH2OProduced(i) = crs.tick;
    crsCompressorOperation(:,i) = crs.CompressorOperation;
    co2accumulatorlevel(i) = crs.CO2Accumulator.currentLevel;
    waterRS.tick;
    
    %% Food Production System
    cropwaterstorelevel(i) = CropWaterStore.currentLevel;
     
    if CropWaterStore.currentLevel <= 0
        disp(['Crop Water Store is empty at tick: ',num2str(i)])
        break
    end
    
    % ISRU inject water into CropWaterStore (0.565L/hr)
%     CropWaterStore.add(0.565);
    
%     % Record shelf water levels
%     lettuceShelfWaterLevel(i) = LettuceShelf.ShelfWaterLevel;
%     peanutShelfWaterLevel(i) = PeanutShelf.ShelfWaterLevel;
%     soybeanShelfWaterLevel(i) = SoybeanShelf.ShelfWaterLevel;
%     sweetPotatoShelfWaterLevel(i) = SweetPotatoShelf.ShelfWaterLevel;
%     wheatShelfWaterLevel(i) = WheatShelf.ShelfWaterLevel;

    % Tick Crop Shelves
    %% add co2 injector here
%     co2injected(i) = co2Injector.tick;
%     WhitePotatoShelves.tick;
%     co2Injector.tick;
%     PeanutShelves.tick;
%     co2Injector.tick;
%     SoybeanShelves.tick;
%     co2Injector.tick;
%     SweetPotatoShelves.tick;
%     co2Injector.tick;
%     WheatShelves.tick;

	LettuceShelf.tick;

    FoodProcessor.tick;
    carriedfoodstorelevel(i) = CarriedFoodStore.currentLevel;
    grownfoodstorelevel(i) = LocallyGrownFoodStore.currentLevel;
    if LocallyGrownFoodStore.currentLevel > 0       
        dryfoodlevel(i) = sum(cell2mat({LocallyGrownFoodStore.foodItems.Mass})-cell2mat({LocallyGrownFoodStore.foodItems.WaterContent}));
        caloriccontent(i) = sum([LocallyGrownFoodStore.foodItems.CaloricContent]);
    end    
    
    %% Tick Crew
    astro1.tick;
    astro2.tick;  
    astro3.tick;
    astro4.tick;
   
    %% Run ISRU
    PotableWaterStore.add(isruAddedWater);
    CropWaterStore.add(isruAddedCropWater);
    O2Store.add(isruAddedO2);
    N2Store.add(isruAddedN2);
    
    %% EVA
    CrewEVAstatus = [strcmpi(astro1.CurrentActivity.Name,'EVA'),...
        strcmpi(astro2.CurrentActivity.Name,'EVA'),...
        strcmpi(astro3.CurrentActivity.Name,'EVA'),...
        strcmpi(astro4.CurrentActivity.Name,'EVA')];
    
    % Regenerate METOX canisters if required
    % Add CO2 removed from METOX canister to Airlock
    if strcmpi(EMUco2RemovalTechnology,'METOX')
        Suitlock.CO2Store.add(METOXregeneratorLoad.take(metoxCO2regenRate));
    end
    
    % if any astro has a current activity that is EVA
    if sum(CrewEVAstatus) > 0
        % identify first crewmember
        hoursOnEVA(i) = hoursOnEVA(i-1)+1;
        if hoursOnEVA(i) == 1
            % Store EVA status
            currentEVAcrew = CrewEVAstatus;

            % Error
            if O2Store.currentLevel < prebreatheO2
                disp(['Insufficient O2 for crew EVA prebreathe or EMU suit fill at tick: ',num2str(i)])
                disp('Current EVA has been skipped')
                % Advance activities for all astronauts
                astro1.skipActivity;
                astro2.skipActivity;
                astro3.skipActivity;
                astro4.skipActivity;
                continue
            end
            
            % perform airlock ops
            % purge and fill EVA suits with O2 from O2Store 
            EVAsuitfill = EVAenvironment.O2Store.add(O2Store.take(prebreatheO2));              % Fill two EMUs with 100% O2
            reservoirFillLevel(i) = EMUfeedwaterReservoir.fill(PotableWaterStore);                                      % fill feedwater tanks
            EMUo2Tanks.fill(O2Store);                                                           % fill PLSS O2 tanks
            
            % Vent lost airlock gases
            suitlockCycleLoss = Suitlock.pressure*suitlockAirLossVolume/(idealGasConstant*(273.15+Suitlock.temperature));    % Suitlock losses are a function of pressure
            suitlockGasVented(i) = Suitlock.vent(suitlockCycleLoss);
            
        elseif hoursOnEVA(i) == 8      % end of EVA
            % Empty EMU and add residual gases within EMU to Airlock
            EVAenvironment.O2Store.currentLevel = 0;
            EVAenvironment.CO2Store.currentLevel = 0;
            EVAenvironment.VaporStore.currentLevel = 0;
            
            Suitlock.O2Store.add(finalEMUo2level);
            Suitlock.CO2Store.add(finalEMUco2level);
            Suitlock.VaporStore.add(finalEMUvaporlevel);
            
            % Define PLSS Store levels
            EMUfeedwaterReservoir.currentLevel = finalFeedwaterTanklevel;
            EMUo2Tanks.currentLevel = plssO2TankLevel;       
            
            % For METOX case, add PLSS removed CO2 back to Airlock 
            % (equivalent to METOX oven baking) 
            if strcmpi(EMUco2RemovalTechnology,'METOX')
                METOXregeneratorLoad.add(totalCO2removed);
            end
            
            % For humidity condensate: for RCA, the loss is captured in 
            % finalEMUvaporlevel, while for the METOX, all humidity
            % condensate is sitting within the feedwater tank
        end
    end
    % If the crew is no longer on EVA, reset hoursOnEVA
    if ~isequal(CrewEVAstatus,currentEVAcrew)
        % if identified crewmember's current activity is not EVA
        hoursOnEVA(i) = 0;
        
        % Run Suitlock PCA
%         SuitlockPCAaction(:,i+1) = SuitlockPCA.tick(SuitlockPCAaction(:,i));
        
        % Run Suitlock CCAA
%         SuitlockCCAAoutput(i) = SuitlockCCAA.tick;
    end
    
    %% Tick Waitbar
    if mod(i,100) == 0
        waitbar(i/simtime,h,['Current tick: ',num2str(i),' | Time Elapsed: ',num2str(round(toc)),'sec']);
    end

%     value(i) = hoursOnEVA;
end

toc

beep

close(h)

diary off

% save('HDUBaseline')

%% Random plot commands used in code validation exercise
% Atmospheric molar fractions
% figure, 
% subplot(2,3,1), plot(t,LabO2level(t)./LabTotalMoles,t,LabCO2level./LabTotalMoles,t,LabN2level./LabTotalMoles,t,LabVaporlevel./LabTotalMoles,t,LabOtherlevel./LabTotalMoles,'LineWidth',2), title('Lab'),legend('O2','CO2','N2','Vapor','Other'), grid on, xlabel('Time (hours)'), ylabel('Molar Fraction')
% subplot(2,3,2), plot(t,PCMO2level(t)./PCMTotalMoles,t,PCMCO2level./PCMTotalMoles,t,PCMN2level./PCMTotalMoles,t,PCMVaporlevel./PCMTotalMoles,t,PCMOtherlevel./PCMTotalMoles,'LineWidth',2), title('PCM'),legend('O2','CO2','N2','Vapor','Other'), grid on, xlabel('Time (hours)'), ylabel('Molar Fraction')
% subplot(2,3,3), plot(t,PLMO2level(t)./PLMTotalMoles(t),t,PLMCO2level(t)./PLMTotalMoles(t),t,PLMN2level(t)./PLMTotalMoles(t),t,PLMVaporlevel(t)./PLMTotalMoles(t),t,PLMOtherlevel(t)./PLMTotalMoles(t),'LineWidth',2), title('PLM'),legend('O2','CO2','N2','Vapor','Other'), grid on, xlabel('Time (hours)'), ylabel('Molar Fraction')
% subplot(2,3,4), plot(t,LoftO2level(t)./LoftTotalMoles,t,LoftCO2level./LoftTotalMoles,t,LoftN2level./LoftTotalMoles,t,LoftVaporlevel./LoftTotalMoles,t,LoftOtherlevel./LoftTotalMoles,'LineWidth',2), title('Loft'),legend('O2','CO2','N2','Vapor','Other'), grid on, xlabel('Time (hours)'), ylabel('Molar Fraction')
% subplot(2,3,5), plot(t,SuitlockO2level(t)./SuitlockTotalMoles,t,SuitlockCO2level./SuitlockTotalMoles,t,SuitlockN2level./SuitlockTotalMoles,t,SuitlockVaporlevel./SuitlockTotalMoles,t,SuitlockOtherlevel./SuitlockTotalMoles,'LineWidth',2), title('Suitlock'),legend('O2','CO2','N2','Vapor','Other'), grid on, xlabel('Time (hours)'), ylabel('Molar Fraction')

% Partial Pressures
t = 1:(length(o2storelevel));

figure, 
subplot(2,3,1), plot(t,LabO2level(t)./LabTotalMoles(t).*LabPressure(t),t,LabCO2level(t)./LabTotalMoles(t).*LabPressure(t),t,LabN2level(t)./LabTotalMoles(t).*LabPressure(t),t,LabVaporlevel(t)./LabTotalMoles(t).*LabPressure(t),t,LabOtherlevel(t)./LabTotalMoles(t).*LabPressure(t),'LineWidth',2), title('Lab'),legend('O2','CO2','N2','Vapor','Other'), grid on, xlabel('Time (hours)'), ylabel('Partial Pressure')
subplot(2,3,2), plot(t,PCMO2level(t)./PCMTotalMoles(t).*PCMPressure(t),t,PCMCO2level(t)./PCMTotalMoles(t).*PCMPressure(t),t,PCMN2level(t)./PCMTotalMoles(t).*PCMPressure(t),t,PCMVaporlevel(t)./PCMTotalMoles(t).*PCMPressure(t),t,PCMOtherlevel(t)./PCMTotalMoles(t).*PCMPressure(t),'LineWidth',2), title('PCM'),legend('O2','CO2','N2','Vapor','Other'), grid on, xlabel('Time (hours)'), ylabel('Partial Pressure')
subplot(2,3,3), plot(t,PLMO2level(t)./PLMTotalMoles(t).*PLMPressure(t),t,PLMCO2level(t)./PLMTotalMoles(t).*PLMPressure(t),t,PLMN2level(t)./PLMTotalMoles(t).*PLMPressure(t),t,PLMVaporlevel(t)./PLMTotalMoles(t).*PLMPressure(t),t,PLMOtherlevel(t)./PLMTotalMoles(t).*PLMPressure(t),'LineWidth',2), title('PLM'),legend('O2','CO2','N2','Vapor','Other'), grid on, xlabel('Time (hours)'), ylabel('Partial Pressure')
subplot(2,3,4), plot(t,LoftO2level(t)./LoftTotalMoles(t).*LoftPressure(t),t,LoftCO2level(t)./LoftTotalMoles(t).*LoftPressure(t),t,LoftN2level(t)./LoftTotalMoles(t).*LoftPressure(t),t,LoftVaporlevel(t)./LoftTotalMoles(t).*LoftPressure(t),t,LoftOtherlevel(t)./LoftTotalMoles(t).*LoftPressure(t),'LineWidth',2), title('Loft'),legend('O2','CO2','N2','Vapor','Other'), grid on, xlabel('Time (hours)'), ylabel('Partial Pressure')
subplot(2,3,5), plot(t,SuitlockO2level(t)./SuitlockTotalMoles(t).*SuitlockPressure(t),t,SuitlockCO2level(t)./SuitlockTotalMoles(t).*SuitlockPressure(t),t,SuitlockN2level(t)./SuitlockTotalMoles(t).*SuitlockPressure(t),t,SuitlockVaporlevel(t)./SuitlockTotalMoles(t).*SuitlockPressure(t),t,SuitlockOtherlevel(t)./SuitlockTotalMoles(t).*SuitlockPressure(t),'LineWidth',2), title('Suitlock'),legend('O2','CO2','N2','Vapor','Other'), grid on, xlabel('Time (hours)'), ylabel('Partial Pressure')

% % Airlock ppCO2
% figure, plot(t,SuitlockCO2level./SuitlockTotalMoles.*SuitlockPressure,'LineWidth',2),grid on, title('Airlock ppCO2')
% 
% % O2 molar fraction
% figure, 
% subplot(2,3,1), plot(t,LabO2level(t)./LabTotalMoles(t),'LineWidth',2), title('Lab'), grid on, xlabel('Time (hours)'), ylabel('O2 Molar Fraction')
% subplot(2,3,2), plot(t,PCMO2level(t)./PCMTotalMoles(t),'LineWidth',2), title('PCM'), grid on, xlabel('Time (hours)'), ylabel('O2 Molar Fraction')
% subplot(2,3,3), plot(t,PLMO2level(t)./PLMTotalMoles(t),'LineWidth',2), title('PLM'), grid on, xlabel('Time (hours)'), ylabel('O2 Molar Fraction')
% subplot(2,3,4), plot(t,LoftO2level(t)./LoftTotalMoles(t),'LineWidth',2), title('Loft'), grid on, xlabel('Time (hours)'), ylabel('O2 Molar Fraction')
% subplot(2,3,5), plot(t,SuitlockO2level(t)./SuitlockTotalMoles(t),'LineWidth',2), title('Suitlock'), grid on, xlabel('Time (hours)'), ylabel('O2 Molar Fraction')
% 
% % O2 Partial Pressure
% figure, 
% subplot(2,3,1), plot(t,LabO2level(t)./LabTotalMoles(t).*LabPressure(t),'LineWidth',2), title('Lab'), grid on, xlabel('Time (hours)'), ylabel('O2 Partial Pressure')
% subplot(2,3,2), plot(t,PCMO2level(t)./PCMTotalMoles(t).*PCMPressure(t),'LineWidth',2), title('PCM'), grid on, xlabel('Time (hours)'), ylabel('O2 Partial Pressure')
% subplot(2,3,3), plot(t,PLMO2level(t)./PLMTotalMoles(t).*PLMPressure(t),'LineWidth',2), title('PLM'), grid on, xlabel('Time (hours)'), ylabel('O2 Partial Pressure')
% subplot(2,3,4), plot(t,LoftO2level(t)./LoftTotalMoles(t).*PLMPressure(t),'LineWidth',2), title('Loft'), grid on, xlabel('Time (hours)'), ylabel('O2 Partial Pressure')
% subplot(2,3,5), plot(t,SuitlockO2level(t)./SuitlockTotalMoles(t).*PLMPressure(t),'LineWidth',2), title('Suitlock'), grid on, xlabel('Time (hours)'), ylabel('O2 Partial Pressure')
% 
% % CO2 molar fraction
% figure, 
% subplot(2,3,1), plot(t,LabCO2level(t)./LabTotalMoles(t),'LineWidth',2), title('Lab'), grid on, xlabel('Time (hours)'), ylabel('CO2 Molar Fraction')
% subplot(2,3,2), plot(t,PCMCO2level(t)./PCMTotalMoles(t),'LineWidth',2), title('PCM'), grid on, xlabel('Time (hours)'), ylabel('CO2 Molar Fraction')
% subplot(2,3,3), plot(t,PLMCO2level(t)./PLMTotalMoles(t),'LineWidth',2), title('PLM'), grid on, xlabel('Time (hours)'), ylabel('CO2 Molar Fraction')
% subplot(2,3,4), plot(t,LoftCO2level(t)./LoftTotalMoles(t),'LineWidth',2), title('Loft'), grid on, xlabel('Time (hours)'), ylabel('CO2 Molar Fraction')
% subplot(2,3,5), plot(t,SuitlockCO2level(t)./SuitlockTotalMoles(t),'LineWidth',2), title('Suitlock'), grid on, xlabel('Time (hours)'), ylabel('CO2 Molar Fraction')
% 
% 
% % CO2 Partial Pressure
% figure, 
% subplot(2,3,1), plot(t,LabCO2level(t)./LabTotalMoles(t).*LabPressure(t),'LineWidth',2), title('Lab'), grid on, xlabel('Time (hours)'), ylabel('CO2 Partial Pressure')
% subplot(2,3,2), plot(t,PCMCO2level(t)./PCMTotalMoles(t).*PCMPressure(t),'LineWidth',2), title('PCM'), grid on, xlabel('Time (hours)'), ylabel('CO2 Partial Pressure')
% subplot(2,3,3), plot(t,PLMCO2level(t)./PLMTotalMoles(t).*PLMPressure(t),'LineWidth',2), title('PLM'), grid on, xlabel('Time (hours)'), ylabel('CO2 Partial Pressure')
% subplot(2,3,4), plot(t,LoftCO2level(t)./LoftTotalMoles(t).*LoftPressure(t),'LineWidth',2), title('Loft'), grid on, xlabel('Time (hours)'), ylabel('CO2 Partial Pressure')
% subplot(2,3,5), plot(t,SuitlockCO2level(t)./SuitlockTotalMoles(t).*SuitlockPressure(t),'LineWidth',2), title('Suitlock'), grid on, xlabel('Time (hours)'), ylabel('CO2 Partial Pressure')
% 
% subplot(2,2,3),line([1 length(t)],0.482633011*ones(1,2),'LineWidth',2,'Color','r')
% 
% figure, 
% plot(t,PCMCO2level(t)./PCMTotalMoles(t).*PCMPressure(t),'LineWidth',2), 
% title('PCM CO2 Levels with CDRA Failure'), grid on, xlabel('Mission Elapsed Time (hours)'), ylabel('CO2 Partial Pressure')
% line([1 length(t)],0.482633011*ones(1,2),'LineWidth',2,'Color','r')
% 
% % N2 Partial Pressure
% figure, 
% subplot(2,2,1), plot(t,LabN2level(t)./LabTotalMoles(t).*LabPressure(t),'LineWidth',2), title('Inflatable 1'), grid on, xlabel('Time (hours)'), ylabel('N2 Partial Pressure')
% subplot(2,2,2), plot(t,PCMN2level(t)./PCMTotalMoles(t).*PCMPressure(t),'LineWidth',2), title('Living Unit 1'), grid on, xlabel('Time (hours)'), ylabel('N2 Partial Pressure')
% subplot(2,2,3), plot(t,lifeSupportUnitN2level(t)./lifeSupportUnitTotalMoles(t).*lifeSupportUnitPressure(t),'LineWidth',2), title('Life Support Unit 1'), grid on, xlabel('Time (hours)'), ylabel('N2 Partial Pressure')
% subplot(2,2,4), plot(t,PLMN2level(t)./PLMTotalMoles(t).*PLMPressure(t),'LineWidth',2), title('Cargo Unit 1'), grid on, xlabel('Time (hours)'), ylabel('N2 Partial Pressure')
% 
% % Vapor Partial Pressure
% figure, 
% subplot(2,3,1), plot(t,LabVaporlevel(t)./LabTotalMoles(t).*LabPressure(t),'LineWidth',2), title('Lab'), grid on, xlabel('Time (hours)'), ylabel('Vapor Partial Pressure')
% subplot(2,3,2), plot(t,PCMVaporlevel(t)./PCMTotalMoles(t).*PCMPressure(t),'LineWidth',2), title('PCM'), grid on, xlabel('Time (hours)'), ylabel('Vapor Partial Pressure')
% subplot(2,3,3), plot(t,PLMVaporlevel(t)./PLMTotalMoles(t).*PLMPressure(t),'LineWidth',2), title('PLM'), grid on, xlabel('Time (hours)'), ylabel('Vapor Partial Pressure')
% subplot(2,3,4), plot(t,LoftVaporlevel(t)./LoftTotalMoles(t).*LoftPressure(t),'LineWidth',2), title('Loft'), grid on, xlabel('Time (hours)'), ylabel('Vapor Partial Pressure')
% subplot(2,3,5), plot(t,SuitlockVaporlevel(t)./SuitlockTotalMoles(t).*SuitlockPressure(t),'LineWidth',2), title('Suitlock'), grid on, xlabel('Time (hours)'), ylabel('Vapor Partial Pressure')
% 
% % Vapor Molar Fraction
% figure, 
% subplot(2,3,1), plot(t,LabVaporlevel(t)./LabTotalMoles(t),'LineWidth',2), title('Lab'), grid on, xlabel('Time (hours)'), ylabel('Vapor Molar Fraction')
% subplot(2,3,2), plot(t,PCMVaporlevel(t)./PCMTotalMoles(t),'LineWidth',2), title('PCM'), grid on, xlabel('Time (hours)'), ylabel('Vapor Molar Fraction')
% subplot(2,3,3), plot(t,PLMVaporlevel(t)./PLMTotalMoles(t),'LineWidth',2), title('PLM'), grid on, xlabel('Time (hours)'), ylabel('Vapor Molar Fraction')
% subplot(2,3,4), plot(t,LoftVaporlevel(t)./LoftTotalMoles(t),'LineWidth',2), title('Loft'), grid on, xlabel('Time (hours)'), ylabel('Vapor Molar Fraction')
% subplot(2,3,5), plot(t,SuitlockVaporlevel(t)./SuitlockTotalMoles(t),'LineWidth',2), title('Suitlock'), grid on, xlabel('Time (hours)'), ylabel('Vapor Molar Fraction')
% 
% % Total Pressure
% figure, 
% subplot(2,3,1), plot(t,LabPressure(t),'LineWidth',2), title('Lab'), grid on, xlabel('Time (hours)'), ylabel('Total Pressure')
% subplot(2,3,2), plot(t,PCMPressure(t),'LineWidth',2), title('PCM'), grid on, xlabel('Time (hours)'), ylabel('Total Pressure')
% subplot(2,3,3), plot(t,PLMPressure(t),'LineWidth',2), title('PLM'), grid on, xlabel('Time (hours)'), ylabel('Total Pressure')
% subplot(2,3,4), plot(t,LoftPressure(t),'LineWidth',2), title('Loft'), grid on, xlabel('Time (hours)'), ylabel('Total Pressure')
% subplot(2,3,5), plot(t,SuitlockPressure(t),'LineWidth',2), title('Suitlock'), grid on, xlabel('Time (hours)'), ylabel('Total Pressure')

% % Environmental N2 Store plots
% figure, 
% subplot(2,2,1), plot(1:simtime,crewN2level,'LineWidth',2), title('Crew Quarters Environmental N2 Level'), grid on
% subplot(2,2,2), plot(1:simtime,lifeSupportUnitN2level,'LineWidth',2), title('Galley Environmental N2 Level'), grid on
% subplot(2,2,3), plot(1:simtime,labsN2level,'LineWidth',2), title('Labs Environmental N2 Level'), grid on
% subplot(2,2,4), plot(1:simtime,maintN2level,'LineWidth',2), title('Maintenance Environmental N2 Level'), grid on
% 
% i = i-1;
% figure, plot(1:(i-1),crewO2level(1:(i-1)),1:(i-1),crewCO2level(1:(i-1)),...
%     1:(i-1),crewN2level(1:(i-1)),1:(i-1),crewOtherlevel(1:(i-1)),1:(i-1),crewVaporlevel(1:(i-1)),'LineWidth',2),...
%    legend('O_2','CO_2','N_2','Other','Vapor'), grid on
% title('MATLAB Crew Quarters')
% 
% figure, plot(1:(i-1),maintO2level(1:(i-1)),1:(i-1),maintCO2level(1:(i-1)),...
%     1:(i-1),maintN2level(1:(i-1)),1:(i-1),maintOtherlevel(1:(i-1)),1:(i-1),maintVaporlevel(1:(i-1)),'LineWidth',2),...
%    legend('O_2','CO_2','N_2','Other','Vapor'), grid on
% title('MATLAB Maintenance Module')
% 
% figure, plot(1:(i-1),labsO2level(1:(i-1)),1:(i-1),labsCO2level(1:(i-1)),...
%     1:(i-1),labsN2level(1:(i-1)),1:(i-1),labsOtherlevel(1:(i-1)),1:(i-1),labsVaporlevel(1:(i-1)),'LineWidth',2),...
%    legend('O_2','CO_2','N_2','Other','Vapor'), grid on
% title('MATLAB Labs Module')
% 
% figure, plot(1:(i-1),galleyO2level(1:(i-1)),1:(i-1),galleyCO2level(1:(i-1)),...
%     1:(i-1),lifeSupportUnitN2level(1:(i-1)),1:(i-1),lifeSupportUnitOtherlevel(1:(i-1)),1:(i-1),lifeSupportUnitVaporlevel(1:(i-1)),'LineWidth',2),...
%    legend('O_2','CO_2','N_2','Other','Vapor'), grid on
% title('MATLAB Galley Module')
% 
% figure, plot(maintN2level,'LineWidth',2),grid on
% 
% figure, plot(1:length(crewO2level),crewO2level), grid on
% figure, plot(1:length(N2level),N2level), grid on
% figure, plot(1:length(crewCO2level),crewCO2level), grid on
% figure, plot(1:(i-1),H2level(1:(i-1)),'LineWidth',2), title('MATLAB H_2 Store'), grid on
% % figure, plot(1:length(H2level),H2level), grid on
% figure, plot(1:length(CH4level),CH4level), grid on
% figure, plot(1:length(crewVaporlevel),crewVaporlevel,'LineWidth',2), grid on, title('MATLAB Crew Quarters Vapor Level')
% figure, plot(1:(i-1),maintVaporlevel(1:(i-1)),'LineWidth',2), grid on, title('MATLAB Maintenance Vapor Level')
% figure, plot(1:(i-1),H2Ostorelevel(1:(i-1)),'LineWidth',2), title('MATLAB Potable Water Store'), grid on
% figure, plot(1:(i-1),DirtyH2Ostorelevel(1:(i-1)),'LineWidth',2), title('MATLAB Dirty Water Store'), grid on
% % figure, plot(1:length(DirtyH2Ostorelevel),DirtyH2Ostorelevel), grid on
% % figure, plot(1:length(FoodStoreLevel),FoodStoreLevel), grid on
% % figure, plot(1:length(DryWasteStoreLevel),DryWasteStoreLevel), grid on
% figure, plot(1:(i-1),DryWasteStoreLevel(1:(i-1)),'LineWidth',2), title('MATLAB Dry Waste Store'), grid on
% figure, plot(1:(i-1),GreyH2Ostorelevel(1:(i-1)),'LineWidth',2), title('MATLAB Grey Water Store'), grid on
% figure, plot(1:(i-1),O2Storelevel(1:(i-1)),'LineWidth',2), title('MATLAB O_2 Store'), grid on
% figure, plot(1:(i-1),CH4Storelevel(1:(i-1)),'LineWidth',2), title('MATLAB Methane Store'), grid on
% figure, plot(1:(i-1),consumedWaterBuffer(1:(i-1)),'LineWidth',2), title('MATLAB Consumed Water Buffer'), grid on
% % figure, plot(1:length(GreyH2Ostorelevel),GreyH2Ostorelevel), grid on
% figure, plot(1:(i-1),FoodStoreLevel(1:(i-1)),'LineWidth',2), title('MATLAB Food Store'), grid on
% figure, plot(1:length(CO2conc),CO2conc), grid on
% figure, plot(1:length(O2conc),O2conc), grid on
% figure, plot(1:length(vaporconc),vaporconc), grid on
% figure, plot(1:length(CO2concMain),CO2concMain), grid on
% figure, plot(1:length(O2concMain),O2concMain), grid on
% figure, plot(1:length(O2levelMain),O2levelMain), grid on
% figure, plot(1:length(pres),pres), grid on
% figure, plot(1:length(CO2storelevel),CO2storelevel), grid on
% figure, plot(1:length(powerlevel),powerlevel), grid on
% % figure, plot(1:length(CO2Storelevel),CO2Storelevel), grid on
% figure, plot(1:(i-1),CO2Storelevel(1:(i-1)),'LineWidth',2), title('MATLAB CO_2 Store'), grid on
% figure, plot(1:length(intensity),intensity)
