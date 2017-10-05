classdef FoodStoreImpl < handle
    %FoodStoreImpl Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        contents
        foodItems    % vector of FoodMatter objects
        currentLevel = 0;
        currentCapacity = 0;
        currentCalories = 0;
        resupplyFrequency = 0;
        resupplyAmount = 0;
        overflow     % vector of overflowed FoodMatter objects
    end
    
    methods
        function obj = FoodStoreImpl(initialcapacity,initialfoodItems)
            if nargin > 0
                
                obj.currentCapacity = initialcapacity;
                
                if nargin == 2
                
                    if ~(strcmpi(class(initialfoodItems),'FoodMatter'))
                        error('initialfoodItems must be of type "FoodMatter"')
                    end
                    
                    obj.foodItems = initialfoodItems;
                    obj.currentCalories = 0;
                    for i = 1:length(initialfoodItems)
                        obj.contents{i} = initialfoodItems(i).Type.Name;
                        obj.currentCalories = obj.currentCalories+initialfoodItems(i).CaloricContent;
                        obj.currentLevel = obj.currentLevel + initialfoodItems(i).Mass;     % Calculate initial level by summing mass of all fooditems
                    end
                end
            end
        end
       
        %% add
        function [actuallyAdded,obj] = add(obj,foodmatterRequested,resourceManagementDefinition)
            
            % Incorporate this if condition so that the function can handle
            % a varying number of inputs
            if nargin > 0
                finalFoodmatterRequested = foodmatterRequested;       % Initialize finalBiomatterRequested
            end
            
            % Find combined mass of foodmatterRequested (for the case that
            % it is a vector of length > 1)            
            massRequested = sum([foodmatterRequested.Mass]);
            
            % If resourceManagementDefinition is included 
            if nargin == 3
                % Select lowest flowrate, then add biomatter to store
                % accordingly 
                finalflowrate = min([massRequested,resourceManagementDefinition.DesiredFlowRate,...
                    resourceManagementDefinition.MaxFlowRate]);
            
                % if final flow rate doesn't equal to mass requested (ie
                % flow is limited by resourceManagementDefinition), we
                % adjust the foodmatterRequested vector to meet the flow
                % limitations (this is essentially like the take method)
                if finalflowrate ~= massRequested
%                     itemsToTake = [];
                    itemsToTake = FoodMatter.empty(0,length(foodmatterRequested));
                    collectedMass = 0;                    
                    for i = 1:length(foodmatterRequested)
                        massStillNeeded = finalflowrate-collectedMass;
                         % If mass of current FoodMatterItem does not meet
                         % massStillNeeded, we take all of it
                         if foodmatterRequested(i).Mass < massStillNeeded
%                              itemsToTake = [itemsToTake foodmatterRequested(i)];
                             itemsToTake(i) = foodmatterRequested(i);
                             collectedMass = collectedMass + foodmatterRequested(i).Mass;
                         else
                             % if mass of current FoodmatterItem is >=
                             % massStillNeeded, we cut it up and take only what is
                             % needed.
                             
                             % Portion of cut up FoodmatterItem to take
                             partialTakenItem = FoodMatter(foodmatterRequested(i).Type,massStillNeeded,...
                                 foodmatterRequested(i).WaterContent*massStillNeeded/foodmatterRequested(i).Mass);
                             
                             % Add partialTakenItem to list of FoodmatterItems to
                             % take
