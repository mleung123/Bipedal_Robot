% Optimization Master
% Author: Connor Morrow
% Date: 1/14/2020
% Description: This master script will call subscripts in order to 
% optimize muscle attachment locations for the bipedal robot. It first 
% grabs the human torque data and initial robot torque data. Once this is 
% complete, it begin perturbing robot muscle locations until it finds a
% solution that matches human torque data. 

clear
close all
clc

%% ------------- User Entered Parameters -------------
%Choose the Joint that you will to observe
%Options are: Back, Bi_Hip, Calves, Foot, Toe, Uni_Hip
ChooseJoint = 'Back';

%Choose the number of divisions for the angles of rotation
divisions = 100;

%Choose the number of iterations for the optimization code
iterations = 100;

    %Note: Time calculation equation (estimates how long this will take)
%     totalTimeSeconds = 3*iterations*2^6*3
%     totalTimeMinutes = totalTimeSeconds/60
%     totalTimeHours = totalTimeMinutes/60

%Choose the minimum change for the value of the location
epsilon = 1;

%Choose the scaling factor for the cost function, which weights the
%importance of distance from the attachment point to the nearest point on
%the model body
%Scaling Values
GTorque = 0.0001;           %Cost weight for the difference between human and robot torque      
GDiameter40 = 1e7;              %Cost Weight for the diameter of the festo muscle
GDiameter20 = 1e3;
G = 1000;                   %Cost weight for the distance from the attachment point to the model body
GLength = 100;

%Adjust the axis range for the Torque plots
caxisRange = [-40 150];

%Adjust the axis for the robot model plot
axisLimits = [-1 1 -1 1 -1.25 0.75];

%% ----------------- Setup -------------------------------
%Include relevant folders
addpath('Open_Sim_Bone_Geometry')
addpath('Functions')
addpath('Human_Data')

%% ------------- Humanoid Model --------------
%Runs the humanoid model. Only run if you need to update the data
%run("HumanoidMuscleCalculation.m")

%Loads important data for the human model. Data was previously created and
%then stored, for quicker load time.
%Data saved: Back, Bi_Hip, Calves, Foot, Toe, Uni_Hip
load(strcat('Human_', ChooseJoint, '_Data.mat'));

%% ------------- Robot Model -----------------
%Runs the bipedal model for initial calculations and creating the proper
%classes
run("RobotPAMCalculationOptimization.m")    

%Set up the original robot torque if I want to see if the error is better
OriginalRobotTorque1 = RobotTorque1;
OriginalRobotTorque2 = RobotTorque2;
if exist('RobotTorque3', 'var') == 1
    OriginalRobotTorque3 = RobotTorque3;
    if exist('RobotTorque4', 'var') == 1
        OriginalRobotTorque4 = RobotTorque4;
    end
end


%% ------------- Optimization ------------------
%The robot model has now constructed a preliminary model and generated
%torques. We will now begin to move around the attachment points to see if
%we can generate better torques

%Load in points that construct the relevant bone models to the muscles.
%This will be used as a part of our cost function, to evaluate how far away
%our new muscle attachments are. 
if isequal(ChooseJoint, 'Back')
    PointsFile = 'Pelvis_R_Mesh_Points.xlsx';
    Pelvis = xlsread(PointsFile)';
    
    PointsFile = 'Spine_Mesh_Points.xlsx';
    Home = Joint1a.Home;
    Spine = xlsread(PointsFile)'+Home;
    
    PointsFile = 'Sacrum_Mesh_Points.xlsx';
    Sacrum = xlsread(PointsFile)';
end

%Determine how many muscles are included in the algorithm
MuscleNum = size(Muscles, 2);

%Calculate the distance from the attachment point to the nearest point on
%the robot body
%The first step is to get all the attachment points into the same
%reference frame. 

L = Muscle1.Location;
iii = 0;                %variable that remembers which joint we are looking at. Will update to 1 for the first joint, 2 for the second cross over joint, and so on.
for k = 1:size(Muscle1.Location, 2)
    for ii = 1:size(Muscle1.CrossPoints, 2)
        iii = iii+1;
        if k == Muscle1.CrossPoints(ii)
            L(:, k) = L(:, k)+Muscle1.TransformationMat(1:3, 4, iii);
        end
    end
end

%Create a tensor to store all the points that describe the bone mesh
bone{1} = Spine;
bone{2} = Sacrum;
bone{3} = Pelvis;

