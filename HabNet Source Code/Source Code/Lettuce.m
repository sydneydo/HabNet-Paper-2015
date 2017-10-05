classdef Lettuce < handle%PlantImpl
    %Lettuce Summary of this class goes here
    %   Detailed explanation goes here
    
    properties (SetAccess = private)
        Name = 'Lettuce'
        Type = 'Planophile'
        taInitialValue = 1200
        initialPPFValue = 300 %295.14       % per m^2 of crop area - adjusted from BioSim value to that listed in Table 1 of "Crop Models for Varying Envrionmental Conditions"
        initialCO2Value = 1200                % micromoles of CO2/moles of atmosphere
        CarbonUseEfficiency24 = 0.625
        BCF = 0.4
        CUEmax = 0.625
        Photoperiod = 16
        NominalPhotoperiod = 16
        TimeAtOrganFormation = 1
        N = 2.5
        CQYMin = 0;
        TimeAtCanopySenescence = 31
        TimeAtCropMaturity = 30 %28  - Updated from BioSim value according to BVAD Table 4.2.28
        OPF = 1.08;
        FractionOfEdibleBiomass = 0.95 %0.9 - Updated from BioSim value according to BVAD Table 4.2.28
        CaloriesPerKilogram = (1-0.9498)*1000*(4*28.7+4*13.6+9*1.5)/(28.7+13.6+1.5) %180;
        EdibleFreshBasisWaterContent = 0.9498 %0.95 % percentage of edible portion of crop that is made up of water -  % REF: http://ndb.nal.usda.gov/ndb/foods/show/3050
        InedibleFreshBasisWaterContent = 0.9 % percentage of inedible portion of crop that is made up of water
        CanopyClosureConstants %= [95488,1068.6,zeros(1,4),15.977,zeros(1,3),0.3419,0.00019733,zeros(1,3),-0.00019076,zeros(1,9)]
        CanopyQuantumYieldConstants
        LightCycleTemperature = 23      % in Celsius
        CarbohydrateFractionOfDryMass = 28.7/(28.7+13.6+1.5)  % REF: http://ndb.nal.usda.gov/ndb/foods/show/3050
        ProteinFractionOfDryMass = 13.6/(28.7+13.6+1.5)       % REF: http://ndb.nal.usda.gov/ndb/foods/show/3050
        FatFractionOfDryMass = 1.5/(28.7+13.6+1.5)            % REF: http://ndb.nal.usda.gov/ndb/foods/show/3050
    end
    
    methods
        %% Constructor
        function obj = Lettuce%(cropArea,AirSource,AirSink)
            
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
            canopyClosureConstants(2) = 1.0289E4;
            canopyClosureConstants(3) = -3.7018;
            canopyClosureConstants(5) = 3.6648E-7;
            canopyClosureConstants(7) = 1.7571;
            canopyClosureConstants(9) = 2.3127E-6;
            canopyClosureConstants(11) = 1.876;
            
            obj.CanopyClosureConstants = canopyClosureConstants;
            
            % Initialize Canopy Quantum Yield Constants
            canopyQYConstants = zeros(1,25);
            canopyQYConstants(7) = 4.4763E-2;
            canopyQYConstants(8) = 5.163E-5;
            canopyQYConstants(9) = -2.075E-8;
            canopyQYConstants(12) = -1.1701E-5;
            canopyQYConstants(18) = -1.9731E-11;
            canopyQYConstants(19) = 8.9265E-15;
            
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