%                              itemsToTake = [itemsToTake partialTakenItem];
                             itemsToTake(i) = partialTakenItem;
                             
                             % Update collectedMass
                             collectedMass = collectedMass + partialTakenItem.Mass;
                             
                             % Determine amount sent to overflow
                             % Update current FoodmatterItem to reflect
                             % amount not sent to store
                             portionSentToOverflow = FoodMatter(foodmatterRequested(i).Type,...
                                 foodmatterRequested(i).Mass-partialTakenItem.Mass,...
                                 foodmatterRequested(i).WaterContent*partialTakenItem.WaterContent);
                             
                             % Add updated foodmatterRequested and all 
                             % remaining foodmatterItems (if any) to overflow
                             obj.overflow = [obj.overflow,portionSentToOverflow];
                             
                             if i < length(foodmatterRequested)
                                 for j = (i+1):length(foodmatterRequested)
                                     obj.overflow = [obj.overflow,foodmatterRequested(j)];
                                 end
                             end
                         end
                         
                         % Break out of loop if we've collected enough mass
                         if collectedMass >= finalflowrate
                             break
                         end
                    end
                    
                    % Define final FoodMatter array to add to FoodStore
                    finalFoodmatterRequested = itemsToTake;
                end
            end
                
            %% Add finalFoodmatterRequested to food store
            % Cycle through each element of finalFoodmatterRequested and
            % add
            actuallyAdded = 0;
            for i = 1:length(finalFoodmatterRequested)
                % If adding more than current capacity can hold (the basis
                % used here is mass, but maybe this should be volume)
                if finalFoodmatterRequested(i).Mass + obj.currentLevel > obj.currentCapacity
                    actuallyAdded = actuallyAdded + obj.currentCapacity - obj.currentLevel;     % add only until we reach capacity
                    
                    % Portion of current FoodmatterItem to take
                    partialAddedItem = FoodMatter(finalFoodmatterRequested(i).Type,obj.currentCapacity-obj.currentLevel,...
                        finalFoodmatterRequested(i).WaterContent*(obj.currentCapacity-obj.currentLevel)/finalFoodmatterRequested(i).Mass);
                    
                    % Add this to FoodStore
                    obj.foodItems = [obj.foodItems partialAddedItem];
                    obj.currentLevel = obj.currentLevel + partialAddedItem.Mass;                     % update currentLevel
                    obj.contents{length(obj.contents)+1} = partialAddedItem.Type.Name;
                    obj.currentCalories = obj.currentCalories + partialAddedItem.CaloricContent;
                    
                    % Determine amount sent to overflow
                    % Update current FoodmatterItem to reflect
                    % amount not sent to store
                    portionSentToOverflow = FoodMatter(finalFoodmatterRequested(i).Type,...
                        finalFoodmatterRequested(i).Mass-partialAddedItem.Mass,...
                        finalFoodmatterRequested(i).WaterContent-partialAddedItem.WaterContent);
                    
                    % Add updated foodmatterRequested and all
                    % remaining foodmatterItems (if any) to overflow
                    obj.overflow = [obj.overflow,portionSentToOverflow];
                    if i < length(finalFoodmatterRequested)
                        for j = (i+1):length(finalFoodmatterRequested)
                            obj.overflow = [obj.overflow,finalFoodmatterRequested(j)];
                        end
                    end
                    
                    % Break out of for loop
                    break
                else
                    % if store can hold mass of biomass requested to be added
                    actuallyAdded = actuallyAdded + finalFoodmatterRequested(i).Mass;
                    obj.foodItems = [obj.foodItems finalFoodmatterRequested(i)];
                    obj.currentLevel = obj.currentLevel + finalFoodmatterRequested(i).Mass;
                    obj.contents{length(obj.contents)+1} = finalFoodmatterRequested(i).Type.Name;
                    obj.currentCalories = obj.currentCalories + finalFoodmatterRequested(i).CaloricContent;
                end
            end
        end
        
        %% take
        function [foodTaken, obj] = takeFoodMatterCalories(obj,caloriesNeeded,limitingMass)
            
            if nargin == 2
                limitingMass = Inf;
            end
            
            % This function goes through each fooditem in the food store,
            % and progressively collects food to meet the desired calorie
            % and mass requirements. Note that the order in which fooditems
            % are listed in the foodStore drives the order in which they
            % are consumed
            % The aggregate amount of calories and mass taken from the
            % store is tracked in the collectedCalories and the
            % collectedMass variable. These are initialized as follows:
            collectedCalories = 0;
            collectedMass = 0;
            itemsToTake = FoodMatter.empty(0,length(obj.foodItems));    % Vector containing fooditems to return to store (used for store updating)
%             itemsToTake = [];     % Vector containing fooditems to return to store (used for store updating)
            itemsToDelete = zeros(1,length(obj.foodItems));
