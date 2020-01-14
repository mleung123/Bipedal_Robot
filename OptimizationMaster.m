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
iterations = 2;

%Choose the minimum change for the value of the location
epsilon = 0.01;

%Choose the scaling factor for the cost function, which weights the
%importance of distance from the attachment point to the nearest point on
%the model body
%Scaling Values
GTorque = 0.0001;           %Cost weight for the difference between human and robot torque      
GDiameter = 1;              %Cost Weight for the diameter of the festo muscle
G = 1000;                   %Cost weight for the distance from the attacment point to the model body

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
%Runs the bipedal model
run("RobotPAMCalculationOptimization.m")    

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

Muscles{1} = Muscle1;

%Calculate the distance from the attachment point to the nearest point on
%the robot body
%The first step is to get all the attachment points into the same
%reference frame. 

L = Muscle1.Location;
iii = 0;                %variable that remembers which joint we are looking at. Will update to 1 for the first joint, 2 for the second cross over joint, and so on.
for i = 1:size(Muscle1.Location, 2)
    for ii = 1:size(Muscle1.CrossPoints, 2)
        iii = iii+1;
        if i == Muscle1.CrossPoints(ii)
            L(:, i) = L(:, i)+Muscle1.TransformationMat(1:3, 4, iii);
        end
    end
end

%Create a tensor to store all the points that describe the bone mesh
bone{1} = Spine;
bone{2} = Sacrum;
bone{3} = Pelvis;

%Evaluate cost function for the initial set of attachment points
C(1) = 0;

for ii = 1:100
    for iii = 1:100
        C(1) = C(1) + abs(HumanTorque1(ii, iii) - RobotTorque1(ii, iii));
    end
end

%Perturb original location
newLocation = Muscles{1}.Location + epsilon;

Muscles{2} = PamData(Muscle1.Muscle, newLocation, Muscle1.CrossPoints, Muscle1.MIF, Muscle1.TransformationMat, Muscle1.Axis);

for i = 1:divisions
    Torque{2}(:, i, :) = Muscles{2}.Torque(:, ((i-1)*divisions)+1:i*divisions, :);
end

%Designate what needs to be plotted
NewRobotTorque1 = Torque{2}(:, :, 1);
NewRobotTorque2 = Torque{2}(:, :, 2);
NewRobotTorque3 = Torque{2}(:, :, 3);

%Evaluate cost function for the new set of attachment points
C(2) = 0;

for ii = 1:divisions
    for iii = 1:divisions
        C(2) = C(2) + abs(HumanTorque1(ii, iii) - NewRobotTorque1(ii, iii));
    end
end


%% -------------------- Plotting ----------------------
%Generate Plots to see how the torques changed after optimization, and
%whether they are better/more in sync with the human model 

%Plot how the cost function changes over the iterations

%Plots for the new robot configuration
figure
surf(RobotAxis1*180/pi, RobotAxis2*180/pi, NewRobotTorque1, 'EdgeColor', 'none')
title(RobotTitle1); xlabel(RobotAxis1Label); ylabel(RobotAxis2Label)
zlabel('Torque, N*m')
colorbar; caxis(caxisRange)

figure
surf(RobotAxis1*180/pi, RobotAxis2*180/pi, NewRobotTorque2, 'EdgeColor', 'none')
title(RobotTitle2); xlabel(RobotAxis1Label); ylabel(RobotAxis2Label)
zlabel('Torque, N*m')
colorbar; caxis(caxisRange)

if exist('RobotTorque3', 'var') == 1
    figure
    surf(RobotAxis1*180/pi, RobotAxis2*180/pi, NewRobotTorque3, 'EdgeColor', 'none')
    title(RobotTitle3); xlabel(RobotAxis1Label); ylabel(RobotAxis2Label)
    zlabel('Torque, N*m')
    colorbar; caxis(caxisRange)
end

if exist('RobotTorque4', 'var') == 1
    figure
    surf(RobotAxis1*180/pi, RobotAxis2*180/pi, NewRobotTorque4, 'EdgeColor', 'none')
    title(RobotTitle4); xlabel(RobotAxis1Label); ylabel(RobotAxis2Label)
    zlabel('Torque, N*m')
    colorbar; caxis(caxisRange)
end

%Plots for the error from the first robot configuration to the new robot
%configuration
Error1 = HumanTorque1 - RobotTorque1;
Error2 = HumanTorque2 - RobotTorque2;

