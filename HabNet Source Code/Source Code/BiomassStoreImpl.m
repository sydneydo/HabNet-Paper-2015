classdef BiomassStoreImpl < handle
    %BiomassStoreImpl Summary of this class goes here
    %   By: Sydney Do (sydneydo@mit.edu)
    %   Date Created: 6/8/2014
    %   Last Updated: 6/8/2014
    %
    %   This class file represents a biomass store. This holds the output
    %   of the Biomass Production system, before sending it to a food
    %   processor for conversion into edible food
    
    properties
        contents            % list of names of BioMatter objects
        biomatterItems      % vector of BioMatter objects
        currentCapacity
        currentLevel = 0
        overflow = 0
        resupplyFrequency = 0
        resupplyAmount = 0
    end
    
    methods
        %% Constructor
        function obj = BiomassStoreImpl(initialcapacity,initialfoodItems)
            if nargin > 0

                obj.currentCapacity = initialcapacity;
                
                if nargin == 2
                
                    if ~(strcmpi(class(initialfoodItems),'BioMatter'))
                        error('initialfoodItems must be of type "BioMatter"')
                    end
                    
                    for i = 1:length(initialfoodItems)
                        
                        obj.currentLevel = obj.currentLevel + initialfoodItems(i).Mass;     % Calculate initial level by summing mass of all fooditems
                        if obj.currentLevel > obj.currentCapacity
                            
                            warning('Warning: total contents of initialfoodItems exceeds declared capacity of store')
                            disp({'Warning: total contents of initialfoodItems exceeds declared capacity of store';...
                                ['Only ',obj.contents,' added']});
                            %                         error('total contents of initialfoodItems exceeds declared capacity of store');
                            break
                        end
                        
                        obj.biomatterItems = [obj.biomatterItems, initialfoodItems(i)];
                        obj.contents{i} = initialfoodItems(i).Type.Name;
                    end
                end

            end
        end
        
        %% takeBiomatterMass
        % This function takes biomatter out of the store according to a
        % mass of biomatter requested
        % The primary use of this method is within the FoodProcessorImpl
        % class file
        function biomatterTaken = take(obj,massRequested,resourceManagementDefinition)
            % This function goes through each biomatter item in the biomassStore,
            % and progressively collects biomatter to meet the desired 
            % mass requirements. Note that the order in which biomatter items
            % are listed in the biomassStore drives the order in which they
            % are consumed
            % The aggregate amount of mass taken from the store is tracked 
            % in the collectedMass variable. These are initialized as follows:
            collectedMass = 0;
%             itemsToTake = [];       % Vector containing biomatter items to return to consumer (used for store updating)
            itemsToTake = BioMatter.empty(0,length(obj.biomatterItems));        % Length of itemsToTake can't be more than the number of biomatterItems currently available
            j = 0;      % Counter for items to take
%             itemsToDelete = [];
            itemsToDelete = zeros(1,length(obj.biomatterItems));     % Vector containing indexes of biomatter items to remove from store (used for store updating)
            
            % Ensure that request is always for positive amounts
            if massRequested < 0
                biomatterTaken = [];
                return
            end
            
            % Determine final mass to take based on resource consumer flow
            % rate limitations
            if nargin == 2
                finalMassRequested = massRequested;
            elseif nargin == 3
                finalMassRequested = min([massRequested,resourceManagementDefinition.DesiredFlowRate,...
                    resourceManagementDefinition.MaxFlowRate]);
            end
            
            % Cycle through biomatterItems within biomass store and take
            % biomatter
            for i = 1:length(obj.biomatterItems)
                massStillNeeded = finalMassRequested - collectedMass;
                
                % If mass of current biomatterItem does not meet
                % massStillNeeded, we take all of it
                if obj.biomatterItems(i).Mass < massStillNeeded
                    j = j+1;
%                     itemsToTake = [itemsToTake obj.biomatterItems(i)];
                    itemsToTake(j) = obj.biomatterItems(i);
%                     itemsToDelete = [itemsToDelete i];          % increase efficiency in the future by preallocating array to a certain length and shrinking it at the end
                    itemsToDelete(j) = i;
                    collectedMass = collectedMass + obj.biomatterItems(i).Mass;     % Update collected mass
                else
                    % if mass of current biomatterItem is >=
                    % massStillNeeded, we cut it up and take only what is
                    % needed. We return the rest to the biomass Store
