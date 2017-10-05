classdef PressureDistribute < handle
    %PressureDistribute Summary of this class goes here
    %   By: Sydney Do (sydneydo@mit.edu)
    %   Date Created: 3/26/2015
    %   Last Updated: 3/26/2015
    
    %   This is an updated version of PressureBalancer based on solving a
    %   system of linear equations, rather than an iterative approach
    
    %   Note that this code does not work for habitat module arrangments
    %   that are circular and enclosed - in this case, a reference module
    %   needs to be chosen to initiate the analysis
    %   This code is based on iterating through a process of:
    %   1. Determining pressure differences in each module between the
    %   current pressure and the average pressure
    %   2. Identifying source and sink nodes based on rows within the
    %   adjacency matrix with only one entry
    %   3. Adjusting pressures within source and sink nodes until the
    %   pressure difference between their own pressures and the known
    %   average pressure is zero
    
    %   Include this function after fans are initiated
    
    properties
        Modules             % List of modules in the order in which they are captured in the adjacency matrix
        AdjacencyMatrix     % Adjacency matrix of modules and their connections
        TargetPressure      % Average pressure across habitat being targeted
        LinearSystem        % Derived system of equations
        SourceNodes         % Vector of modules that send gases, ordered by adjacency matrix
        SinkNodes           % Vector of modules that receive gases, ordered by adjacency matrix
        TakenAir            % Matrix of air taken from modules (each row represents a module, each column represents a gas species)
        InjectedAir         % Matrix of air injected into modules (each row represents a module, each column represents a gas species)
    end
    
    properties (Access = private)
        idealGasConstant = 8.314;   % J/K/mol
        CelsiusToKelvin = 273.15;
    end
    
    methods
        %% Constructor
        function obj = PressureDistribute(modules,adjacencyMatrix)
            if ~strcmpi(class(modules),'SimEnvironmentImpl')
                error('Input must be of class "SimEnvironmentImpl"')
            end
            
            obj.Modules = modules;
            obj.AdjacencyMatrix = adjacencyMatrix;            
            
            %% Build linear system matrix during initialization
            [row,col] = find(adjacencyMatrix==1);
                        
            % Define equations corresponding to flows in and out of each
            % module
            % First part of matrix with pressure balances
%             A = sparse(col,1:length(col),1,systemRows,systemCols,2*systemCols);
            
            % Define equations corresponding to corresponding to flow
            % equality - ie. x_ab = -x_ba
            % We do this by searching for equal pairs across the diagonal
            % of a matrix
            ind = [col,row];        % Baseline, we arrange it this way so as to follow the convention of building the A matrix based on moving across each row and finding non-zero elements
            indcompare = [row,col];

            obj.SourceNodes = col;
            obj.SinkNodes = row;
            
            count = 0;
            count2 = 0;
            equalityConstraintIndex = zeros(length(col),2);
            for j = 1:length(col)
                % Find pairing indices
                matchingIndex = find(indcompare(:, 1) == ind(j,1) & indcompare(:, 2) == ind(j,2));
                
                if matchingIndex > j
                    count = count+1;
                    count2 = count2+1;
                    equalityConstraintIndex(count2,:) = [length(adjacencyMatrix)+count,j];
                    count2 = count2+1;
                    equalityConstraintIndex(count2,:) = [length(adjacencyMatrix)+count,matchingIndex];
                end
            end
            
            % Define Linear System
            obj.LinearSystem = sparse([col;equalityConstraintIndex(:,1)],[(1:length(col))';equalityConstraintIndex(:,2)],1);
            
        end
        
        
        %% tick
        function obj = tick(obj)
            
            % Determine b column vector to solve with system of equations, based on total number of moles required to be moved to equalize pressure            
            
            % Calculate Average Pressure 
            obj.TargetPressure = sum([obj.Modules.totalMoles])*obj.idealGasConstant*(mean([obj.Modules.temperature])+obj.CelsiusToKelvin)/(sum([obj.Modules.volume]));	% Target Pressure in kPa      
                       
            % Molar difference between current and average pressure
%             pressureDiff = [obj.Modules.pressure]-obj.TargetPressure;
            
%             molarDiff = pressureDiff.*[obj.Modules.volume]./(obj.idealGasConstant*([obj.Modules.temperature]+obj.CelsiusToKelvin));
            
            molarDiff = [obj.Modules.totalMoles]-obj.TargetPressure*[obj.Modules.volume]./(obj.idealGasConstant*([obj.Modules.temperature]+obj.CelsiusToKelvin));
            
            % Construct molar difference vector
            moleDiffVector = [molarDiff';zeros(sum(sum(obj.AdjacencyMatrix))/2,1)];
            
            % Solve system of equations
            moleExchange = obj.LinearSystem\moleDiffVector;
            
            % Take only positive values within solution (corresponding to
            % flowing from one module to another) and calculate moles to
            % take (all together)
                        
            airGivers = obj.SourceNodes(moleExchange>0);
            airToMove = moleExchange(moleExchange>0);
            airTakers = obj.SinkNodes(moleExchange>0);
            
            % Take air from each module
            takenAir = zeros(length(airGivers),5);
            
            for j = 1:length(airGivers)
                takenAir(j,:) = obj.takeAir(obj.Modules(airGivers(j)),airToMove(j));
            end
            
            % Inject air to each destination module
            injectedAir = zeros(length(airTakers),5);
            
            for j = 1:length(airTakers)
                injectedAir(j,:) = obj.injectAir(obj.Modules(airTakers(j)),takenAir(j,:));
            end
 
            obj.TakenAir = takenAir;
            obj.InjectedAir = injectedAir;
            
        end
        
    end
    
    %% Static Methods
    methods (Static)
        %% TakeAir
        % Function to take air out of a module
        % Output ordered by the following species [O2,CO2,N2,Vapor,Other]
        function takenAir = takeAir(module,molesToMove)
            takenAir = zeros(1,5);
            takenAir(1) = module.O2Store.take(molesToMove*module.O2Percentage);
            takenAir(2) = module.CO2Store.take(molesToMove*module.CO2Percentage);
            takenAir(3) = module.NitrogenStore.take(molesToMove*module.N2Percentage);
            takenAir(4) = module.VaporStore.take(molesToMove*module.VaporPercentage);
            takenAir(5) = module.OtherStore.take(molesToMove*module.OtherPercentage);
        end
        
        %% TakeAir
        % Function to take air out of a module
        % Output ordered by the following species [O2,CO2,N2,Vapor,Other]
        function injectedAir = injectAir(module,molesToInject)
            injectedAir = zeros(1,5);
            injectedAir(1) = module.O2Store.add(molesToInject(1));
            injectedAir(2) = module.CO2Store.add(molesToInject(2));
            injectedAir(3) = module.NitrogenStore.add(molesToInject(3));
            injectedAir(4) = module.VaporStore.add(molesToInject(4));
            injectedAir(5) = module.OtherStore.add(molesToInject(5));
        end
        
    end
    
end