%             itemsToDelete = [];     % Vector containing fooditems to remove from store (used for store updating)
            
            count = 0;      % Counter for foodItems to delete
            
            % We now cycle through each foodItem within the foodstore:
            for i = 1:length(obj.foodItems)
                
                % Determine number of calories within current FoodMatter
                % foodItem = food mass*food energy density
                currentfoodItemCalories = obj.foodItems(i).CaloricContent;
                caloriesStillNeeded = caloriesNeeded - collectedCalories;   % Update amount of calories still needed to be taken from FoodStore

                % If you have more calories from obj.foodItems(i)
                % than the amount of calories still needed to be collected
                % (caloriesStillNeeded), or you have more food mass available to
                % be taken than what is needed:
                % take the lower of the calories needed, or the equivalent
                % limiting mass

                % pare down the amount of calories taken to
                % the amount needed first based on the limitingMass, then
                % by the amount of calories (if required)
                % More material in stores than material to be extracted
                if currentfoodItemCalories > caloriesStillNeeded ||...
                        (obj.foodItems(i).Mass + collectedMass) > limitingMass
                    
                    % Define by default, mass of current fooditem to remove
                    % from store as being all of the mass available, and
                    % calories of fooditem to remove from store as being
                    % all the calories currently available
                    massToRemove = obj.foodItems(i).Mass;
                    caloriesToRemove = currentfoodItemCalories;
                    
                    % If amount of mass of foodItem remaining > limitingMass
                    % (ie. the mass of food to take from store), reduce the
                    % amount of fooditem mass you want to take from the
                    % store
                    if massToRemove > limitingMass                   
                        % If we filter by mass, we need to calculate the
                        % amount of mass to remove, and calculate the
                        % corresponding calories that this equates to
                        % (this requires creating an equivalent FoodMatter
                        % object)
                        
                        flowRateMass = limitingMass - collectedMass;    % Remaining mass to remove from store
                        flowrateFractionOfOriginal = flowRateMass/obj.foodItems(i).Mass;    % Mass fraction of available foodItem mass to remove
                        
                        % Create a FoodMatter object represent the fooditem
                        % to remove from the food store
                        partialReturnedFoodMatter = FoodMatter(obj.foodItems(i).Type,flowRateMass,...
                            obj.foodItems(i).WaterContent*flowrateFractionOfOriginal);
                        % Calculate corresponding mass to remove
                        massToRemove = partialReturnedFoodMatter.Mass;
                        
                        % Equivalent amount of calories of newly created
                        % FoodMatter object
                        caloriesToRemove = partialReturnedFoodMatter.CaloricContent;
                        
                        % Calculate watercontent to remove
                        waterContentToRemove = partialReturnedFoodMatter.WaterContent;      
                    end
                    
                    % Apply second constraint - pare amount to take to
                    % level of calories if necessary
                    if caloriesToRemove > caloriesStillNeeded
                        % If we filter by calories, we automatically know
                        % how many calories to remove. The equivalent mass
                        % of these calories can be calculated by performing
                        % a linear scaling of the mass (since the caloric
                        % density is fixed)
                        
                        % Adjusted amount of FoodItems to keep in
                        % FoodStore
                        fractionOfMassToKeepForCalories = (caloriesToRemove-caloriesStillNeeded)/...
                            caloriesToRemove;
                        % Update mass to remove based on linear assumption (which
                        % equates to a homogenous mixture assumption)                       
                        massToRemove = (1-fractionOfMassToKeepForCalories)*...
                            massToRemove;
                        
                        caloriesToRemove = caloriesStillNeeded;
                        
                        waterContentToRemove = massToRemove/obj.foodItems(i).Mass*...
                            obj.foodItems(i).WaterContent;
                        
                        % Create corresponding FoodMatter object to represent
                        % FoodItems removed
                        partialReturnedFoodMatter = FoodMatter(obj.foodItems(i).Type,...
                            massToRemove,waterContentToRemove);
                    end
                    
                    % Add newly created FoodMatter object to itemsToTake
                    % vector, signifying FoodItems taken from FoodStore
%                     itemsToTake = [itemsToTake partialReturnedFoodMatter];
                    itemsToTake(i) = partialReturnedFoodMatter;
                    
                    % Update contents within foodItem store
                    obj.foodItems(i).Mass = obj.foodItems(i).Mass - massToRemove;
                    obj.currentLevel = obj.currentLevel - massToRemove;
                    obj.foodItems(i).WaterContent = obj.foodItems(i).WaterContent - waterContentToRemove;
                    obj.foodItems(i).CaloricContent = obj.foodItems(i).CaloricContent - caloriesToRemove;
                    obj.currentCalories = obj.currentCalories - caloriesToRemove;
                    
                    % Remove fooditem altogether if its mass is <= 0
                    if obj.foodItems(i).Mass <= 0
