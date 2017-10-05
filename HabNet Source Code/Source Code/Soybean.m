classdef Soybean < handle
    %Rice Summary of this class goes here
    %   Detailed explanation goes here
    
    properties (SetAccess = private)
        Name = 'Soybean'
        Type = 'Legume'
        taInitialValue = 1200
        initialPPFValue = 800 %648.15       % per m^2 of crop area - adjusted from BioSim value to that listed in Table 1 of "Crop Models for Varying Envrionmental Conditions"
        initialCO2Value = 1200                % micromoles of CO2/moles of atmosphere
%         CarbonUseEfficiency24 = 0.64
        BCF = 0.46
        CUEmax = 0.65
        CUEmin = 0.3
        Photoperiod = 12                % days
        NominalPhotoperiod = 12         % days
        TimeAtOrganFormation = 46       % days
        N = 1.5
        CQYMin = 0.02;
        TimeAtCanopySenescence = 48     % days
        TimeAtCropMaturity = 86         % days
        OPF = 1.16;
        FractionOfEdibleBiomass = 0.95 %0.4 - Updated from BioSim value according to BVAD Table 4.2.28
        CaloriesPerKilogram = (1-0.0854)*1000*(4*301.6+4*364.9+9*199.4)/(301.6+364.9+199.4) %1340;
        EdibleFreshBasisWaterContent = 0.0854 %0.1 % percentage of edible portion of crop that is made up of water -  % REF: http://ndb.nal.usda.gov/ndb/foods/show/4828
        InedibleFreshBasisWaterContent = 0.9
        CanopyClosureConstants
        CanopyQuantumYieldConstants
        LightCycleTemperature = 26      % in Celsius
        CarbohydrateFractionOfDryMass = 301.6/(301.6+364.9+199.4)  % REF: http://ndb.nal.usda.gov/ndb/foods/show/4828
        ProteinFractionOfDryMass = 364.9/(301.6+364.9+199.4)       % REF: http://ndb.nal.usda.gov/ndb/foods/show/4828
        FatFractionOfDryMass = 199.4/(301.6+364.9+199.4)             % REF: http://ndb.nal.usda.gov/ndb/foods/show/4828
    end
    
    methods
        %% Constructor
        function obj = Soybean%(cropArea,AirSource,AirSink)
            
            % Initialize Canopy Closure Constants
            canopyClosureConstants = zeros(1,25);
            canopyClosureConstants(1) = 6.7978E6;
            canopyClosureConstants(2) = -4.3658E3;
            canopyClosureConstants(3) = 1.5573;
            canopyClosureConstants(6) = -4.326E4;
            canopyClosureConstants(7) = 33.959;
            canopyClosureConstants(11) = 112.63;
            canopyClosureConstants(14) = -4.911E-9;
            canopyClosureConstants(16) = -0.13637;
            canopyClosureConstants(21) = 6.6918E-5;
            canopyClosureConstants(22) = -2.1367E-8;
            canopyClosureConstants(23) = 1.5467E-11;
            
            obj.CanopyClosureConstants = canopyClosureConstants;
            
            % Initialize Canopy Quantum Yield Constants
            canopyQYConstants = zeros(1,25);
            canopyQYConstants(7) = 4.1513E-2;
            canopyQYConstants(8) = 5.1157E-5;
            canopyQYConstants(9) = -2.0992E-8;
            canopyQYConstants(13) = 4.0864E-8;
            canopyQYConstants(17) = -2.1582E-8;
            canopyQYConstants(18) = -1.0468E-10;
            canopyQYConstants(23) = 4.8541E-14;
            canopyQYConstants(25) = 3.9259E-21;
            
            obj.CanopyQuantumYieldConstants = canopyQYConstants;

        end        
        
    end
    
end

