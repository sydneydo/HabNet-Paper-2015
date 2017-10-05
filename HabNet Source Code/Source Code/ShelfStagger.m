classdef ShelfStagger < handle
    %UNTITLED3 Summary of this class goes here
    %   Class to evenly stagger a given shelf
    
    % Update 12/22/2014
    % Updated ShelfImpl2 to ShelfImpl3
    
    properties
        Shelves
        NumberOfBatches
        BatchStartTick
        BatchTemporalSpacing
        BatchStartTicks
        currentTick = 0;
    end
    
    methods
        %% Constructor
        function obj = ShelfStagger(shelf,numberOfBatches,starttick)
            
            obj.NumberOfBatches = numberOfBatches;
            obj.BatchStartTick = starttick;
            
            cropDaysTilMaturity = shelf.Crop.TimeAtCropMaturity;
            obj.BatchTemporalSpacing = cropDaysTilMaturity/numberOfBatches*24;
            batchStartTicks = starttick + obj.BatchTemporalSpacing*(0:(numberOfBatches-1));
            
            obj.BatchStartTicks = batchStartTicks;
%             modifiedShelf = shelf;
%             modifiedShelf.cropAreaUsed = shelf.cropAreaUsed/numberOfBatches;
%             modifiedShelf.cropAreaTotal = shelf.cropAreaTotal/numberOfBatches;
%             shelves = repmat(modifiedShelf,1,numberOfBatches);
            
            % Set CropCycleStartTimes
            shelves = ShelfImpl3.empty(0,numberOfBatches);
            for i = 1:numberOfBatches
                shelves(i) = ShelfImpl3(shelf.Crop,shelf.cropAreaTotal/numberOfBatches,...
                    shelf.AirConsumerDefinition.ResourceStore,...
                    shelf.GreyWaterConsumerDefinition.ResourceStore,...
                    shelf.PotableWaterConsumerDefinition.ResourceStore,...
                    shelf.PowerConsumerDefinition.ResourceStore,...
                    shelf.BiomassProducerDefinition.ResourceStore,batchStartTicks(i));
            end
            
            obj.Shelves = shelves;
            
        end
        
        %% Tick
        function tick(obj)
            
            for i = 1:length(obj.Shelves)
%                 if obj.Shelves(i).hasDied == 1
%                     disp([obj.Shelves(i).Crop.Name, ' crop has been killd'])
%                     return
%                 end
                    
                obj.Shelves(i).tick;
            end
            
        end
        
    end
    
end

