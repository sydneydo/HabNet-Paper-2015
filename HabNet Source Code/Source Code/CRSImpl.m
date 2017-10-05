classdef CRSImpl
    %CRSImpl Summary of this class goes here
    %   By: Sydney Do (sydneydo@mit.edu)
    %   Date Created: 5/16/2014
    %   Last Updated: 5/16/2014
    %   This is a simple implementation of CO2 Reduction System (Sabatier
    %   Reactor)
    
    properties
        % Consumer/Producer Definitions
        CO2ConsumerDefinition
        H2ConsumerDefinition
        PowerConsumerDefinition
        PotableWaterProducerDefinition
        MethaneProducerDefinition
    end
    
    properties (Access = private)
        % According to BioSim code comments, this value is used to:
        % multiply times power to determine how much air/H2/water we're consuming
        % That is, it relates CO2 processed to power used --> 0.027mols
        % processed per watt
        LINEAR_MULTIPLICATIVE_FACTOR = 0.02777777777777778
    end
    
    methods
        %% Constructor
        function obj = CRSImpl
            obj.CO2ConsumerDefinition = ResourceUseDefinitionImpl;
            obj.H2ConsumerDefinition = ResourceUseDefinitionImpl;
            obj.PowerConsumerDefinition = ResourceUseDefinitionImpl;
            obj.PotableWaterProducerDefinition = ResourceUseDefinitionImpl;
            obj.MethaneProducerDefinition = ResourceUseDefinitionImpl;
        end
        
        %% tick
        function tick(obj)
            % gatherPower();
            currentPowerConsumed = obj.PowerConsumerDefinition.ResourceStore.take(obj.PowerConsumerDefinition.MaxFlowRate,obj.PowerConsumerDefinition);     % Take power
            
            % gatherH2andCO2();
            % Follows CO2 + 4H2 --> CH4 + 2H2O
            % The calculations below are in moles
            CO2Needed = currentPowerConsumed * obj.LINEAR_MULTIPLICATIVE_FACTOR;
            H2Needed = CO2Needed * 4;
            % Take these resources from stores
            currentCO2Consumed = obj.CO2ConsumerDefinition.ResourceStore.take(CO2Needed,obj.CO2ConsumerDefinition);
            currentH2Consumed = obj.H2ConsumerDefinition.ResourceStore.take(H2Needed,obj.H2ConsumerDefinition);
            
            % Stop running if nothing is taken from stores
            if currentCO2Consumed == 0 || currentH2Consumed == 0
                % Return anything taken back to their original stores
                obj.CO2ConsumerDefinition.ResourceStore.add(currentCO2Consumed,obj.CO2ConsumerDefinition);
                obj.H2ConsumerDefinition.ResourceStore.add(currentH2Consumed,obj.H2ConsumerDefinition);
                currentH2OProduced = 0;
                currentCH4Produced = 0;
            else
                limitingReactant = min(currentH2Consumed/4,currentCO2Consumed);
                
                % Send excess reactants back to stores
%                 if limitingReactant == (currentH2Consumed) %(currentH2Consumed/4) - commented version is the CORRECT version since limiting reactant has to be one of the two within the min command above
                if limitingReactant == (currentH2Consumed/4)  
                    obj.CO2ConsumerDefinition.ResourceStore.add(currentCO2Consumed-limitingReactant,obj.CO2ConsumerDefinition); % This is correct since here, limiting reactant is already defined as currentH2Consumed/4
                else %if limitingReactant == currentCO2Consumed
                    obj.H2ConsumerDefinition.ResourceStore.add(currentH2Consumed-4*limitingReactant,obj.H2ConsumerDefinition);
                end
                
                %             waterLitersProduced = 2*limitingReactant*18.01524/1000;    % Converts moles of water produced (from stoichiometry) to liters of water produced
                %             CH4molesProduced = limitingReactant;
                currentH2OProduced = 2*limitingReactant*18.01524/1000;
                currentCH4Produced = limitingReactant;
            end    
            % pushWaterAndMethane();
            % Send water and methane to stores
            obj.PotableWaterProducerDefinition.ResourceStore.add(currentH2OProduced,obj.PotableWaterProducerDefinition);
            obj.MethaneProducerDefinition.ResourceStore.add(currentCH4Produced,obj.MethaneProducerDefinition);
            
        end
    end
    
end