%                         itemsToDelete = [itemsToDelete i];
                        count = count+1;
                        itemsToDelete(count) = i;
                    end
                    
                    % Update total mass and calories collected
                    collectedMass = collectedMass + massToRemove;
                    collectedCalories = collectedCalories + caloriesToRemove;
                    
                %% Else if insufficient calories of current FoodItem available
                % within FoodStore but too much mass, pare down mass flow
                % rate to meet consumption limit (limitingMass)
                elseif currentfoodItemCalories <= caloriesStillNeeded &&...
                        (obj.foodItems(i).Mass + collectedMass) > limitingMass
                    flowRateMass = limitingMass - collectedMass;    % Remaining mass to remove from store
                    flowrateFractionOfOriginal = flowRateMass/obj.foodItems(i).Mass;    % Mass fraction of available foodItem mass to remove
                    
                    % Create a FoodMatter object represent the fooditem
                    % to remove from the food store
                    paredToFlowrateFoodMatter = FoodMatter(obj.foodItems(i).Type,flowRateMass,...
                        obj.foodItems(i).WaterContent*flowrateFractionOfOriginal);
                    
                    % Add new FoodItem to itemsToTake vector
%                     itemsToTake = [itemsToTake paredToFlowrateFoodMatter];
                    itemsToTake(i) = paredToFlowrateFoodMatter;
                    
                    % Update amount of mass of FoodItem still within store
                    obj.foodItems(i).Mass = obj.foodItems(i).Mass - paredToFlowrateFoodMatter.Mass;
                    obj.currentLevel = obj.currentLevel - paredToFlowrateFoodMatter.Mass;
                    obj.foodItems(i).CaloricContent = obj.foodItems(i).CaloricContent - paredToFlowrateFoodMatter.CaloricContent;
                    obj.currentCalories = obj.currentCalories - paredToFlowrateFoodMatter.CaloricContent;
                    
                    % Remove fooditem altogether if its mass is <= 0
                    if obj.foodItems(i).Mass <= 0
%                         itemsToDelete = [itemsToDelete i];
                        count = count+1;
                        itemsToDelete(count) = i;
                    end
                    
                    % Update total mass and calories collected (check the logic of this!)
                    collectedMass = collectedMass + paredToFlowrateFoodMatter.Mass;
                    collectedCalories = collectedCalories + paredToFlowrateFoodMatter.CaloricContent;

                %% Else if too many calories of current FoodItem available
                % within FoodStore but too little mass, pare down to
                % required calories
                elseif currentfoodItemCalories > caloriesStillNeeded &&...
                        (obj.foodItems(i).Mass + collectedMass) <= limitingMass
                    
                    % Adjusted amount of FoodItems to remove from
                    % FoodStore
                    fractionOfMassToKeepForCalories = (currentfoodItemCalories-caloriesStillNeeded)/...
                        currentfoodItemCalories;
                    %% Update mass to remove based on linear assumption (which
                    % equates to a homogenous mixture assumption)
                    massToRemove = (1-fractionOfMassToKeepForCalories)*...
                        obj.foodItems(i).Mass;  % Mass to remove from store
                    
                    waterContentToRemove = massToRemove/obj.foodItems(i).Mass*...
                        obj.foodItems(i).WaterContent;
                    
                    caloriesToRemove = caloriesStillNeeded;
                    
                    % Create corresponding FoodMatter object to represent
                    % FoodItems removed
                    partialReturnedFoodMatter = FoodMatter(obj.foodItems(i).Type,...
                        massToRemove,waterContentToRemove);

                    % Add newly created FoodMatter object to itemsToTake
                    % vector, signifying FoodItems taken from FoodStore
%                     itemsToTake = [itemsToTake partialReturnedFoodMatter];
                    itemsToTake(i) = partialReturnedFoodMatter;
                    
                    % Update contents within foodItem store
                    obj.foodItems(i).Mass = obj.foodItems(i).Mass - massToRemove;
                    obj.currentLevel = obj.currentLevel - massToRemove;
                    obj.foodItems(i).WaterContent = obj.foodItems(i).WaterContent - waterContentToRemove;
                    obj.foodItems(i).CaloricContent = obj.foodItems(i).CaloricContent - caloriesToRemove;
                    obj.currentCalories = obj.currentCalories - caloriesToRemove;
                                     
                    % Remove fooditem altogether if its mass is <= 0
                    if obj.foodItems(i).Mass <= 0
