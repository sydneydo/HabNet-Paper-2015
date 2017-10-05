classdef WhitePotato < handle%PlantImpl
    %WhitePotato Summary of this class goes here
    %   Detailed explanation goes here
    
    properties (SetAccess = private)
        Name = 'White Potato'
        Type = 'Planophile'
        taInitialValue = 1200
        initialPPFValue = 655;%648.15       % in micromoles/m^2/s - adjusted from BioSim value to that listed in Table 1 of "Crop Models for Varying Envrionmental Conditions"
        initialCO2Value = 1200                % micromoles of CO2/moles of atmosphere
        CarbonUseEfficiency24 = 0.625
        BCF = 0.41
        CUEmax = 0.625
        CUEmin = 0
        Photoperiod = 12
        NominalPhotoperiod = 12
        TimeAtOrganFormation = 45
        N = 2
        CQYMin = 0.02;
        TimeAtCanopySenescence = 75
        TimeAtCropMaturity = 138;%132   % Changed to 138 to match the value within Table 4.2.28 of BVAD
        OPF = 1.02;
        FractionOfEdibleBiomass = 1 %0.3   % referred to as XFRT (Fraction of daily carbon gain allocated to edible biomass after t_E) within BVAD Table 4.2.14, changed to a value of 1 according to BVAD Table 4.2.28 (0.3 was the value used within BioSim)
        CaloriesPerKilogram = (1-0.8158)*1000*(4*157.1+4*16.8+9*1)/(157.1+16.8+1) %760;
        EdibleFreshBasisWaterContent = 0.8158  % percentage of edible portion of crop that is made up of water -  % REF: http://ndb.nal.usda.gov/ndb/foods/show/3129
        InedibleFreshBasisWaterContent = 0.9 % percentage of inedible portion of crop that is made up of water
        CanopyClosureConstants
        CanopyQuantumYieldConstants
        LightCycleTemperature = 20      % in Celsius
        CarbohydrateFractionOfDryMass = 157.1/(157.1+16.8+1)  % REF: http://ndb.nal.usda.gov/ndb/foods/show/3129
        ProteinFractionOfDryMass = 16.8/(157.1+16.8+1)       % REF: http://ndb.nal.usda.gov/ndb/foods/show/3129
        FatFractionOfDryMass = 1/(157.1+16.8+1)             % REF: http://ndb.nal.usda.gov/ndb/foods/show/3129
    end
    
    methods
        %% Constructor
        function obj = WhitePotato%(cropArea,AirSource,AirSink)
            
            % Initialize Canopy Closure Constants
            canopyClosureConstants = zeros(1,25);
            canopyClosureConstants(1) = 6.5773E5;
            canopyClosureConstants(2) = 8.5626E3;
            canopyClosureConstants(12) = 0.042749;
            canopyClosureConstants(13) = 8.8437E-7;
            canopyClosureConstants(17) = -1.7905E-5;
            
            obj.CanopyClosureConstants = canopyClosureConstants;
            
            % Initialize Canopy Quantum Yield Constants
            canopyQYConstants = zeros(1,25);
            canopyQYConstants(7) = 4.6929E-2;
            canopyQYConstants(8) = 5.0910E-5;
            canopyQYConstants(9) = -2.1878E-8;
            canopyQYConstants(15) = 4.3976E-15;
            canopyQYConstants(18) = -1.5272E-11;
            canopyQYConstants(22) = -1.9602E-11;
            
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

