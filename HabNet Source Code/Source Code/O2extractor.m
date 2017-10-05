classdef O2extractor < handle
    %O2extractor Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        Environment         % Of class SimEnvironmentImpl - corresponds to the environment from which o2 is being extracted
        TargetTotalPressure
        TargetO2MolarFraction   % Target O2 molar fraction
        TargetO2PartialPressure
        Mode
        OutputStore
    end
    
    properties (SetAccess = private)
        UpperO2FractionLimit = 0.3
        PartialPressureBoundingBox = 0.05%1.37895146     % in kPa (converted from 0.2psia), extent of control box around which pressure is controled (REF: Section 5.1 EAWG)
        idealGasConstant = 8.314;        % J/K/mol
        ppO2setPoint
    end
    
    methods
        %% Constructor
        function obj = O2extractor(environment,targetTotalPressure,targetO2molarFraction,O2output,mode)
            
            % Check that inputs are of the correct type
            if ~(strcmpi(class(environment),'SimEnvironmentImpl') || ...
                    strcmpi(class(O2output),'StoreImpl'))
                error('First input must be of type "SimEnvironmentImpl" and second input must be of type "StoreImpl"');
            end
            
            if ~(strcmpi(mode,'Partial Pressure')||strcmpi(mode,'Molar Fraction'))
                error('Fifth input must be declared as either "Partial Pressure" or "Molar Fraction"');
            end
            
            obj.Environment = environment;
            obj.OutputStore = O2output;
            
            obj.TargetTotalPressure = targetTotalPressure;
            obj.TargetO2MolarFraction = targetO2molarFraction;
            obj.TargetO2PartialPressure = targetO2molarFraction*targetTotalPressure;
            obj.ppO2setPoint = targetO2molarFraction*targetTotalPressure - obj.PartialPressureBoundingBox;
            obj.Mode = mode;

        end
        
        %% Tick
        function O2removed = tick(obj)
            % We assume for now that there are no limits on the rate at
            % which O2 can be removed from the environment
            % The O2extractor is perfectly efficient
            
            % Remove O2 from environment if ppO2 increasess past bounding
            % box value
            switch obj.Mode
                case 'Partial Pressure'
                    currentppO2 = obj.Environment.O2Percentage*obj.Environment.pressure;
                    
                    if currentppO2 > (obj.TargetO2PartialPressure + obj.PartialPressureBoundingBox)
                        % Determine targetO2moles level based on current
                        % environmental conditions
                        targetO2moles = obj.ppO2setPoint*obj.Environment.volume/...
                            (obj.idealGasConstant*(273.15+obj.Environment.temperature));
                        
                        o2molesToRemove = obj.Environment.O2Store.currentLevel-targetO2moles;
                        
                        % Take moles from environment and send to O2 output
                        O2removed = obj.Environment.O2Store.take(o2molesToRemove);
                        obj.OutputStore.add(O2removed);
                    else
                        O2removed = 0;
                    end
                    
                case 'Molar Fraction'
                    % we determine the target ppO2 based on molar fraction
                    % and take away the number of moles corresponding to
                    % the other side of the equivalant pressure bounding
                    % box
                    currentTargetppO2 = obj.TargetO2MolarFraction*obj.Environment.totalMoles*obj.idealGasConstant*...
                        (obj.Environment.temperature+273.15)/obj.Environment.volume;
                    
                    if (obj.Environment.O2Percentage*obj.Environment.pressure) > (currentTargetppO2 + obj.PartialPressureBoundingBox)
                    
                        targetO2moles = (currentTargetppO2-obj.PartialPressureBoundingBox)*obj.Environment.volume/...
                            (obj.idealGasConstant*(273.15+obj.Environment.temperature));
                        
                        o2molesToRemove = obj.Environment.O2Store.currentLevel-targetO2moles;
                        
%                     o2MolesToRemove = (obj.Environment.O2Store.currentLevel-obj.TargetO2MolarFraction*obj.Environment.totalMoles)/...
%                         (1-obj.TargetO2MolarFraction);

                        % Take moles from environment and send to O2 output
                        O2removed = obj.Environment.O2Store.take(o2molesToRemove);
                        obj.OutputStore.add(O2removed);
   
                    else
                        O2removed = 0;
                    end
                    
            end         

        end
    end
    
end

