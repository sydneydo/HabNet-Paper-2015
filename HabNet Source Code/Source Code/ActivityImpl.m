classdef ActivityImpl %< handle
    %ActivityImpl Summary of this class goes here
    %   (From original BioSim class file comments: 
    %	Activities are performed by crew members (CrewPerson) for a certain amount of
    %   time with a certain intensity in a certain order.
    
    properties
        ID
        Name
        Location
        Intensity
        Duration
    end
    
    methods
        function obj = ActivityImpl(name,intensity,duration,location)
            if nargin > 0
                obj.Name = name;
                obj.Intensity = intensity;
                obj.Duration = duration;
                if nargin == 4
                    obj.Location = location;
                end                
            end
        end
    end
    
end

