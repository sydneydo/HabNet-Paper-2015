classdef FoodProcessorImpl < handle
    %FoodProcessorImpl Summary of this class goes here
    %   By: Sydney Do (sydneydo@mit.edu)
    %   Date Created: 6/8/2014
    %   Last Updated: 6/19/2014
    
    properties
        BiomassConsumerDefinition
        PowerConsumerDefinition
        FoodProducerDefinition
        WaterProducerDefinition         % Is this combined water? rather than potable, grey , or dirty?
        DryWasteProducerDefinition
    end
    
    properties (SetAccess = private)
        hasEnoughPower = 0          % flag to determine if the food processor has enough power to function nominally
        hasEnoughBiomass = 0        % flag to determine if the food processor has enough biomass to function nominally
        massConsumed = 0            % in kg - biomass consumed during the current tick
        currentPowerConsumed = 0    % in Watts - power consumed during the current tick
        currentFoodProduced = 0     % in kg - food produced during the current tick
        biomatterConsumed           % array of biomatter objects referring to what is consumed by the food processor
    end
    
    properties (Access = private)
        biomassNeeded = 200         % (according to BioSim code comments) - During any given tick, this much biomass is needed for the food processor to run optimally - currently this flag has no real influence on the performance of the Food Processor
        powerNeeded = 100;          % (according to BioSim code comments) - During any given tick, this much power is needed for the food processor to run at all
        ProductionRate = 1
    end
    
    methods
        %% Constructor
        function obj = FoodProcessorImpl
            obj.BiomassConsumerDefinition = ResourceUseDefinitionImpl;
            obj.PowerConsumerDefinition = ResourceUseDefinitionImpl;
            obj.FoodProducerDefinition = ResourceUseDefinitionImpl;
            obj.WaterProducerDefinition = ResourceUseDefinitionImpl;
            obj.DryWasteProducerDefinition = ResourceUseDefinitionImpl;
        end
           
        %% tick
        function tick(obj)
            %   From BioSim source code:
            %   When ticked, the Food Processor does the following: 1) attempts to
            %   collect references to various server (if not already done). 2) consumes
            %   power and biomass. 3) creates food (if possible)
            obj.massConsumed = 0;           % Reset biomass consumed during this tick
%             obj.currentFoodProduced = 0;    % Reset mass of food produced during this tick
%             obj.currentPowerConsumed = 0;   % Reset power consumed during this tick

           %% gatherPower
           obj.currentPowerConsumed = obj.PowerConsumerDefinition.ResourceStore.take(obj.powerNeeded,obj.PowerConsumerDefinition);     % Take power
           % Could probably save power use by putting a controller on when
           % food processor is turned on - since it currently consumes power
           % every tick
           
           % if has enough power
           if obj.currentPowerConsumed >= obj.powerNeeded
               
               %% gatherBiomass
               obj.biomatterConsumed = obj.BiomassConsumerDefinition.ResourceStore.take(obj.biomassNeeded,obj.BiomassConsumerDefinition);   % Take biomass from biomass store
                              
               %% createFood
               % If nothing is obtained from the Biomass Store, break out
               % of method and return a zero value for currentFoodProduced
               if isempty(obj.biomatterConsumed)
                   return
               end
               
               % Initialize empty foodMatterArray
               foodMatterArray = FoodMatter.empty(length(obj.biomatterConsumed),0);
%                biomatterMassConsumed = 0;   % Initialize variable to track mass of biomatter consumed
%                currentWaterProduced = 0;    % Initialize variable to track water produced by Food Processor

               % Transform BioMatter to FoodMatter
               for i = 1:length(obj.biomatterConsumed)
                   if obj.biomatterConsumed(i).InedibleFraction > 0
%                        foodMass = obj.biomatterConsumed(i).Mass*(1-obj.biomatterConsumed(i).InedibleFraction);       % Only take edible portion of Biomatter
                       foodMatterArray(i)= FoodMatter(obj.biomatterConsumed(i).Type,...
                           obj.biomatterConsumed(i).Mass*(1-obj.biomatterConsumed(i).InedibleFraction),...
                           obj.biomatterConsumed(i).EdibleWaterContent);  % We explicitly leave out the ProductionRate multiplier on foodMass
                   else
%                        foodMass = obj.biomatterConsumed(i).Mass;
                       foodMatterArray(i)= FoodMatter(obj.biomatterConsumed(i).Type,...
                           obj.biomatterConsumed(i).Mass,...
                           obj.biomatterConsumed(i).EdibleWaterContent);  % We explicitly leave out the ProductionRate multiplier on foodMass
                   end
                   
%                    foodMatterArray(i) = transformBiomatter(obj.biomatterConsumed(i));
               end
               
               biomatterMassConsumed = sum(cell2mat({obj.biomatterConsumed.Mass}));     % Sum masses of individual biomatterConsumed objects
               currentWaterProduced = sum(cell2mat({obj.biomatterConsumed.InedibleWaterContent}));  % Sum inedibleWaterContent of individual biomatterConsumed objects
               obj.currentFoodProduced = sum(cell2mat({foodMatterArray.Mass}));     % Total mass of foodmatter produced
               
               % Push food to FoodStore
               obj.FoodProducerDefinition.ResourceStore.add(foodMatterArray,obj.FoodProducerDefinition);
               
               % Send waste to dry waste store
               % Note: Waste = Mass of Biomatter Consumed - Mass of Food
               % Produced
               obj.DryWasteProducerDefinition.ResourceStore.add(biomatterMassConsumed - obj.currentFoodProduced,...
                    obj.DryWasteProducerDefinition);    % Note that Biosim has the subtraction equation the other way around
                
               % Send water to water store (potentially the store that is
               % the input to the WaterRS?
               obj.WaterProducerDefinition.ResourceStore.add(currentWaterProduced,obj.WaterProducerDefinition);     % Note that water here is in kg (from BioMatter defn)
               
           end
           
        end
    end
    
%     %% Static Methods
%     methods (Static)
%         function foodMatter = transformBiomatter(bioMatter)
%                         
%             if bioMatter.InedibleFraction > 0
%                 foodMass = bioMatter.Mass*(1-bioMatter.InedibleFraction);       % Only take edible portion of Biomatter
%             else
%                 foodMass = bioMatter.Mass;
%             end
%             
%             % Create New FoodMatter
%             foodMatter = FoodMatter(bioMatter.Type,foodMass,bioMatter.EdibleWaterContent);  % We explicitly leave out the ProductionRate multiplier on foodMass
%         end
%     end
    
end

