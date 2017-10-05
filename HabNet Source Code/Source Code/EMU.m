classdef EMU
    %UNTITLED2 Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        UrineProcessor
        CO2removalTechnology
        ThermalControlTechnology
        hoursOnEVA = 0;
    end
    
    methods
        %% Constructor
        function obj = EMU(urineManagementType,CO2removalType,o2Store,co2Store,potableWaterStore,dirtyWaterStore,dryWasteStore,foodStore)
            
            if ~(strcmpi(urineManagementType,'UCTA') || strcmpi(urineManagementType,'MAG'))
                error('Selected Urine Management Technology must be either "UCTA" or "MAG"')
            elseif ~(strcmpi(CO2removalType,'METOX') || strcmpi(CO2removalType,'RCA'))
                error('Selected CO2 Removal Technology must be either "METOX" or "RCA"')
            end
            
            obj.UrineProcessor = urineManagementType;
            obj.CO2removalTechnology = CO2removalType;
            
            if strcmpi(CO2removalType,'METOX')
                obj.ThermalControlTechnology = 'Sublimator';
            elseif strcmpi(CO2removalType,'RCA')
                obj.ThermalControlTechnology = 'SWME';
            end
            
            % Create corresponding SimEnvironment
            
        end
        
        %% Tick
        function tick(obj,CrewEVAstatus,hoursOnEVA)
            % CrewEVAstatus is a binary vector indicating which crewmembers
            % are currently on EVA
            % hoursOnEVA is the current number of hours on EVA
            if sum(CrewEVAstatus) > 0
                % identify first crewmember
                obj.hoursOnEVA = obj.hoursOnEVA+1;
                if obj.hoursOnEVA == 1
                    % Store EVA status
                    currentEVAcrew = CrewEVAstatus;
                    % perform airlock ops
                    EVAprebreathedO2 = O2Store.take(prebreatheO2);      % Crew Prebreathe O2
                    % empty EVA environment to airlock and fill EVA suits with O2
                    % from O2store
                    Airlock.O2Store.add(EVAenvironment.O2Store.take(EVAenvironment.O2Store.currentLevel));
                    Airlock.CO2Store.add(EVAenvironment.CO2Store.take(EVAenvironment.CO2Store.currentLevel));
                    Airlock.NitrogenStore.add(EVAenvironment.NitrogenStore.take(EVAenvironment.NitrogenStore.currentLevel));
                    Airlock.VaporStore.add(EVAenvironment.VaporStore.take(EVAenvironment.VaporStore.currentLevel));
                    Airlock.OtherStore.add(EVAenvironment.OtherStore.take(EVAenvironment.OtherStore.currentLevel));
                    
                    EVAsuitfill = EVAenvironment.O2Store.add(O2Store.take(EMUtotalMoles));              % Fill two EMUs with 100% O2
                    % Error
                    if EVAprebreathedO2 < prebreatheO2 || EVAsuitfill < EMUtotalMoles
                        disp(['Insufficient O2 for crew EVA prebreathe or EMU suit fill at tick: ',num2str(i)])
                        disp('Current EVA has been skipped')
                        % Advance activities for all astronauts
                        astro1.skipActivity;
                        astro2.skipActivity;
                        astro3.skipActivity;
                        astro4.skipActivity;
                    end
                    % Vent lost airlock gases
                    airlockGasVented = Airlock.vent(airlockCycleLoss);
            
                end
            
            
        
        
    end
    
end

