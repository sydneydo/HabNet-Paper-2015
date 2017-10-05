classdef StoreImpl < handle
    %StoreImpl Summary of this class goes here
    %   By: Sydney Do (sydneydo@mit.edu)
    %   Revision History
    %   Last Updated: 2/15/2015
    %   2/15/2015: Modified fill method warning to include the "contents"
    %   property so that the warning indicates exactly which store is being
    %   referred to
    
    %   TO DO: Incorporate tick method or some other means to track ticks,
    %   so that warnings can have tick information within them
    
    properties
        % Are just associated to the class - don't need to be predeclared
        % in Matlab
        contents
        type        % constrain to types of either "Environmental" or "Material", where environmental represents an atmospheric store (this effects how resources are added to stores)
        tickcount = 0;
        currentLevel = 0;
        currentCapacity = 0;
        overflow = 0;
        pipe = false;
%         initialLevel = 0;
%         initialCapacity = 0;
        resupplyFrequency = 0;
        resupplyAmount = 0;

%         myTicks =0;
        %% resupply

    end 
    
    methods
        function obj = StoreImpl(storecontent,storetype,capacity,level)
            if nargin == 2
                obj.contents = storecontent;
                % Control input to storetype
                if ~(strcmpi(storetype,'Environmental') ||...
                        strcmpi(storetype,'Material'))
                    error('Store type must be set to either Environmental or Material')
                end
                obj.type = storetype;
            
            elseif nargin == 4     
                obj.contents = storecontent;
                % Control input to storetype
                if ~(strcmpi(storetype,'Environmental') ||...
                        strcmpi(storetype,'Material'))
                    error('Store type must be set to either Environmental or Material')
                end
                obj.type = storetype;
                obj.currentCapacity = capacity;
                obj.currentLevel = level;
            end
        end

        function obj = tick(obj,tickcount)
            obj.tickcount = tickcount;
            if obj.tickcount > 0 && obj.resupplyFrequency > 0
                % Resupply store if the current tickcount occurs at the
                % interval between resupply
                if mod(obj.tickcount,obj.resupplyFrequency) == 0
                    obj.add(obj.resupplyAmount);
                end
            end
        end

        %% Method to Add Resources to Stores
        function [actuallyAdded,obj] = add(obj,amountRequested,resourceManagementDefinition)
            % resourceManagementDefinition must be of a type corresponding
            % to one of the resource consumer or producer definitions
            
            %% Commands for Environmental Stores
            if nargin == 2 % should correspond to an Environmental type of Store
            
                if amountRequested < 0;
                    actuallyAdded = 0;
                    return
                    % If an environmental store, modify store capacity to
                    % contain what is required
                elseif strcmpi(obj.type,'Environmental')
                    obj.currentLevel = obj.currentLevel+amountRequested;
                    obj.currentCapacity = obj.currentLevel; % Enforce environmental store capacity to equal current level
                    actuallyAdded = amountRequested;
                else % if simple buffer
                    % If wanting to add more than what the store can hold
                    if (amountRequested + obj.currentLevel) > obj.currentCapacity
                        actuallyAdded = obj.currentCapacity - obj.currentLevel;
                        obj.currentLevel = obj.currentLevel + actuallyAdded;
                        obj.overflow = obj.overflow + (amountRequested - actuallyAdded);
                    % If amount to add does not result in overfilling of store
                    else
                        obj.currentLevel = obj.currentLevel+amountRequested;
                        actuallyAdded = amountRequested;
                    end
                end
                
            %% Commands for Material Stores
            elseif nargin == 3 % should correspond to a Material type of Store
                % Determine flow rate by which to add resources based on
                % desired and max flow rates
                % The code below corresponds to the
                % StoreFlowRateControllableImpl.pushFractionalResourcesToStores
                % method used in BioSim
                % This method needs as an input, the resource consumer
                % definition, so that the max and min flow rates can be
                % extracted and then compared
                
