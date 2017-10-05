lettuce = (30*24+1):30*24:19000;    % ticks at which a yield occurs

profile = zeros(1,19000);
% profile(lettuce) = 1;

vals = 20.03*30*(1:length(lettuce))/1000;

profile(lettuce) = vals;

for i = 1:(length(lettuce)-1)
    profile((lettuce(i)+1):(lettuce(i+1)-1)) = vals(i);
end

profile((lettuce(end)+1):end) = vals(end);   % Assign data to last growth cycle

figure, plot(profile)

%% Alternative (faster)
timesteps = 19000;
TimeToCropMaturity = 88;        % days
growthrate = 11.86;             % grams/day/m^2
noCycles = floor(timesteps/(24*TimeToCropMaturity));

matrix = repmat(0:noCycles,24*TimeToCropMaturity,1);

profile = growthrate*TimeToCropMaturity/1000*transpose(matrix(:));
profile = profile(1:timesteps);
figure, plot(profile), grid on