classdef Wheat < handle%PlantImpl
    %Wheat Summary of this class goes here
    %   Detailed explanation goes here
    
    properties (SetAccess = private)
        Name = 'Wheat'
        Type = 'Erectophile'
        taInitialValue = 1200
        initialPPFValue = 1400 %1597.22       % per m^2 of crop area - adjusted from BioSim value to that listed in Table 1 of "Crop Models for Varying Envrionmental Conditions"
        initialCO2Value = 1200                % micromoles of CO2/moles of atmosphere
        CarbonUseEfficiency24 = 0.64
        BCF = 0.44 %0.42 - Updated from BioSim value according to BVAD Table 4.2.29
        Photoperiod = 20
        NominalPhotoperiod = 20
        TimeAtOrganFormation = 34
        N = 1
        CQYMin = 0.01;
        TimeAtCanopySenescence = 33
        TimeAtCropMaturity = 62
        OPF = 1.07;
        FractionOfEdibleBiomass = 1 %0.4 - Updated from BioSim value according to BVAD Table 4.2.28
        CaloriesPerKilogram = (1-0.1242)*1000*(4*744.8+4*96.1+9*19.5) /(744.8+96.1+19.5)    %3300;  % Calories per kilogram of total wet food (dry food + water)
        EdibleFreshBasisWaterContent = 0.1242 %0.12 % percentage of edible portion of crop that is made up of water -  % REF: http://ndb.nal.usda.gov/ndb/foods/show/6532
        InedibleFreshBasisWaterContent = 0.9 % percentage of inedible portion of crop that is made up of water
        CanopyClosureConstants %= [95488,1068.6,zeros(1,4),15.977,zeros(1,3),0.3419,0.00019733,zeros(1,3),-0.00019076,zeros(1,9)]
        CanopyQuantumYieldConstants
        LightCycleTemperature = 23      % in Celsius
        CarbohydrateFractionOfDryMass = 744.8/(744.8+96.1+19.5)  % REF: http://ndb.nal.usda.gov/ndb/foods/show/6532
        ProteinFractionOfDryMass = 96.1/(744.8+96.1+19.5)       % REF: http://ndb.nal.usda.gov/ndb/foods/show/6532
        FatFractionOfDryMass = 19.5/(744.8+96.1+19.5)             % REF: http://ndb.nal.usda.gov/ndb/foods/show/6532
    end
    
    methods
        %% Constructor
        function obj = Wheat%(cropArea,AirSource,AirSink)
            
%             % Initial PPF Value
%             initialPPFValue = 1597.22;
%             
%             % Initial CO2 Value
%             initialCO2Value = 1200;
% 
%             % Initial TA Value (find out what TA is!)
%             TAInitialValue = 1200;
            
            % Initialize Canopy Closure Constants
            canopyClosureConstants = zeros(1,25);
            canopyClosureConstants(1) = 9.5488E4;
            canopyClosureConstants(2) = 1.0686E3;
            canopyClosureConstants(7) = 15.977;
            canopyClosureConstants(11) = 0.3419;
            canopyClosureConstants(12) = 1.9733E-4;
            canopyClosureConstants(16) = -1.9076E-4;
            
            obj.CanopyClosureConstants = canopyClosureConstants;
            
            % Initialize Canopy Quantum Yield Constants
            canopyQYConstants = zeros(1,25);
            canopyQYConstants(7) = 4.4793E-2;
            canopyQYConstants(8) = 5.1583E-5;
            canopyQYConstants(9) = -2.0724E-8;
            canopyQYConstants(12) = -5.1946E-6;
            canopyQYConstants(18) = -4.9303E-12;
            canopyQYConstants(19) = 2.2255E-15;
            
            obj.CanopyQuantumYieldConstants = canopyQYConstants;
%             % Construct Parent Class
%             obj@PlantImpl(cropArea,AirSource,AirSink,initialPPFValue,initialCO2Value,...
%                 TAInitialValue,canopyClosureConstants,canopyQYConstants);
            
%             % Update value of taInitialValue
%             obj.taInitialValue = TAInitialValue;
        end
        
        %% Tick
%         function obj = tick(obj)
%             tick@PlantImpl(obj);        % Access tick method within PlantImpl class
%         end
        
        
%             public Wheat(ShelfImpl pShelfImpl) {
%         super(pShelfImpl);
%         canopyClosureConstants(0) = 95488;
%         canopyClosureConstants(1) = 1068.6;
%         canopyClosureConstants(6) = 15.977;
%         canopyClosureConstants(10) = 0.3419;
%         canopyClosureConstants(11) = 0.00019733;
%         canopyClosureConstants(15) = -0.00019076;
% 
%         canopyQYConstants(6) = 0.044793;
%         canopyQYConstants(7) = 0.000051583;
%         canopyQYConstants(8) = -0.000000020724;
%         canopyQYConstants(11) = -0.0000051946;
%         canopyQYConstants(17) = -0.0000000000049303;
%         canopyQYConstants(18) = 0.0000000000000022255;
        
        
    end
    
end