%                         itemsToDelete = [itemsToDelete i];
                        count = count+1;
                        itemsToDelete(count) = i;
                    end
                    
                    % Update total mass and calories collected
                    collectedMass = collectedMass + massToRemove;
                    collectedCalories = collectedCalories + caloriesToRemove;
                    
                %% Else if we have insufficient calories and insufficient
                % food mass, just take all of the current food item
                else
%                     itemsToTake = [itemsToTake obj.foodItems(i)];   % Append items to take from store vector
                    itemsToTake(i) = obj.foodItems(i);   % Append items to take from store vector
%                     itemsToDelete = [itemsToDelete i];   % Append items to vector of items to remove from foodstore
                    count = count+1;
                    itemsToDelete(count) = i;
                    
                    obj.currentLevel = obj.currentLevel - obj.foodItems(i).Mass;    % Update aggregate level in store
                    obj.currentCalories = obj.currentCalories - obj.foodItems(i).CaloricContent;    % Update aggregate calories in store
                    
                    collectedMass = collectedMass + obj.foodItems(i).Mass;
                    collectedCalories = collectedCalories + obj.foodItems(i).CaloricContent;     
                end   
                
                %% Break out of loop if we have taken sufficient items from FoodStore
                if collectedCalories >= caloriesNeeded ||...
                        collectedMass >= limitingMass
                    % break out of for loop and define output variables
                    break
                end
                
            end
            
            %% Remove Identified Items from FoodStore
            % remove trailing zeros from itemsToDelete
            itemsToDelete = itemsToDelete(1:find(itemsToDelete,1,'last'));
            obj.foodItems(itemsToDelete) = [];
            obj.contents(itemsToDelete) = [];
            % no update to obj.contents is currently incorporated
            
            
            %% Define output variables here
            foodTaken = itemsToTake;
        end

        %% sortContents
        % function to aggregate biomatter of the same type together within
        % the Biomass store
        function obj = sortContents(obj)
            
            % break out of function if we only have one element within
            % obj.biomatterItems
            if length(obj.foodItems) == 1
                return
            end
            
            % determine number of unique biomatter types currently within
            % Biomass store
            [uniqueFoodmatter, ~, allIndices] = unique(obj.contents,'stable');
            [orderedIndices, orderedPositions] = sort(allIndices);
            reorderedFoodmatterItems = obj.foodItems(orderedPositions);
            
            %            j = 1;       % Index of orderBiomatterItems vector
            orderedFoodmatter = [];   % initialize orderedBiomatter vector
            mass = reorderedFoodmatterItems(1).Mass;
            waterContent = reorderedFoodmatterItems(1).WaterContent;
            
            % cycle through reorderedBiomatterItems and
            for i = 2:length(reorderedFoodmatterItems)
                %                currentindex = orderedIndices(i);
                
                % if consecutive indices within reorderedBiomatterItems are the same
                if orderedIndices(i-1) == orderedIndices(i)
                    mass = mass + reorderedFoodmatterItems(i).Mass;
                    waterContent = waterContent + reorderedFoodmatterItems(i).WaterContent;
                else
                    % if consecutive indices are different
                    % store aggregated foodmatter into orderedFoodmatter
                    orderedFoodmatter = [orderedFoodmatter,...
                        FoodMatter(reorderedFoodmatterItems(i-1).Type,mass,waterContent)];
                    
                    % Set variables to correspond to current biomatter item
                    mass = reorderedFoodmatterItems(i).Mass;
                    waterContent = reorderedFoodmatterItems(i).WaterContent;
                end
            end
            
            % Append final biomatter object to orderedBiomatter vector
            orderedFoodmatter = [orderedFoodmatter,...
                FoodMatter(reorderedFoodmatterItems(i).Type,mass,waterContent)];
            
            % store orderedBiomatter within obj.biomatterItems
            obj.foodItems = orderedFoodmatter;
            obj.contents = uniqueFoodmatter;
            
        end
        
    end
    
%     methods (Static)
%         function calories = calculateCalories(fooditem)
%             % Enforce input as being of type "FoodMatter"
%             if ~(strcmpi(class(fooditem),'FoodMatter'))
%                 error('Input to calculateCalories must be of type "FoodMatter"')
%             end
%             % Calories = food mass (kg) * food energy density (calories/kg)
%             calories = fooditem.Mass * fooditem.Type.CaloriesPerKilogram;
%         end
%     end
    
end