%Evaluate cost function for the initial set of attachment points
% C = zeros(1, MuscleNum*2^6*iterations);   %Don't do this. Need to look at
% the min later on, and initializing with zeros fucks it up. Maybe init
% with 1's and then multiply by a lot
eC(1) = 0;              %Error component of the cost function
mC(1) = 0;              %Muscle length component of the cost function
dC(1) = 0;              %Muscle diameter component of the cost function
C(1) = 0;               %Cost function value

k = 1;

for ii = 1:100
    for iii = 1:100
        eC(1) = eC(1) + abs(HumanTorque1(ii, iii) - RobotTorque1(ii, iii));
        eC(1) = eC(1) + abs(HumanTorque2(ii, iii) - RobotTorque2(ii, iii));
        if exist('RobotTorque3', 'var') == 1
            eC(1) = eC(1) + abs(HumanTorque3(ii, iii) - RobotTorque3(ii, iii));
            if exist('RobotTorque4', 'var') == 1
                eC(1) = eC(1) + abs(HumanTorque4(ii, iii) - RobotTorque4(ii, iii));
            end
        end
    end
end

%For this part of the cost function, we must sum across all muscles
for i = 1:MuscleNum
    Diameter = Muscles{i}.Diameter;
    MLength = Muscles{i}.MuscleLength;
    %Increase the cost based on length of muscle
    for ii = 1:length(MLength)
        mC(k) = mC(k) + GLength*MLength(ii);
    end

    %Increase the cost based on the diameter of the muscle
    if Diameter == 40
        dC(k) = dC(k) + GDiameter40;
    elseif Diameter == 20
        dC(k) = dC(k) + GDiameter20;
    end
    MLength = [];
end
C(1) = eC(1) + mC(1) + dC(1);

beginOptimization = 1;          %Flags that optimization has begun for the optimization pam calculations
%Perturb original location by adding epsilon to every cross point
%Will then move to creating an algorith that will add and subtract to
%different axes

%Start the optimization as a for loop to create all the points of a cube.
%later, automate this to be in a while loop that go until a threshold
ep1 = zeros(3, 1);              %Change in the first cross point for the Muscle
ep2 = zeros(3, 1);              %Change in the second cross point for the muscle
neg = [1, -1];
k = 2;                  %index for the cost function. Start at 2, since 1 was the original point
shrinkEp = 0;                   %Flag. Once it reaches the number of muscles, it will scale epsilon down to refine the search
myBreak = 0;                    %Flag for if epsilon becomes extremely small, in which case the optimization should end
previousBestC = C(1);           %Variable that stores the best value from the previous series of calculations. Compares to newest best ot determine if actions need to be takne
previousBestIteration = 1;      %Variable that stores the iteration number of the lowest cost value

%some initialization
for m = 1:MuscleNum
    LocationTracker1{m} = zeros(3, MuscleNum*2^6*iterations);
    LocationTracker2{m} = zeros(3, MuscleNum*2^6*iterations);
    StartingLocation1{m} = zeros(3, 1);
    StartingLocation2{m} = zeros(3, 1);
end
Cross = zeros(1, 3);

%We begin with the point before the crossing point
for m = 1:MuscleNum
    Cross(m) = Muscles{m}.CrossPoints(1);  %Will need to change this indexing for muscles that have multiple crossing points
    StartingLocation1{m} = Muscles{m}.Location(:, Cross(m) - 1);
    StartingLocation2{m} = Muscles{m}.Location(:, Cross(m));
    LocationTracker1{m} = StartingLocation1{m};
    LocationTracker2{m} = StartingLocation2{m};
end

