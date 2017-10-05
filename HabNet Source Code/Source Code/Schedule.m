classdef Schedule < handle
    %UNTITLED4 Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        crew = CrewPersonImpl
        activitySet
    end
    
    methods
        function obj = Schedule(Crew,ActivitySet)
            obj.crew = Crew;
            obj.activitySet = ActivitySet;
        end
           
        function obj = insertActivityInSchedule(obj,activity)
            obj = [obj, activity];
        end
            
        
    end
    
end

