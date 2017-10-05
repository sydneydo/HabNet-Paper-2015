classdef Rice < handle
    %Rice Summary of this class goes here
    %   Detailed explanation goes here
    
    properties (SetAccess = private)
        Name = 'Rice'
        Type = 'Erectophile'
        taInitialValue = 1200
        initialPPFValue = 1200 %763.89       % per m^2 of crop area - adjusted from BioSim value to that listed in Table 1 of "Crop Models for Varying Envrionmental Conditions"
        initialCO2Value = 1200                % micromoles of CO2/moles of atmosphere
        CarbonUseEfficiency24 = 0.64
        BCF = 0.44 %0.45 - Updated from BioSim value according to BVAD Table 4.2.29
        Photoperiod = 12                % days
        NominalPhotoperiod = 12         % days
        TimeAtOrganFormation = 57       % days
        N = 1.5
        CQYMin = 0.01;
        TimeAtCanopySenescence = 61     % days
        TimeAtCropMaturity = 88 %85         % days - Updated from BioSim value according to BVAD Table 4.2.28
        OPF = 1.08;
        FractionOfEdibleBiomass = 0.98 %0.3 - Updated from BioSim value according to BVAD Table 4.2.28
        CaloriesPerKilogram = (1-0.1329)*1000*(4*791.5+4*65+9*5.2)/(791.5+65+5.2) %3630;
        EdibleFreshBasisWaterContent = 0.1329 %0.12 % percentage of edible portion of crop that is made up of water -  % REF: http://ndb.nal.usda.gov/ndb/foods/show/6397
        InedibleFreshBasisWaterContent = 0.9 % percentage of inedible portion of crop that is made up of water
        CanopyClosureConstants
        CanopyQuantumYieldConstants
        LightCycleTemperature = 29      % in Celsius
        CarbohydrateFractionOfDryMass = 791.5/(791.5+65+5.2)  % REF: http://ndb.nal.usda.gov/ndb/foods/show/6397
        ProteinFractionOfDryMass = 65/(791.5+65+5.2)          % REF: http://ndb.nal.usda.gov/ndb/foods/show/6397
        FatFractionOfDryMass = 5.2/(791.5+65+5.2)             % REF: http://ndb.nal.usda.gov/ndb/foods/show/6397
    end
    
    methods
        %% Constructor
        function obj = Rice%(cropArea,AirSource,AirSink)
            
            % Initialize Canopy Closure Constants
            canopyClosureConstants = zeros(1,25);
            canopyClosureConstants(1) = 6.5914E6;
            canopyClosureConstants(2) = 2.5776E4;
            canopyClosureConstants(4) = 6.4532E-3;
            canopyClosureConstants(6) = -3.748E3;
            canopyClosureConstants(8) = -0.043378;
            canopyClosureConstants(13) = 4.562E-5;
            canopyClosureConstants(17) = 4.5207E-6;
            canopyClosureConstants(18) = -1.4936E-8;
            
            obj.CanopyClosureConstants = canopyClosureConstants;
            
            % Initialize Canopy Quantum Yield Constants
            canopyQYConstants = zeros(1,25);
            canopyQYConstants(7) = 3.6186E-2;
            canopyQYConstants(8) = 6.1457E-5;
            canopyQYConstants(9) = -2.4322E-8;
            canopyQYConstants(13) = -9.1477E-9;
            canopyQYConstants(14) = 3.889E-12;
            canopyQYConstants(17) = -2.6712E-9;
            
            obj.CanopyQuantumYieldConstants = canopyQYConstants;

        end        
        
    end
    
end

