classdef ISSVCCRLinearImpl < handle
    %ISSVCCRLinearImpl Summary of this class goes here
    %   By: Sydney Do (sydneydo@mit.edu)
    %   Date Created: 8/4/2014
    %   Last Updated: 8/4/2014
    %   Simplified linear version of the VCCR Implementation
    %   VCCR = Variable Configuration CO2 Removal
    %   This represents a 4BMS with a CO2 Store
    %   From Scott Bell: 
    %   Regarding the VCCR, the current default is just a linear model that
    %   takes 25.625 watts to scrub 1.2125 moles of air per tick (roughly 
    %   0.02844 moles of CO2 per tick). Boosting the power will make the 
    %   VCCR work harder.
    
    %   Note, this implementation assumes 100% CO2 desorption efficiency
    
    %   Modifications from original (done on 8/4/2014):
    %   Modified parameters to match ISS CDRA numbers of:
    %   Average process airflow of 95lb/hour (ref SAE 2005-01-2864)
    %   Average power consumption of 860W (REF: BVAD 2004 Appendix)
    %   Max power consumption is 1487W (REF: BVAD Appendix)
    %   Current DABs of CDRA are sized to nominally remove 0.58lb CO2/hour
    %   (Equivalent to the CO2 removal needs of 6.3 crewpersons)
    %   (REF: High Capacity Adsorbent Development for Carbon Dioxide 
    %   Removal System Efficiency Improvements)
    %   Max CO2 removal rate is equivalent to 8 person loads
    %   (REF:  "Methodology and Assumptions of Contingency Shuttle Crew 
    %   Support (CSCS) Calculations Using ISS Environmental Control and 
    %   Life Support Systems" SAE 2006-01-2061
    %
    %   Note that ISS CDRA operations follow a day/night cycle, rather than
    %   operate continuously.
    %   During the “night” cycle the 4BMS desorbing bed heaters are turned 
    %   off and the OGA goes to standby, stopping H2 production and 
    %   signaling the Sabatier to transition into standby as well
    
    %   Modifications on 12/25/2014
    %   - Added a "Setpoint" mode - to control CO2 concentration within the
    %   atmosphere to a predefined level (required for crops)
    
    properties
        % Consumer/Producer Definitions
        AirConsumerDefinition
        AirProducerDefinition
        CO2ProducerDefinition
        PowerConsumerDefinition
        Error = 0
    end
    
    properties (SetAccess = private)
        OperatingMode
        SetPoint        % measure in ppm of CO2
        CDRA_Avg_Power_Consumption% = 860
        CDRA_Max_Power_Consumption
        CDRA_Nominal_CO2_Removal_Rate% = 0.58*453.592/(12.011+2*15.999)  % mol/hr (converted from 0.58lb CO2/hr)
        CDRA_Max_CO2_Removal_Rate% = 8/6.3*0.58*453.592/(12.011+2*15.999)  % mol/hr (max CDRA capacity is for 8 human equivalents)
        CDRA_Nominal_Airflow_Rate% = 95*453.592/(12.011+2*15.999);     % in mol/hr (converted from 95lb/hr)
        CDRA_Max_Airflow_Rate% = 129*453.592/(12.011+2*15.999);     % in mol/hr (converted from 129lb/hr) (REF: Living Together in Space, pg 132 - maximum flow rate through CDRA selector valves)
        % max flow rate through CCAA CHX (and hence CDRA is 11866L/hr - determined by Temperature Control and Check Valve, pg 105, Living Together in Space)
    end
    
    methods
        %% Constructor
        function obj = ISSVCCRLinearImpl(AirInput,AirOutput,CO2Output,PowerSource,setpoint)
            
            % Error Checking
            if nargin > 0
                if ~(strcmpi(class(AirInput),'SimEnvironmentImpl') || strcmpi(class(AirOutput),'SimEnvironmentImpl'))
                    error('First two input arguments must be of type "SimEnvironmentImpl"')
                elseif ~(strcmpi(class(CO2Output),'StoreImpl') || strcmpi(class(PowerSource),'StoreImpl'))
                    error('Third and fourth input arguments must be of type "StoreImpl"')
                end
            
                % Initialize Nominal CDRA Power Consumption
                averageCDRAPowerConsumption = 860;      % Watts, (REF: BVAD 2004 Appendix)
                maxCDRAPowerConsumption = 1487;         % Watts, (REF: BVAD 2004 Appendix)
                obj.CDRA_Avg_Power_Consumption = averageCDRAPowerConsumption;
                obj.CDRA_Max_Power_Consumption = maxCDRAPowerConsumption;
                
                obj.PowerConsumerDefinition = ResourceUseDefinitionImpl(PowerSource,averageCDRAPowerConsumption,maxCDRAPowerConsumption);
                
                % Initialize Nominal and Maximum Airflow Rates through CDRA
                nominalCDRAairflowRate = 95*453.592/(12.011+2*15.999);     % in mol/hr (converted from 95lb/hr)
                maxCDRAflowRate = 129*453.592/(12.011+2*15.999);     % in mol/hr (converted from 129lb/hr) (REF: Living Together in Space, pg 132 - maximum flow rate through CDRA selector valves)
                obj.CDRA_Nominal_Airflow_Rate = nominalCDRAairflowRate;
                obj.CDRA_Max_Airflow_Rate = maxCDRAflowRate;
                
                obj.AirConsumerDefinition = ResourceUseDefinitionImpl(AirInput,nominalCDRAairflowRate,maxCDRAflowRate);
                obj.AirProducerDefinition = ResourceUseDefinitionImpl(AirOutput,nominalCDRAairflowRate,maxCDRAflowRate);
                
                % Initialize Nominal and Maximum CO2 Removal Rates (based on
                % adsoprtion capacity of zeolite adsorbents)
                nominalCDRAco2RemovalRate = 0.58*453.592/(12.011+2*15.999);     % in moles/hr (converted from 0.58lb/hr) = 6.3 human equivalents
                maxCDRAco2RemovalRate = 8/6.3*nominalCDRAco2RemovalRate;        % 8 human equivalents
                obj.CDRA_Nominal_CO2_Removal_Rate = nominalCDRAco2RemovalRate;
                obj.CDRA_Max_CO2_Removal_Rate = maxCDRAco2RemovalRate;
                
                obj.CO2ProducerDefinition = ResourceUseDefinitionImpl(CO2Output,nominalCDRAco2RemovalRate,maxCDRAco2RemovalRate);
                
                % Define Operating Mode
                if nargin >= 5
                    obj.OperatingMode = 'Set Point';
                    obj.SetPoint = setpoint;
                else
                    obj.OperatingMode = 'Nominal';
                end                   
                
            end
        end
        
        %% tick
        function molesOfCO2Adsorbed = tick(obj)
            
            % Only run if there is no system error
            if obj.Error == 0
                
                switch obj.OperatingMode
                    
                    case 'Nominal'
                        
                        % The code written below follows the VCCRLinearImpl.tick method
                        currentPowerConsumed = obj.PowerConsumerDefinition.ResourceStore.take(obj.PowerConsumerDefinition.MaxFlowRate,obj.PowerConsumerDefinition);     % Take power
                        
                        % Error source
                        if currentPowerConsumed == 0
                            disp('VCCR has switched off due to zero power draw')
                            obj.Error = 1;
                            molesOfCO2Adsorbed = 0;
                            return
                        end
                        
                        %gatherCO2(obj);
                        
                        % Size of air input sample is tuned to be a
                        % linear equation between the nominal and maximum power
                        % consumptions and air flow rates
                        molesAirNeeded = (obj.CDRA_Max_Airflow_Rate-obj.CDRA_Nominal_Airflow_Rate)/...
                            (obj.CDRA_Max_Power_Consumption-obj.CDRA_Avg_Power_Consumption)*...
                            (currentPowerConsumed-obj.CDRA_Avg_Power_Consumption)+obj.CDRA_Nominal_Airflow_Rate;
                        
                        % Similarly CO2 removal rate is tuned to power input (maps to
                        % more power sent to heaters for quicker desorption --> leads to
                        % fast adsorption/desorption cycles
                        co2RemovalRate = (obj.CDRA_Max_CO2_Removal_Rate-obj.CDRA_Nominal_CO2_Removal_Rate)/...
                            (obj.CDRA_Max_Power_Consumption-obj.CDRA_Avg_Power_Consumption)*...
                            (currentPowerConsumed-obj.CDRA_Avg_Power_Consumption)+obj.CDRA_Nominal_CO2_Removal_Rate;  % in mol/hr
                        
                    case 'Set Point'
                        
                        % CO2 removal rate based on reaching set point
                        co2RemovalRate = max([(obj.SetPoint*1E-6*obj.AirConsumerDefinition.ResourceStore.totalMoles-...
                            obj.AirConsumerDefinition.ResourceStore.CO2Store.currentLevel)/(obj.SetPoint*1E-6-1),0]);
                        
                        % Determine corresponding airflow required
                        molesAirNeeded = co2RemovalRate/obj.AirConsumerDefinition.ResourceStore.CO2Percentage;
                        
                        % Calculate corresponding power to remove
                        % corresponding airflow
                        powerRequired = (obj.CDRA_Max_Power_Consumption-obj.CDRA_Avg_Power_Consumption)/...
                            (obj.CDRA_Max_Airflow_Rate-obj.CDRA_Nominal_Airflow_Rate)*...
                            (molesAirNeeded-obj.CDRA_Nominal_Airflow_Rate)+obj.CDRA_Avg_Power_Consumption;
                        
                        % Take power according to CO2 removal rate
                        currentPowerConsumed = obj.PowerConsumerDefinition.ResourceStore.take(min([obj.PowerConsumerDefinition.MaxFlowRate,powerRequired]));     % Take power
                        
                        % Rescale co2RemovalRate if insufficient power
                        % available
                        if currentPowerConsumed < powerRequired
                            disp('Insufficient power to reduce [CO2] to desired level. Removing as much CO2 as power level allows')
                            co2RemovalRate = (obj.CDRA_Max_CO2_Removal_Rate-obj.CDRA_Nominal_CO2_Removal_Rate)/...
                                (obj.CDRA_Max_Power_Consumption-obj.CDRA_Avg_Power_Consumption)*...
                                (currentPowerConsumed-obj.CDRA_Avg_Power_Consumption)+obj.CDRA_Nominal_CO2_Removal_Rate;  % in mol/hr
                            
                            molesAirNeeded = (obj.CDRA_Max_Airflow_Rate-obj.CDRA_Nominal_Airflow_Rate)/...
                                (obj.CDRA_Max_Power_Consumption-obj.CDRA_Avg_Power_Consumption)*...
                                (currentPowerConsumed-obj.CDRA_Avg_Power_Consumption)+obj.CDRA_Nominal_Airflow_Rate;
                        end
                        
                        
                end
                
                % Define molar percentages internally to avoid errors from
                % auto updating after taking constituents
                O2percentage =  obj.AirConsumerDefinition.ResourceStore.O2Percentage;
                CO2percentage = obj.AirConsumerDefinition.ResourceStore.CO2Percentage;
                N2percentage = obj.AirConsumerDefinition.ResourceStore.N2Percentage;
                Vaporpercentage = obj.AirConsumerDefinition.ResourceStore.VaporPercentage;
                Otherpercentage = obj.AirConsumerDefinition.ResourceStore.OtherPercentage;
                
                % Determine amount of moles of CO2 currently within sample
                CO2molesInAirSample = CO2percentage*molesAirNeeded;
                
                %            if CO2molesInAirSample > co2RemovalRate
                %                % Adsordent Beds are saturated - take only what beds can
                %                % hold (ie co2RemovalRate
                %                obj.AirConsumerDefinition.ResourceStore.CO2Store.take(co2RemovalRate,...
                %                    obj.AirConsumerDefinition);
                %                % Add this amount to CO2 Store/Accumulator
                %                obj.CO2ProducerDefinition.ResourceStore.add(co2RemovalRate,obj.CO2ProducerDefinition);
                %                % Return remainder of CO2 to cabin
                %                obj.AirProducerDefinition.ResourceStore.CO2Store.add(CO2molesInAirSample-co2RemovalRate);
                %            else     % if CO2 content is less than adsorption capacity, take all CO2 from air sample and send it to CO2 store
                %                obj.AirConsumerDefinition.ResourceStore.CO2Store.take(CO2molesInAirSample,...
                %                    obj.AirConsumerDefinition);
                %                % Add this amount to CO2 Store/Accumulator
                %                obj.CO2ProducerDefinition.ResourceStore.add(CO2molesInAirSample,obj.CO2ProducerDefinition);
                %            end
                
                %% Quicker implementation of above if statement
                
                % Take CO2 moles from input environment (the lower amount of the
                % mount of CO2 in the air, or the current CO2 adsorption capacity)
                obj.AirConsumerDefinition.ResourceStore.CO2Store.take(min(co2RemovalRate,CO2molesInAirSample),...
                    obj.AirConsumerDefinition);
                
                % Add what was taken to CO2 Store
                molesOfCO2Adsorbed = obj.CO2ProducerDefinition.ResourceStore.add(min(co2RemovalRate,CO2molesInAirSample),obj.CO2ProducerDefinition);
                
                % Add any residual CO2 back into the output environment
                obj.AirProducerDefinition.ResourceStore.CO2Store.add(max(CO2molesInAirSample-co2RemovalRate,0));
                
                %% Move other constituents of air
                
                % Get air from AirConsumerDefinition.ResourceStore
                currentO2Consumed = obj.AirConsumerDefinition.ResourceStore.O2Store.take(molesAirNeeded*...
                    O2percentage,obj.AirConsumerDefinition);
                currentN2Consumed = obj.AirConsumerDefinition.ResourceStore.NitrogenStore.take(molesAirNeeded*...
                    N2percentage,obj.AirConsumerDefinition);
                currentVaporConsumed = obj.AirConsumerDefinition.ResourceStore.VaporStore.take(molesAirNeeded*...
                    Vaporpercentage,obj.AirConsumerDefinition);
                currentOtherConsumed = obj.AirConsumerDefinition.ResourceStore.OtherStore.take(molesAirNeeded*...
                    Otherpercentage,obj.AirConsumerDefinition);
                
                % Push air constituents (minus CO2) to AirProducerDefinition.ResourceStore
                obj.AirProducerDefinition.ResourceStore.O2Store.add(currentO2Consumed);
                obj.AirProducerDefinition.ResourceStore.NitrogenStore.add(currentN2Consumed);
                obj.AirProducerDefinition.ResourceStore.VaporStore.add(currentVaporConsumed);
                obj.AirProducerDefinition.ResourceStore.OtherStore.add(currentOtherConsumed);
                
                
                
            else
                % There is an error in the CDRA - no O2 is produced and we
                % skip the tick function
                molesOfCO2Adsorbed = 0;
                return
                
            end
                
        end
    end
    
end

