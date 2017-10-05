classdef DryBean < handle%PlantImpl
    %DryBean Summary of this class goes here
    %   Detailed explanation goes here
    
    properties (SetAccess = private)
        Name = 'Dry Bean'
        Type = 'Legume'
        taInitialValue = 1200
        initialPPFValue = 600 %555.55       % per m^2 of crop area - adjusted from BioSim value to that listed in Table 1 of "Crop Models for Varying Envrionmental Conditions"
        initialCO2Value = 1200                % micromoles of CO2/moles of atmosphere
%         CarbonUseEfficiency24 = 0.64
        BCF = 0.45 %0.46 - Updated from BioSim value according to BVAD Table 4.2.29
        CUEmax = 0.65
        CUEmin = 0.5
        Photoperiod = 18
        NominalPhotoperiod = 12
        TimeAtOrganFormation = 40
        N = 2
        CQYMin = 0.02;
        TimeAtCanopySenescence = 42
        TimeAtCropMaturity = 63 %85 - Updated from BioSim value according to BVAD Table 4.2.28
        OPF = 1.1;
        FractionOfEdibleBiomass = 0.97 %0.4 - Updated from BioSim value according to BVAD Table 4.2.28
        CaloriesPerKilogram = (1-0.1175)*1000*(4*600.1+9*8.3+4*235.8)/(600.1+8.3+235.8) %3490;
        EdibleFreshBasisWaterContent = 0.1175 %0.1 % percentage of edible portion of crop that is made up of water -  % REF: http://ndb.nal.usda.gov/ndb/foods/show/4749
        InedibleFreshBasisWaterContent = 0.9 % percentage of inedible portion of crop that is made up of water
        CanopyClosureConstants %= [95488,1068.6,zeros(1,4),15.977,zeros(1,3),0.3419,0.00019733,zeros(1,3),-0.00019076,zeros(1,9)]
        CanopyQuantumYieldConstants
        LightCycleTemperature = 26      % in Celsius
        CarbohydrateFractionOfDryMass = 600.1/(600.1+8.3+235.8)  % REF: http://ndb.nal.usda.gov/ndb/foods/show/4749
        ProteinFractionOfDryMass = 235.8/(600.1+8.3+235.8)       % REF: http://ndb.nal.usda.gov/ndb/foods/show/4749
        FatFractionOfDryMass = 8.3/(600.1+8.3+235.8)             % REF: http://ndb.nal.usda.gov/ndb/foods/show/4749
    end
    
    methods
        %% Constructor
        function obj = DryBean%(cropArea,AirSource,AirSink)
            
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
            canopyClosureConstants(1) = 2.9041E5;
            canopyClosureConstants(2) = 1.5594E3;
            canopyClosureConstants(7) = 15.840;
            canopyClosureConstants(12) = 6.1120E-3;
            canopyClosureConstants(18) = -3.7409E-9;
            canopyClosureConstants(25) = 9.6484E-19;
            
            obj.CanopyClosureConstants = canopyClosureConstants;
            
            % Initialize Canopy Quantum Yield Constants
            canopyQYConstants = zeros(1,25);
            canopyQYConstants(7) = 4.191E-2;
            canopyQYConstants(8) = 5.3852E-5;
            canopyQYConstants(9) = -2.1275E-8;
            canopyQYConstants(12) = -1.238E-5;
            canopyQYConstants(18) = -1.544E-11;
            canopyQYConstants(19) = 6.469E-15;
            
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

