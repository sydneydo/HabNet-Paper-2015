function [crewSchedule, missionEVAschedule,crewEVAScheduleLogical] = CrewScheduler(numberOfEVAdaysPerWeek,numberOfCrew,missionDurationInWeeks,activityList)
%CrewScheduler Summary of this function goes here
%   Output data structure is a matrix with each row corresponding to the
%   schedule of each crew person for one week
%   Second output is a crew EVA schedule throughout the mission (identifies
%   EVA days - rows = week number, columns = days of the week, starting on Saturday)
%
%   Third output is an assignment of EVAs to crewmembers
%   Rows correspond to crewpersons and columns correspond to mission days
%
%   Created by: Sydney Do (sydneydo@mit.edu)
%   Created on: 7/31/2014
%   Last modified: 8/1/2014

%% Note that V-Habs task types are:
% - Mission Tasks: Science, EVA, Report to Ops
% - Recreation Tasks: Sleep, Leisure
% - Human Tasks: Personal Hygiene, Medical Check, Food, Drinking, Restroom,
% Training
% - LSS and Habitat Tasks: Planting, Harvest, LSS Action, Maintenance,
% Cleaning
% - Off-Nominal Tasks: Repair, Emergency
%
% Some of these tasks drive metabolic rates, while others drive ECLSS
% operations (those that occur in batch mode rather than continuous mode)

%% EVA Options (According to BVAD)
% Because the gravity on Mars is about twice that of Luna and about a third
% of that on Earth, the overall mass of a Mars spacesuit is extremely
% critical. A likely mission design to mitigate this problem is to reduce
% the standard EVA duration to 4 hours and plan to recharge the spacesuit
% consumables at midday. Thus, to maintain the same time outside the vehicle
% during exploration, two 4-hour, or “half-day,” EVA sorties per workday
% could replace the more traditional 8-hour EVA sortie. Assuming five
% workdays per week allows 520 half-day EVA sorties of two crewmembers per
% year without any allowance for holidays. This is also the expected number
% of airlock cycles per year. Each EVA sortie normally requires at least
% two crewmembers outside.

%% Assumptions
%   *Minimum number of crew required for EVAs to occur is 3 (two on EVA and
%   one within vehicle) (REF: EAWG Report)
%   *Only two crew members are on EVA at any one time (regardless of the
%   crew size)
%   *No EVAs on weekends (ie. maximum number of EVAs per week is 5) (REF:
%   BVAD - see above)
%   *The mission starts at the beginning of a weekend (i.e. two weekend
%   days occur before the commencement of the working week)
%   *EVAs occur in 8 hour continuous blocks of time
%   *Crewmembers who perform an EVA do not exercise on the same day
%   *Two hours of exercise are performed by each crewmember every day
%   *Each crewmember sleeps for eight hours every day
%   *Only two people can exercise simultaneously at any time (due to
%   equipment availability constraints)
%   *On a non-EVA day, there is at least one hour of IVA activities between
%   waking up from sleep and commencing exercise activities (this
%   simplifies the automated scheduling process)

%% Code

missionDurationInDays = missionDurationInWeeks * 7;

%% Determine EVA days throughout mission
% First determine EVA days within the mission schedule
% Use following encoding scheme:
% Weekend day or non-EVA Weekday = 0
% Weekday - EVA day = 1

numberOfWorkDaysPerWeek = 5;

% Zeroed Matrix of All Working Days (Non-Weekend Days) within Mission
% (Each row corresponds to a week)
workingDays = zeros(missionDurationInWeeks,numberOfWorkDaysPerWeek);

%% TO DO: Put in conditional statement for if numberOfEVAdaysPerWeek = 0
% if numberOfEVAdaysPerWeek > 0

% Randomly select days of the week that EVAs will occur for all weeks
% within the mission duration

