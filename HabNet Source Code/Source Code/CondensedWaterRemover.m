classdef CondensedWaterRemover < handle
    %CondensedWaterRemover Summary of this class goes here
    %   Represents a technology that removes condensed water from an
    %   environment and sends it to a grey water store
    
    %   We assume no flow rate restrictions. This technology is equivalent
    %   to the crew collecting condensed water within the environment and
    %   pooring the liquid water into a dirty water store
    
    properties
        Environment
        DirtyWaterOutput
    end
    
    methods
        %% Constructor
        function obj = CondensedWaterRemover(environment,dirtywaterstore)
            obj.Environment = environment;
            obj.DirtyWaterOutput = dirtywaterstore;
        end
        
        %% Tick
        function condensedWaterRemoved = tick(obj)
            % Take condensed water from environment
            condensedWaterRemoved = obj.Environment.VaporStore.takeOverflow*18.01524/1000;
            
            % Add to dirty water store
            obj.DirtyWaterOutput.add(condensedWaterRemoved);
        end
    end
    
end

