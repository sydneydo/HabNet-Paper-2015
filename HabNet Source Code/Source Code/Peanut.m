classdef Peanut < handle%PlantImpl
    %Peanut Summary of this class goes here
    %   Detailed explanation goes here
    
    properties (SetAccess = private)
        Name = 'Peanut'
        Type = 'Legume'
        taInitialValue = 1200
        initialPPFValue = 600 %625       % per m^2 of crop area - adjusted from BioSim value to that listed in Table 1 of "Crop Models for Varying Envrionmental Conditions"
        initialCO2Value = 1200                % micromoles of CO2/moles of atmosphere
        BCF = 0.5 %0.6 - Updated from BioSim value according to BVAD Table 4.2.29
        CUEmax = 0.65
        CUEmin = 0.3
        Photoperiod = 12
        NominalPhotoperiod = 12
        TimeAtOrganFormation = 49
        N = 2
        CQYMin = 0.02;
        TimeAtCanopySenescence = 65
        TimeAtCropMaturity = 110 %104 - Updated from BioSim value according to BVAD Table 4.2.28
        OPF = 1.19;
        FractionOfEdibleBiomass = 0.49 %0.25 - Updated from BioSim value according to BVAD Table 4.2.28
        CaloriesPerKilogram = (1-0.0639)*1000*(4*158.2+4*261.5+9*496)/(158.2+261.5+496) %5680;
        EdibleFreshBasisWaterContent = 0.0639 %0.056 % percentage of edible portion of crop that is made up of water -  % REF: http://ndb.nal.usda.gov/ndb/foods/show/4812
        InedibleFreshBasisWaterContent = 0.9    % percentage of inedible portion of crop that is made up of water
        CanopyClosureConstants
        CanopyQuantumYieldConstants
        LightCycleTemperature = 26      % in Celsius
        CarbohydrateFractionOfDryMass = 158.2/(158.2+261.5+496)  % REF: http://ndb.nal.usda.gov/ndb/foods/show/4812
        ProteinFractionOfDryMass = 261.5/(158.2+261.5+496)       % REF: http://ndb.nal.usda.gov/ndb/foods/show/4812
        FatFractionOfDryMass = 496/(158.2+261.5+496)             % REF: http://ndb.nal.usda.gov/ndb/foods/show/4812
    end
    
    methods
        %% Constructor
        function obj = Peanut%(cropArea,AirSource,AirSink)
            
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
            canopyClosureConstants(1) = 3.7487E6;
            canopyClosureConstants(2) = 2.9200E3;
            canopyClosureConstants(5) = 9.4008E-8;
            canopyClosureConstants(6) = -1.8840E4;
            canopyClosureConstants(7) = 23.912;
            canopyClosureConstants(11) = 51.256;
            canopyClosureConstants(16) = -0.05963;
            canopyClosureConstants(17) = 5.5180E-6;
            canopyClosureConstants(21) = 2.5969E-5;
            
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