tic
disp('Beginning Optimization');
for iiii = 1:iterations
    for m = 1:MuscleNum
        for k1 = 1:2
            ep1(1) = epsilon*neg(k1);
            for k2 = 1:2
                ep1(2) = epsilon*neg(k2);
                for k3 = 1:2
                    ep1(3) = epsilon*neg(k3);
                    for k4 = 1:2
                        ep2(1) = epsilon*neg(k4);
                        for k5 = 1:2
                            ep2(2) = epsilon*neg(k5);
                            for k6 = 1:2
                                ep2(3) = epsilon*neg(k6);

                                %Change the Locaiton of the first and
                                %second crossing point
                                Location{m}(:, Cross(m) - 1) = StartingLocation1{m} + ep1;
                                Location{m}(:, Cross(m)) = StartingLocation2{m} + ep2;
                                
                                %Update all of the Location Tracker
                                %variables to identify current
                                %configuration
                                for config = 1:MuscleNum
                                    LocationTracker1{config}(:, k) = Location{config}(:, Cross(config) - 1);
                                    LocationTracker2{config}(:, k) = Location{config}(:, Cross(config));
                                end
                                
                                run('RobotPAMCalculationOptimization.m')

                                %Evaluate cost function for the new set of attachment points
                                eC(k) = 0;
                                mC(k) = 0;
                                dC(k) = 0;
                                C(k) = 0;

                                for ii = 1:100
                                    for iii = 1:100
                                        eC(k) = eC(k) + abs(HumanTorque1(ii, iii) - RobotTorque1(ii, iii));
                                        eC(k) = eC(k) + abs(HumanTorque2(ii, iii) - RobotTorque2(ii, iii));
                                        if exist('RobotTorque3', 'var') == 1
                                            eC(k) = eC(k) + abs(HumanTorque3(ii, iii) - RobotTorque3(ii, iii));
                                            if exist('RobotTorque4', 'var') == 1
                                                eC(k) = eC(k) + abs(HumanTorque4(ii, iii) - RobotTorque4(ii, iii));
                                            end
                                        end
                                    end
                                end

                                %Increase the cost based on length of muscle
                                for ii = 1:length(Muscles{m}.MuscleLength)
                                    mC(k) = mC(k) + GLength*Muscles{m}.MuscleLength(ii);
                                end

                                %Increase the cost based on the diameter of the muscle
                                if Muscles{m}.Diameter == 40
                                    dC(k) = dC(k) + GDiameter40;
                                elseif Muscles{m}.Diameter == 20
                                    dC(k) = dC(k) + GDiameter20;
                                end
                                
                                C(k) = eC(k) + mC(k) + dC(k);

                                disp(['Iteration number ', num2str(k-1), ' out of of ', num2str(2^6*iterations*MuscleNum), '.']);
                                k = k+1;            %Increment k for the next point of the cost function
                            end
                        end
                    end
                end
            end
        end
% %         [a, b] = min(C(end-2^6:end));
%         [a, b] = min(C);
% 
%         %If the previous starting location is still the location with the
%         %minimum cost, change the step size of epsilon.
%         if same(StartingLocation1{m}, LocationTracker1{m}(:, b))
%             if same(StartingLocation2{m}, LocationTracker2{m}(:, b))
%                 shrinkEp = shrinkEp+1;
%                 if shrinkEp == MuscleNum
%                     shrinkEp = 0;
%                     epsilon = 0.1*epsilon;
%                     if epsilon < 10^-6
%                         myBreak = 1;
%                         break
%                     end
%                 end
%             end
%         end
%         StartingLocation1{m} = LocationTracker1{m}(:, b);               %Update the next round of optimization with the location with minimum cost
%         StartingLocation2{m} = LocationTracker2{m}(:, b);
%         if myBreak == 1             %Likely should change the loop to be a while loop for the iterations. Can tackle that in another branch soon
%             break
%         end
    end
%         [a, b] = min(C(end-2^6:end));
    [currentBestC, currentBestIteration] = min(C);
    if currentBestIteration == previousBestIteration
        epsilon = epsilon*0.5;
        if epsilon < 10^-6
            myBreak = 1;
        end
    end

    for n = 1:MuscleNum
        StartingLocation1{n} = LocationTracker1{n}(:, currentBestIteration);               %Update the next round of optimization with the location with minimum cost
        StartingLocation2{n} = LocationTracker2{n}(:, currentBestIteration);
    end
 
    previousBestIteration = currentBestIteration;
    previousBestC = currentBestC;
    
    if myBreak == 1             %Likely should change the loop to be a while loop for the iterations. Can tackle that in another branch soon
        break
    end
end
timeElapsed = toc;
%%------------------ Plotting ----------------------
% run('OptimizationPlotting.m')

figure
plot(C)
xlabel('Iterations')
ylabel('Cost Value')

%Create an average of the iterationst to create viewable epochs
for i = 1:iterations
    startP = (i-1)*MuscleNum*2^6+1;             %Starting Point for summation of the epoch
    endP = i*MuscleNum*2^6;                     %Ending poster for summation of the epoch
    if i*MuscleNum*2^6 < length(C)
        averageC(i) = sum(C(startP:endP));
    else
        averageC(i) = sum(C(startP:end));
    end
end

figure
plot(averageC)
xlabel('Epochs')
ylabel('Cost Value')