%                     fractionOfOriginal = massStillNeeded/obj.biomatterItems(i);
                    
                    % Portion of cut up biomatterItem to take
                    partialTakenItem = BioMatter(obj.biomatterItems(i).Type,massStillNeeded,...
                        obj.biomatterItems(i).InedibleFraction,...
                        obj.biomatterItems(i).EdibleWaterContent*massStillNeeded/obj.biomatterItems(i).Mass,...
                        obj.biomatterItems(i).InedibleWaterContent*massStillNeeded/obj.biomatterItems(i).Mass);
                    
                    % Add partialTakenItem to list of biomatterItems to
                    % take
                    j = j+1;
%                     itemsToTake = [itemsToTake partialTakenItem];
                    itemsToTake(j) = partialTakenItem;
                    
                    % Update current biomatterItem mass, edible and
                    % inedible water content
                    obj.biomatterItems(i).EdibleWaterContent = obj.biomatterItems(i).EdibleWaterContent*(1-massStillNeeded/obj.biomatterItems(i).Mass);
                    obj.biomatterItems(i).InedibleWaterContent = obj.biomatterItems(i).InedibleWaterContent*(1-massStillNeeded/obj.biomatterItems(i).Mass);
                    % Note that to replicate the results of BioSim, comment
                    % out the above line!
                    obj.biomatterItems(i).Mass = obj.biomatterItems(i).Mass-massStillNeeded;
                    
                    % if updated current biomatterItem mass is zero, add it
                    % to the list of biomatterItems to remove from the
                    % biomassStore
                    if obj.biomatterItems(i).Mass <= 0
                        itemsToDelete(j) = i;       % Note that j has already been updated earlier for this condition
                    end
                    
                    % Update collectedMass
                    collectedMass = collectedMass + partialTakenItem.Mass;
                    
                end
                
                % Break out of loop if we've collected enough mass
                if collectedMass >= finalMassRequested
                    break
                end
               
            end
            
            % Remove Identified Items from BiomassStore
            itemsToDelete = itemsToDelete(1:find(itemsToDelete,1,'last'));      % Remove trailing zeros from itemsToDelete vector
            obj.biomatterItems(itemsToDelete) = [];
            obj.contents(itemsToDelete) = [];          
                        
            % Update currentLevel of BiomassStore
            for i = 1:length(itemsToTake)
                obj.currentLevel = obj.currentLevel - itemsToTake(i).Mass;
            end
            
            % Define output variables
            biomatterTaken = itemsToTake;   % this is a vector of biomatter items. Note that the total mass of biomatter within this vector may be less than that originally requested
        end

        %% addBiomatter
        % used within
        % BiomassProducerDefinitionImpl.pushFractionalResourceToBiomassStore
        % within the BioSim Java implementation, this assumes that the
        % input to this method is of type BioMatter
        
        % Note that as is, this method can only take in one BioMatter Item
        % at a time. FoodStore has a means to account for this
        function [actuallyAdded, obj] = add(obj,biomatterRequested,resourceManagementDefinition)
            
            % Ensure that input is always a positive value
            if length(biomatterRequested) < 0
                actuallyAdded = [];
                return
            end
            
            % Incorporate this if condition so that the function can handle
            % a varying number of inputs
            if nargin > 0
                finalBiomatterRequested = biomatterRequested;       % Initialize finalBiomatterRequested
            end
            
            % If resourceManagementDefinition is included 
            if nargin == 3
                % Select lowest flowrate, then add biomatter to store
                % accordingly
                finalflowrate = min([biomatterRequested.Mass,resourceManagementDefinition.DesiredFlowRate,...
                    resourceManagementDefinition.MaxFlowRate]);
            
                if finalflowrate ~= biomatterRequested.Mass
                    % Create new biomatter object corresponding to the original
                    % Biomatter requested, scaled down to the finalflowrate
                    finalBiomatterRequested = BioMatter(biomatterRequested.Type,finalflowrate,...
                        biomatterRequested.InedibleFraction,...
                        biomatterRequested.EdibleWaterContent*finalflowrate/biomatterRequested.Mass,...
                        biomatterRequested.InedibleWaterContent*finalflowrate/biomatterRequested.Mass);
                end
            end
            
            % Add finalBiomatterRequested to biomass store

            % If adding more than current capacity can hold (the basis
            % used here is mass, but maybe this should be volume)
            if finalBiomatterRequested.Mass + obj.currentLevel > obj.currentCapacity
                actuallyAdded = obj.currentCapacity - obj.currentLevel;     % add only until we reach capacity
                obj.currentLevel = obj.currentLevel + actuallyAdded;                     % update currentLevel to be equal to currentCapacity
                obj.overflow = obj.overflow + finalBiomatterRequested.Mass - actuallyAdded;     % send excess to overflow and update its value
                
                % Create corresponding new BioMatter object to add to
                % store contents
                fractionOfOriginalBiomatter = actuallyAdded / finalBiomatterRequested.Mass;      % mass fraction of actually added biomatter to that requested - this is used for scaling of the newly created BioMatter
                
                newBiomatter = BioMatter(finalBiomatterRequested.Type,actuallyAdded,...
                    finalBiomatterRequested.InedibleFraction,...
                    finalBiomatterRequested.EdibleWaterContent*fractionOfOriginalBiomatter,...
                    finalBiomatterRequested.InedibleWaterContent*fractionOfOriginalBiomatter);
                
                %% fix this to better organize biomatter storage later? sort by biomatter type? if desired, use sortContents method
                obj.biomatterItems = [obj.biomatterItems newBiomatter];     % add newBiomatter to contents of BiomassStore
                obj.contents{length(obj.contents)+1} = finalBiomatterRequested.Type.Name;
            else
                % if store can hold mass of biomass requested to be added
                actuallyAdded = finalBiomatterRequested.Mass;
                obj.currentLevel = obj.currentLevel + actuallyAdded;
                obj.biomatterItems = [obj.biomatterItems finalBiomatterRequested]; 
                obj.contents{length(obj.contents)+1} = finalBiomatterRequested.Type.Name;
            end     
        end
  
        %% sortContents
        % function to aggregate biomatter of the same type together within
        % the Biomass store
        function obj = sortContents(obj)
            
            % break out of function if we only have one element within
            % obj.biomatterItems
            if length(obj.biomatterItems) == 1
                return
            end
            
            % determine number of unique biomatter types currently within
            % Biomass store
            [uniqueBiomatter, ~, allIndices] = unique(obj.contents,'stable');
            [orderedIndices, orderedPositions] = sort(allIndices);
            reorderedBiomatterItems = obj.biomatterItems(orderedPositions);
            
            %            j = 1;       % Index of orderBiomatterItems vector
            orderedBiomatter = [];   % initialize orderedBiomatter vector
            mass = reorderedBiomatterItems(1).Mass;
            inedibleFraction = reorderedBiomatterItems(1).InedibleFraction;
            edibleWaterContent = reorderedBiomatterItems(1).EdibleWaterContent;
            inedibleWaterContent = reorderedBiomatterItems(1).InedibleWaterContent;
            
            % cycle through reorderedBiomatterItems and
            for i = 2:length(reorderedBiomatterItems)
                %                currentindex = orderedIndices(i);
                
                % if consecutive indices within reorderedBiomatterItems are the same
                if orderedIndices(i-1) == orderedIndices(i)
                    inedibleFraction = (mass*inedibleFraction + reorderedBiomatterItems(i).Mass*reorderedBiomatterItems(i).InedibleFraction)/...
                        (mass + reorderedBiomatterItems(i).Mass);
                    mass = mass + reorderedBiomatterItems(i).Mass;
                    edibleWaterContent = edibleWaterContent + reorderedBiomatterItems(i).EdibleWaterContent;
                    inedibleWaterContent = inedibleWaterContent + reorderedBiomatterItems(i).InedibleWaterContent;
                else
                    % if consecutive indices are different
                    % store aggregated biomatter into orderedBiomatter
                    orderedBiomatter = [orderedBiomatter,...
                        BioMatter(reorderedBiomatterItems(i-1).Type,mass,inedibleFraction,...
                        edibleWaterContent,inedibleWaterContent)];
                    
                    % Set variables to correspond to current biomatter item
                    mass = reorderedBiomatterItems(i).Mass;
                    inedibleFraction = reorderedBiomatterItems(i).InedibleFraction;
                    edibleWaterContent = reorderedBiomatterItems(i).EdibleWaterContent;
                    inedibleWaterContent = reorderedBiomatterItems(i).InedibleWaterContent;
                end
            end
            
            % Append final biomatter object to orderedBiomatter vector
            orderedBiomatter = [orderedBiomatter,...
                BioMatter(reorderedBiomatterItems(i).Type,mass,inedibleFraction,...
                edibleWaterContent,inedibleWaterContent)];
            
            % store orderedBiomatter within obj.biomatterItems
            obj.biomatterItems = orderedBiomatter;
            obj.contents = uniqueBiomatter;
            
            
        end
        
    end
    
end