if exist('HumanTorque3', 'var') == 1
    Error3 = HumanTorque3 - RobotTorque3;
    if exist('HumanTorque4', 'var') == 1
        Error4 = HumanTorque4 - RobotTorque4;
    end
end

NewError1 = HumanTorque1 - NewRobotTorque1;
NewError2 = HumanTorque2 - NewRobotTorque2;

if exist('HumanTorque3', 'var') == 1
    NewError3 = HumanTorque3 - NewRobotTorque3;
    if exist('HumanTorque4', 'var') == 1
        NewError4 = HumanTorque4 - NewRobotTorque4;
    end
end

figure
surf(RobotAxis1*180/pi, RobotAxis2*180/pi, Error1, 'EdgeColor', 'none')
title(strcat(RobotTitle1, ' Error')); xlabel(RobotAxis1Label); ylabel(RobotAxis2Label)
zlabel('Torque, N*m')
colorbar; caxis(caxisRange)

figure
surf(RobotAxis1*180/pi, RobotAxis2*180/pi, Error2, 'EdgeColor', 'none')
title(strcat(RobotTitle2, ' Error')); xlabel(RobotAxis1Label); ylabel(RobotAxis2Label)
zlabel('Torque, N*m')
colorbar; caxis(caxisRange)

if exist('HumanTorque3', 'var') == 1
    figure
    surf(RobotAxis1*180/pi, RobotAxis2*180/pi, Error3, 'EdgeColor', 'none')
    title(strcat(RobotTitle3, ' Error')); xlabel(RobotAxis1Label); ylabel(RobotAxis2Label)
    zlabel('Torque, N*m')
    colorbar; caxis(caxisRange)
end

if exist('HumanTorque4', 'var') == 1
    figure
    surf(RobotAxis1*180/pi, RobotAxis2*180/pi, Error4, 'EdgeColor', 'none')
    title(strcat(RobotTitle4, ' Error')); xlabel(RobotAxis1Label); ylabel(RobotAxis2Label)
    zlabel('Torque, N*m')
    colorbar; caxis(caxisRange)
end


figure
surf(RobotAxis1*180/pi, RobotAxis2*180/pi, NewError1, 'EdgeColor', 'none')
title(strcat('New ', RobotTitle1, ' Error')); xlabel(RobotAxis1Label); ylabel(RobotAxis2Label)
zlabel('Torque, N*m')
colorbar; caxis(caxisRange)

figure
surf(RobotAxis1*180/pi, RobotAxis2*180/pi, NewError2, 'EdgeColor', 'none')
title(strcat('New ', RobotTitle2, ' Error')); xlabel(RobotAxis1Label); ylabel(RobotAxis2Label)
zlabel('Torque, N*m')
colorbar; caxis(caxisRange)

if exist('HumanTorque3', 'var') == 1
    figure
    surf(RobotAxis1*180/pi, RobotAxis2*180/pi, NewError3, 'EdgeColor', 'none')
    title(strcat('New ', RobotTitle3, ' Error')); xlabel(RobotAxis1Label); ylabel(RobotAxis2Label)
    zlabel('Torque, N*m')
    colorbar; caxis(caxisRange)
end

if exist('HumanTorque4', 'var') == 1
    figure
    surf(RobotAxis1*180/pi, RobotAxis2*180/pi, NewError4, 'EdgeColor', 'none')
    title(strcat('New ', RobotTitle4, ' Error')); xlabel(RobotAxis1Label); ylabel(RobotAxis2Label)
    zlabel('Torque, N*m')
    colorbar; caxis(caxisRange)
end

%Figure that prints the model of the robot and the muscle

if Muscle1.Diameter == 40
    LW = 4;
elseif Muscle1.Diameter == 20
    LW = 2;
else
    LW = 1;
end

figure
hold on
plot3(0, 0, 0, 'o', 'color', 'r')
plot3(Spine(1, :), -Spine(3, :), Spine(2, :), '.', 'color', 'b')
plot3(Sacrum(1, :), -Sacrum(3, :), Sacrum(2, :), '.', 'color', 'b')
plot3(Pelvis(1, :), -Pelvis(3, :), Pelvis(2, :), '.', 'color', 'b')
plot3(L(1, :), -L(3, :), L(2, :), 'color', 'r', 'LineWidth', LW)
axis(axisLimits)
hold off