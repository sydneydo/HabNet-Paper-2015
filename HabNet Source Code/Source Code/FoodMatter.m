classdef FoodMatter %< handle
    %FoodMatter Summary of this class goes here
    %   Note tha thtis is originally an IDL type file
    
    properties
        Type            % PlantType
        Mass
        WaterContent
        CarbohydrateContent     % in kg
        ProteinContent          % in kg
        FatContent              % in kg
        CaloricContent
    end
    
    properties (Access = private)
       CarbohydrateCaloriesPerGram = 4  % 4 kilocalories per gram of fat    
       ProteinCaloriesPerGram = 4       % 4 kilocalories per gram of fat
       FatCaloriesPerGram = 9           % 9 kilocalories per gram of fat
    end
    
    methods
        function obj = FoodMatter(type,mass,watercontent)
            if nargin > 0
                obj.Type = type;
                obj.Mass = mass;
                obj.WaterContent = watercontent;    % in kg
%                 obj.CaloricContent = type.CaloriesPerKilogram * mass;
                obj.CarbohydrateContent = type.CarbohydrateFractionOfDryMass*(mass-watercontent);   % Fraction of dry mass
                obj.ProteinContent = type.ProteinFractionOfDryMass*(mass-watercontent);   % Fraction of dry mass
                obj.FatContent = type.FatFractionOfDryMass*(mass-watercontent);   % Fraction of dry mass
                obj.CaloricContent = (mass-watercontent)*1E3*(type.CarbohydrateFractionOfDryMass*obj.CarbohydrateCaloriesPerGram+...
                    type.ProteinFractionOfDryMass*obj.ProteinCaloriesPerGram+...
                    type.FatFractionOfDryMass*obj.FatCaloriesPerGram);
            end
        end
    end
    
end

