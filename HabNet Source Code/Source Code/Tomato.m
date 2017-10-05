classdef Tomato < handle
    %Tomato Summary of this class goes here
    %   Detailed explanation goes here
    
    properties (SetAccess = private)
        Name = 'Tomato'
        Type = 'Planophile'
        taInitialValue = 1200
        initialPPFValue = 500 %625       % per m^2 of crop area - adjusted from BioSim value to that listed in Table 1 of "Crop Models for Varying Envrionmental Conditions"
        initialCO2Value = 1200                % micromoles of CO2/moles of atmosphere
        CarbonUseEfficiency24 = 0.65
        BCF = 0.42 %0.43 - Updated from BioSim value according to BVAD Table 4.2.29
        CUEmax = 0.65
        CUEmin = 0
        Photoperiod = 12                % days
        NominalPhotoperiod = 12         % days
        TimeAtOrganFormation = 41       % days
        N = 2.5
        CQYMin = 0.01;
        TimeAtCanopySenescence = 56     % days
        TimeAtCropMaturity = 80 %85         % days - Updated from BioSim value according to BVAD Table 4.2.28
        OPF = 1.09;
        FractionOfEdibleBiomass = 0.7 %0.45 - Updated from BioSim value according to BVAD Table 4.2.28
        CaloriesPerKilogram = (1-0.9452)*1000*(4*38.9+4*8.8+9*2)/(38.9+8.8+2) %220;
        EdibleFreshBasisWaterContent = 0.9452 %0.94 % percentage of edible portion of crop that is made up of water -  % REF: http://ndb.nal.usda.gov/ndb/foods/show/3270
        InedibleFreshBasisWaterContent = 0.9 % percentage of inedible portion of crop that is made up of water
        CanopyClosureConstants
        CanopyQuantumYieldConstants
        LightCycleTemperature = 26      % in Celsius
        CarbohydrateFractionOfDryMass = 38.9/(38.9+8.8+2)   % REF: http://ndb.nal.usda.gov/ndb/foods/show/3270
        ProteinFractionOfDryMass = 8.8/(38.9+8.8+2)         % REF: http://ndb.nal.usda.gov/ndb/foods/show/3270
        FatFractionOfDryMass = 2/(38.9+8.8+2)               % REF: http://ndb.nal.usda.gov/ndb/foods/show/3270
    end
    
    methods
        %% Constructor
        function obj = Tomato%(cropArea,AirSource,AirSink)
            
            % Initialize Canopy Closure Constants
            canopyClosureConstants = zeros(1,25);
            canopyClosureConstants(1) = 6.2774E5;
            canopyClosureConstants(2) = 3.1724E3;
            canopyClosureConstants(7) = 24.281;
            canopyClosureConstants(11) = 0.44686;
            canopyClosureConstants(12) = 5.6276E-3;
            canopyClosureConstants(17) = -3.0690E-6;
            
            obj.CanopyClosureConstants = canopyClosureConstants;
            
            % Initialize Canopy Quantum Yield Constants
            canopyQYConstants = zeros(1,25);
            canopyQYConstants(7) = 4.0061E-2;
            canopyQYConstants(8) = 5.688E-5;
            canopyQYConstants(9) = -2.2598E-8;
            canopyQYConstants(13) = -1.182E-8;
            canopyQYConstants(14) = 5.0264E-12;
            canopyQYConstants(17) = -7.1241E-9;
            
            obj.CanopyQuantumYieldConstants = canopyQYConstants;

        end        
        
    end
    
end

