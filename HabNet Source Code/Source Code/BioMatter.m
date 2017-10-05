classdef BioMatter
    %BioMatter Summary of this class goes here
    %   Note that this is originally an IDL type file
    %   BioMatter represents crops that have been sent to the biomass
    %   store by the BiomassPSImpl
    %   The FoodProcessor takes BioMatter from the Biomass store and
    %   converts to FoodMatter, which is then sent to the FoodStore
    %   CrewPersons consume food directly from the FoodStore
    
    properties
        Type            % PlantType
        Mass
        InedibleFraction        % Mass fraction
        EdibleWaterContent      % Mass of edible water content
        InedibleWaterContent    % Mass of inedible water content
    end
    
    methods
        function obj = BioMatter(type,mass,inedibleFraction,edibleWaterContent,inedibleWaterContent)
            if nargin > 0
                obj.Type = type;
                obj.Mass = mass;
                obj.InedibleFraction = inedibleFraction;
                obj.EdibleWaterContent = edibleWaterContent;
                obj.InedibleWaterContent = inedibleWaterContent;
            end
        end
    end
    
end