% Matrix of possibilities of EVAdays per week
possibleEVAdaysPerWeek = nchoosek((1:numberOfWorkDaysPerWeek),numberOfEVAdaysPerWeek);
selectedEVAdaysPerWeekIndices = randi(size(possibleEVAdaysPerWeek,1),missionDurationInWeeks,1);     % Randomly select sets of possibleEVAdaysPerWeek from possibilities
selectedEVAdaysPerWeekSubscripts = possibleEVAdaysPerWeek(selectedEVAdaysPerWeekIndices,:);         % Assign randomly selected sets to weeks within schedule
workingDaysMatrixIndex = sub2ind(size(workingDays),repmat((1:missionDurationInWeeks)',numberOfEVAdaysPerWeek,1),selectedEVAdaysPerWeekSubscripts(:));   % Convert subscripts to indices of workingDays Matrix

% Assign selected EVA days to workingDays Matrix
workingDays(workingDaysMatrixIndex) = 1;

% Introduce weekend days to overall schedule by padding workingDays matrix
% on the front with two zeroed columns
missionEVAschedule = [zeros(missionDurationInWeeks,2),workingDays];

% Vector of EVA days
missionEVAvector = logical(transpose(reshape(missionEVAschedule',numel(missionEVAschedule),1)));    % Logical row vector of mission days, identifying whether or not an EVA is taking place
missionIVAvector = logical(1-missionEVAvector);

%% Assign EVAs to crew members
crewEVAScheduleBinary = zeros(numberOfCrew,missionDurationInDays);     % Initialize binary matrix for crew schedule (each row corresponds to a different crewmember)

% Matrix of possible EVA crew combinations (remember that a max of 2 crew
% per EVA)
possibleEVAcrewmembers = nchoosek(1:numberOfCrew,2);
selectedEVAcrewmembersIndices = randi(size(possibleEVAcrewmembers,1),missionDurationInDays,1);     % Randomly select sets of possibleEVAcrewmembers combinations for ALL mission days
selectedEVAcrewmembersSubscripts = possibleEVAcrewmembers(selectedEVAcrewmembersIndices,:);
crewScheduleBinaryIndex = sub2ind(size(crewEVAScheduleBinary),selectedEVAcrewmembersSubscripts(:),repmat((1:missionDurationInDays)',2,1));

crewEVAScheduleBinary(crewScheduleBinaryIndex) = 1;

% Zero out columns in crewScheduleBinary corresponding to an IVA day (to
% leave only EVA days remaining)
crewEVAScheduleBinary(:,missionIVAvector) = zeros(numberOfCrew,sum(missionIVAvector));
crewEVAScheduleLogical = logical(crewEVAScheduleBinary);      % Make binary array into a logical array
% crewIVAScheduleLogical = logical(1-crewEVAScheduleLogical);

%% Assign activities to Crew Schedule
%   Master List of types of activities
%
%   Format: ActivityImpl('Name',Intensity,Duration)
%   Where:
%   - Intensity is measured on a scale of 0 to 5 (based on BioSim's
%   approach). This drives metabolic rates of the crew
%   - Duration is measured in hours

% Note that the current timestep in our model is in hours

%% Unpack activityList

% lengthOfExercise = 2;                       % Number of hours spent on exercise activity
%
% IVAhour = ActivityImpl('IVA',2,1);          % One hour of IVA time (corresponds to generic IVA activity)
% Sleep = ActivityImpl('Sleep',0,8);          % Sleep period
% Exercise = ActivityImpl('Exercise',5,lengthOfExercise);    % Exercise period
% EVA = ActivityImpl('EVA',4,8);              % EVA - fixed length of 8 hours

[activityNames,activityIndices] = unique({activityList.Name});

% Search for EVA activity
if sum(strcmpi(activityNames,'EVA')) == 1 % If EVA is the name of a unique activity
    EVA = activityList(activityIndices(strcmpi(activityNames,'EVA')));
end

% Search for Sleep activity
if sum(strcmpi(activityNames,'Sleep')) == 1 % If EVA is the name of a unique activity
    Sleep = activityList(activityIndices(strcmpi(activityNames,'Sleep')));
end

% Search for IVA activity
if sum(strcmpi(activityNames,'IVA')) == 1 % If EVA is the name of a unique activity
    IVA = activityList(activityIndices(strcmpi(activityNames,'IVA')));
    if IVA.Duration == 1
        IVAhour = IVA;
    end
end

% Search for Exercise activity
if sum(strcmpi(activityNames,'Exercise')) == 1 % If EVA is the name of a unique activity
    Exercise = activityList(activityIndices(strcmpi(activityNames,'Exercise')));
end

% Define EVA-day activity schedule
EVAday = [Sleep,repmat(IVAhour,1,3),EVA,repmat(IVAhour,1,5)];

lengthOfExercise = Exercise.Duration;       % Extract length of exercise from Exercise activity

% Randomly assign hours in daily morning shift before exercise is performed
% (assuming all mission days are IVA-days for the moment)
hoursInDailyMorningShift = lengthOfExercise*randi(14/lengthOfExercise,size(crewEVAScheduleBinary));      % Select hours after waking up to do exercise (only start exercise on even  hours to avoid overlap of equipment - since exercise duration is 2 hours)

%% Apply exercise equipment constraint
maxNumberOfPeopleExercising = 2;

% Vector of possible exercise start hours
exerciseHourVector = 2:lengthOfExercise:14;

exerciseDistribution = histc(hoursInDailyMorningShift,exerciseHourVector);        % Note that we assume that there are 14hours in a day after sleep and exercise are accounted for

% Find row and column indices of elements within distribution matrix that
% are > maxNumberOfPeopleExercising
[rowIndex,colIndex] = find(exerciseDistribution > maxNumberOfPeopleExercising);

% Move through each identified crew day and modify the crew schedule so
% that there is no longer an exercise conflict
for i = 1:length(rowIndex)
    
    % Find index of identified value within hoursInDailyMorningShift to
    % place (select the first one)
    replacedIndex = find(hoursInDailyMorningShift(:,colIndex(i))==exerciseHourVector(rowIndex(i)));
    
    % For each element to replace (corresponding to the total number of
    % elements - maxNumberOfPeopleExercising
    for j = 1:(exerciseDistribution(rowIndex(i),colIndex(i))-maxNumberOfPeopleExercising)
        
        % Search for elements with zero within column index (this enforces
        % the selected alternative to correspond to that most
        % under-utilized)
        minValIndex = find(exerciseDistribution(:,colIndex(i))==min(exerciseDistribution(:,colIndex(i))));
        
        % Replace identified crew schedule with alternative schedule indicated
        % by minValIndex
        hoursInDailyMorningShift(replacedIndex(j),colIndex(i)) = exerciseHourVector(minValIndex(1));
        
        % Update exerciseDistribution matrix for next element to be sorted
        % through
        exerciseDistribution(:,colIndex(i)) = histc(hoursInDailyMorningShift(:,colIndex(i)),exerciseHourVector);
    end
end

%% Build Final Crew Schedule

% Build Crew Schedule Assuming everyday is an IVA day. Note that the format
% of a non-IVA day is:
% nonEVAday = [Sleep,repmat(IVAhour,1,hoursInDailyMorningShift),Exercise,repmat(IVAhour,1,14-hoursInDailyMorningShift)];
crewSchedule = arrayfun(@(x) [Sleep,repmat(IVAhour,1,x),Exercise,repmat(IVAhour,1,14-x)],hoursInDailyMorningShift,'UniformOutput',0);

% Replace IVA days set on EVA days with EVA day activities
crewSchedule(crewEVAScheduleLogical) = {EVAday};

% Note command to use in main file to load into CrewPersonImpl is:
% [crewSchedule{i,:}]

% Check to see if any of the base activities have vectors as the input of
% the location, and randomly select one element of the vector as the
% location of the activity
%% Search for activities with a vector of SimEnvironments as their location and randomly select locations for them

% For each element within crewSchedule (corresponds to each mission day for
% each crew member)
for i = 1:length(crewSchedule(:))
    
    % For each activity within each crew-day
    for j = 1:length(crewSchedule{i})
        
        % If number of locations assigned is > 1 randomly select one
        if length(crewSchedule{i}(j).Location) > 1
            crewSchedule{i}(j).Location = crewSchedule{i}(j).Location(randi(length(crewSchedule{i}(j).Location)));
        end
        
    end
    
end

end

