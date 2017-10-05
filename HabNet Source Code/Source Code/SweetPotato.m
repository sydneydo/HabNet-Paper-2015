classdef SweetPotato < handle
    %Rice Summary of this class goes here
    %   Detailed explanation goes here
    
    properties (SetAccess = private)
        Name = 'Sweet Potato'
        Type = 'Planophile'
        taInitialValue = 1200
        initialPPFValue = 600 %432.1       % per m^2 of crop area - adjusted from BioSim value to that listed in Table 1 of "Crop Models for Varying Envrionmental Conditions"
        initialCO2Value = 1200                % micromoles of CO2/moles of atmosphere
        CarbonUseEfficiency24 = 0.625
        BCF = 0.44 %0.41 - Updated from BioSim value according to BVAD Table 4.2.29
        CUEmax = 0.625
        CUEmin = 0
        Photoperiod = 12                % days
        NominalPhotoperiod = 18         % days
        TimeAtOrganFormation = 33       % days
        N = 1.5
        CQYMin = 0;
        TimeAtCanopySenescence = 121     % days
        TimeAtCropMaturity = 120 %85         % days - Updated from BioSim value according to BVAD Table 4.2.28
        OPF = 1.02;
        FractionOfEdibleBiomass = 1 %0.4 - Updated from BioSim value according to BVAD Table 4.2.28
        CaloriesPerKilogram = (1-0.7728)*1000*(4*201.2+4*15.7+9*0.5)/(201.2+15.7+0.5) %1140;
        EdibleFreshBasisWaterContent = 0.7728 %0.71 % percentage of edible portion of crop that is made up of water -  % REF: http://ndb.nal.usda.gov/ndb/foods/show/3254
        InedibleFreshBasisWaterContent = 0.9 % percentage of inedible portion of crop that is made up of water
        CanopyClosureConstants
        CanopyQuantumYieldConstants
        LightCycleTemperature = 28      % in Celsius
        CarbohydrateFractionOfDryMass = 201.2/(201.2+15.7+0.5)  % REF: http://ndb.nal.usda.gov/ndb/foods/show/3254
        ProteinFractionOfDryMass = 15.7/(201.2+15.7+0.5)       % REF: http://ndb.nal.usda.gov/ndb/foods/show/3254
        FatFractionOfDryMass = 0.5/(201.2+15.7+0.5)             % REF: http://ndb.nal.usda.gov/ndb/foods/show/3254
    end
    
    methods
        %% Constructor
        function obj = SweetPotato%(cropArea,AirSource,AirSink)
            
            % Initialize Canopy Closure Constants
            canopyClosureConstants = zeros(1,25);
            canopyClosureConstants(1) = 1.2070E6;
            canopyClosureConstants(2) = 4.9484E3;
            canopyClosureConstants(7) = 4.2978;
            canopyClosureConstants(21) = 4.0109E-7;
            canopyClosureConstants(23) = 2.0193E-12;
            
            obj.CanopyClosureConstants = canopyClosureConstants;
            
            % Initialize Canopy Quantum Yield Constants
            canopyQYConstants = zeros(1,25);
            canopyQYConstants(7) = 3.9317E-2;
            canopyQYConstants(8) = 5.6741E-5;
            canopyQYConstants(9) = -2.1797E-8;
            canopyQYConstants(12) = -1.3836E-5;
            canopyQYConstants(13) = -6.3397E-9;
            canopyQYConstants(18) = -1.3464E-11;
            canopyQYConstants(19) = 7.7362E-15;
            
            obj.CanopyQuantumYieldConstants = canopyQYConstants;

        end        
        
    end
    
end

