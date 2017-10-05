classdef TensileData
   properties
      Material = 'carbon steel';
      SampleNumber = 0;
      Stress
      Strain
      
   end % properties
   
   properties (Dependent = true, SetAccess = private)
       Modulus
   end

   methods
       function td = TensileData(material,samplenum,stress,strain)
           if nargin > 0 % Support calling with 0 arguments
               td.Material = material;
               td.SampleNumber = samplenum;
               td.Stress = stress;
               td.Strain = strain;
           end
       end % TensileData
       
       function obj = set.Material(obj,material)
         if ~(strcmpi(material,'aluminum') ||... 
            strcmpi(material,'stainless steel') ||... 
            strcmpi(material,'carbon steel'))
            error('Material must be aluminum, stainless steel, or carbon steel')
         end
      obj.Material = material;
      end % set.Material
      
      function modulus = get.Modulus(obj)
          ind = find(obj.Strain > 0); % Find nonzero strain
          modulus = mean(obj.Stress(ind)./obj.Strain(ind));
      end % Modulus get method
      
      function obj = set.Modulus(obj,~)
          fprintf('%s%d\n','Modulus is: ',obj.Modulus)
          error('You cannot set Modulus explicitly');
      end % Modulus set method

      function disp(td)
          fprintf(1,'Material: %s\nSample Number: %g\nModulus: %1.5g\n',...
              td.Material,td.SampleNumber,td.Modulus);
      end % disp
      
      function plot(td,varargin)
          plot(td.Strain,td.Stress,varargin{:})
          title(['Stress/Strain plot for Sample',...
              num2str(td.SampleNumber)])
          ylabel('Stress (psi)')
          xlabel('Strain %')
      end % plot
      
   end% methods
end% classdef