%                 % Ensure that store is of type Material    
%                 if ~strcmpi(obj.type,'Material')
%                     error('Calls to the "add" method with three inputs must be for "Material" stores')
%                 end
                
                amountToAddFinal = min([amountRequested,resourceManagementDefinition.MaxFlowRate,...
                    resourceManagementDefinition.DesiredFlowRate]);
                
                if amountToAddFinal < 0;
                    actuallyAdded = 0;
                    return
                elseif strcmpi(obj.type,'Environmental')
                    % Add to store and update store capacity
                    obj.currentLevel = obj.currentLevel+amountToAddFinal;
                    actuallyAdded = amountToAddFinal;
                    obj.currentCapacity = obj.currentLevel;
                else % For a material type of store
                    % If wanting to add more than what the store can hold
                    if (amountToAddFinal + obj.currentLevel) > obj.currentCapacity
                        actuallyAdded = obj.currentCapacity - obj.currentLevel;
                        obj.currentLevel = obj.currentLevel + actuallyAdded;
                        obj.overflow = obj.overflow + (amountToAddFinal - actuallyAdded);
                        % If amount to add does not result in overfilling of store
                    else
                        obj.currentLevel = obj.currentLevel+amountToAddFinal;
                        actuallyAdded = amountToAddFinal;
                    end
                end
            end
            
        end
                
        %% Take Method 
        % amountRetrieved is the amount actually retrieved
        function [amountRetrieved,obj] = take(obj,amountToTake,resourceManagementDefinition)
            % resourceManagementDefinition must be of a type corresponding
            % to one of the resource consumer or producer definitions
            
            %% Commands for either Environmental or SimpleBuffer type Stores
            if nargin == 2 % should correspond to an Environmental type of Store
                
                if amountToTake < 0;
                    amountRetrieved = 0;
                    return
                % if asking to take more than exists, empty store
                % at the moment, we don't track the deficit between how much is
                % requested to be taken, and how much is actually taken. This
                % will likely be implemented elsewhere
                elseif amountToTake > obj.currentLevel
                    amountRetrieved = obj.currentLevel;
                    obj.currentLevel = 0;
                % there is enough contents within the store to be taken
                else
                    obj.currentLevel = obj.currentLevel - amountToTake;
                    amountRetrieved = amountToTake;
                end
            
                % If store is an environmental store, adjust store capacity to
                % equal store level
                if strcmpi(obj.type,'Environmental')
                    obj.currentCapacity = obj.currentLevel;
                end
            
            %% Commands for Material Stores
            elseif nargin == 3 % should correspond to a Material type of Store
                % Determine flow rate by which to remove resources based on
                % desired and max flow rates
                % The code below corresponds to the
                % StoreFlowRateControllableImpl.getFractionalResourcesFromStores
                % method used in BioSim
                % This method needs as an input, the resource consumer
                % definition, so that the max and min flow rates can be
                % extracted and then compared
                
%                 % Ensure that store is of type Material
%                 if ~strcmpi(obj.type,'Material')
%                     error('Calls to the "take" method with three inputs must be for "Material" stores')
%                 end
                               
                amountToTakeFinal = min([amountToTake,resourceManagementDefinition.MaxFlowRate,...
                    resourceManagementDefinition.DesiredFlowRate]);
                
                if amountToTakeFinal < 0;
                    amountRetrieved = 0;
                    return
                    
                % if asking to take more than exists, empty store
                % at the moment, we don't track the deficit between how much is
                % requested to be taken, and how much is actually taken. This
                % will likely be implemented elsewhere
                elseif amountToTakeFinal > obj.currentLevel
                    amountRetrieved = obj.currentLevel;
                    obj.currentLevel = 0;
                % there is enough contents within the store to be taken
                else
                    obj.currentLevel = obj.currentLevel - amountToTakeFinal;
                    amountRetrieved = amountToTakeFinal;
                end
                
                % If store is an environmental store, adjust store capacity to
                % equal store level
                if strcmpi(obj.type,'Environmental')
                    obj.currentCapacity = obj.currentLevel;
                end
                
            end
       
        end
        
        %% Take Overflow
        % Method to remove amount from overflow. This is typically used
        % only for the vapor store
        function overflowtaken = takeOverflow(obj)
            overflowtaken = obj.overflow;
            obj.overflow = 0;
        end
            
        %% Fill
        % Method to fill store to capacity
        % Only applies to "Material" type stores
        % "fillStore" is a store that the current store is filling from
        function amountAdded = fill(obj,fillStore)
            
            % Check that obj is of type "Material"
            if ~strcmpi(obj.type,'Material')
                error('The "fill" method can only be applied to stores of type "Material"');
            end
            
            if nargin == 1
                % fill current store from zero source
                amountToAdd = obj.currentCapacity - obj.currentLevel;    % Amount desired to be added
                amountAdded = obj.add(amountToAdd);
                
            elseif nargin == 2
                % fill store from the declared "fillStore"
                
                % Check that fillstore is of type "Material"
                if ~strcmp(fillStore.type,'Material')
                    error('The declared "fillStore" must be of type "Material"');
                end
                
                amountToAdd = obj.currentCapacity - obj.currentLevel;    % Amount desired to be added
                
                if amountToAdd > fillStore.currentLevel
                    disp(['Insufficient resources available to fill ', obj.contents,'. Filling store with as many resources as is available'])
                end                
                
                amountAdded = obj.add(fillStore.take(amountToAdd)); % Note that this line can already handle whether ot nor amountToAdd is > or < fillStore.currentCapacity
            else
                error('Two many input arguments')
            end
            
        end

    
    end
    
        %% setresupply
        % from StoreImpl java class file
%             public void setResupply(int pResupplyFrequency, float pResupplyAmount) {
%         resupplyFrequency = pResupplyFrequency;
%         resupplyAmount = pResupplyAmount;
%     }
        
        


end

