% Robot PAM Calculation Optimization
% Author: Connor Morrow
% Date: 12/11/2019
% Description: This script calculate the torque generated across joints by
% the PAMs that cross over them. It is intended to be used by the 
% optimization script.

if exist('divisions', 'var') == 0
    divisions = 100;
end

if exist('ChooseJoint', 'var') == 0
    ChooseJoint = 'Back';
end

%Flag that tells the code to not run pieces that have been calculated
%previously
if exist('beginOptimization', 'var') == 0
    beginOptimization = 0;
end

if isequal(ChooseJoint, 'Back')
    if beginOptimization == 0
        %Back x axis rotation
        Raxis = [1; 0; 0];
        MaxTheta = 15*pi/180;
        MinTheta = -15*pi/180;
        Home = [-0.1007; 0.0815; 0];                   
        Joint1a = JointData('BackX', Raxis, MaxTheta, MinTheta, Home, divisions);

        %Back y rotation
        Raxis = [0; 1; 0];
        MaxTheta = 0;
        MinTheta =0;               %Ben's script lists the min and max, however only 0 is used. Why?
        Home = [-0.1007; 0.0815; 0];
        Joint1b = JointData('BackY', Raxis, MaxTheta, MinTheta, Home, divisions);

        %Back z rotation
        Raxis = [0; 0; 1];
        MaxTheta = 15*pi/180;
        MinTheta = -45*pi/180;
        Home = [-0.1007; 0.0815; 0];
        Joint1c = JointData('BackZ', Raxis, MaxTheta, MinTheta, Home, divisions);

        R = zeros(3, 3, 1, divisions^2);
        T = zeros(4, 4, 1, divisions^2);
        ii = 1;
        for i = 1:divisions
            for j = 1:divisions
                R(:, :, 1, ii) = Joint1a.RotMat(:, :, i)*Joint1b.RotMat(:, :, i)*Joint1c.RotMat(:, :, j);
                T(:, :, 1, ii) = [R(:, :, 1, ii), Home; 0 0 0 1];
                ii = ii+1;
            end
        end

        T(:, :, 2, :) = T(:, :, 1, :);
        T(:, :, 3, :) = T(:, :, 1, :);
    end
        
%     %Erector Spinae p7 -> b2    
%         ESLocation = [-0.122, -0.158, -0.072, -0.039, 0.005, -0.032, -0.072, -0.04, -0.019;
%                     -0.051, 0.054, 0.172, 0.179, 0.027, 0.027, 0.175, 0.182, 0.048;
%                     0.078, 0.041, 0.031, 0.029, 0.047, 0.048, 0.048, 0.045, 0.059];

    %The following Location is a reduction in points to simplify the
    %optimization code. Return to the above location when running it for real
    
    %PLEASE TO DO NOT FORGET TO COMMENT OUT WHEN THE OPTIMIZATION IS IN A
    %USABLE STATE
    %------------------------------------------------------------------------------------------------------------------------------------
    
    if beginOptimization == 0
        Location1 = [-0.122, -0.158, -0.072;
                    -0.051, 0.054, 0.172;
                    0.078, 0.041, 0.031];
        ESCrossPoints = 3;                    %Via points are the points where a transformation matrix is needed. Typically wrap point + 1
        ESMIF = 2500;
        Axis1 = [10, 20, 30];                           %The axis of interest when calculating the moment arm about each joint. The axis is 1, but is listed as 10 so that the cross product doesn't rotate the resulting vector. See PamData > CrossProd
    end

    Muscle1 = PamData('Erector Spinae', Location1, ESCrossPoints, ESMIF, T, Axis1);
    
    Torque1 = Muscle1.Torque;
    
    %Reorganize the torque calculations into a matrix for 3D plotting
    for i = 1:divisions
        Torque1M(:, i, :) = Torque1(:, ((i-1)*divisions)+1:i*divisions, :);
    end
    
    %Transposing to match Ben's results
    for i = 1:size(Torque1M, 3)
        Torque1M(:, :, i) = Torque1M(:, :, i)';
    end
    
    %Including a way to make the data generic, so that things can be
    %plotted in one location instead of spread out through all of the
    %different sections
    RobotAxis1 = Joint1c.Theta;
    RobotAxis1Label = 'Back Flexion, Degrees';
    RobotAxis2 = Joint1a.Theta;
    RobotAxis2Label = 'Lumbar Bending, Degrees';
    RobotTorque1 = Torque1M(:, :, 1);
    RobotTorque2 = Torque1M(:, :, 2);
    RobotTorque3 = Torque1M(:, :, 3);
    RobotTitle1 = 'Robot Back Torque, Erector Spinae, X Axis';
    RobotTitle2 = 'Robot Back Torque, Erector Spinae, Y Axis';
    RobotTitle3 = 'Robot Back Torque, Erector Spinae, Z Axis';
    
    %Store all necessary variables into a cell array for the optimization
    %script
    Muscles = {Muscle1};
    
    
elseif isequal(ChooseJoint, 'Bi_Hip')
    if beginOptimization == 0
        %Hip Joint z rotation
        Raxis = [0; 0; 1];
        MaxTheta = 110*pi/180;
        MinTheta = -15*pi/180;
        Home = [-0.0707; -0.0661; 0.0835];                   %Home position from the Tibia
        Joint1 = JointData('HipZ', Raxis, MaxTheta, MinTheta, Home, divisions);

        T_h = Joint1.TransformationMat;

        %Knee z rotation
        Raxis = [0; 0; 1];
        MaxTheta = 0.17453293;
        MinTheta = -2.0943951;
        Home = [-0.0707; -0.0661; 0.0835];      %Not actually the home position, but a placeholder
        Joint2 = JointData('Knee', Raxis, MaxTheta, MinTheta, Home, divisions);

        knee_angle_x = [-2.0944; -1.74533; -1.39626; -1.0472; -0.698132; -0.349066; -0.174533;  0.197344;  0.337395;  0.490178;   1.52146;   2.0944];
        knee_x =       [-0.0032;  0.00179;  0.00411;  0.0041;   0.00212;    -0.001;   -0.0031; -0.005227; -0.005435; -0.005574; -0.005435; -0.00525];
        KneeXFunc = fit(knee_angle_x,knee_x,'cubicspline');
        knee_angle_y = [-2.0944; -1.22173; -0.523599; -0.349066; -0.174533;  0.159149; 2.0944];
        knee_y =       [-0.4226;  -0.4082;    -0.399;   -0.3976;   -0.3966; -0.395264; -0.396];
        KneeYFunc = fit(knee_angle_y,knee_y,'cubicspline');

        kneeHome = zeros(3, divisions);
        for j = 1:divisions
            kneeHome(:, j) = [KneeXFunc(Joint2.Theta(j)); KneeYFunc(Joint2.Theta(j)); 0];
        end

        T = zeros(4, 4, 2, divisions*divisions);
        ii = 1;
        for i = 1:divisions
            for j = 1:divisions
                T(:, :, 1, ii) = T_h(:,:, i);
                T(:, :, 2, ii) = [Joint2.RotMat(:, :, j), kneeHome(:, j); 0, 0, 0, 1]; %Change the knee position
                ii = ii + 1;
            end
        end
    end
    
    %Bicep Femoris, Long Head p5 -> t5  
    if beginOptimization == 0
        Location1 = [-0.126, -0.03, -0.023, 0.005;
                        -0.103, -0.036, -0.056, -0.378;
                        0.069, 0.029, 0.034, 0.035];
        BFCrossPoints = [2 2];
        BFMIF = 896;  %max isometric force
        Axis1 = [10 20 30;
                30 0 0];                           %The axis of interest when calculating the moment arm about each joint. Looking at x, y, z for hip, and only z for knee
    end
    Muscle1 = PamData('Bicep Femoris', Location1, BFCrossPoints, BFMIF, T, Axis1);

    Torque1x = Muscle1.Torque(1, :, 1);
    Torque1y = Muscle1.Torque(1, :, 2);
    Torque1z = Muscle1.Torque(1, :, 3);
    Torque2 = Muscle1.Torque(2, :, 1);
    
    %Create the Mesh of Torques to corespond with the joint angles
    Torque1xM = zeros(divisions, divisions); Torque1yM = zeros(divisions, divisions); Torque1zM = zeros(divisions, divisions); KneeTorqueMR = zeros(divisions, divisions); 
    for i = 1:divisions
        Torque1xM(:, i) = Torque1x(((i-1)*divisions)+1:i*divisions);
        Torque1yM(:, i) = Torque1y(((i-1)*divisions)+1:i*divisions);
        Torque1zM(:, i) = Torque1z(((i-1)*divisions)+1:i*divisions);
        Torque2M(:, i) = Torque2(((i-1)*divisions)+1:i*divisions);
    end
    
    %Including Generic variable name for plotting
    RobotAxis1 = Joint1.Theta;
    RobotAxis1Label = 'Hip Flexion, Degrees';
    RobotAxis2 = Joint2.Theta;
    RobotAxis2Label = 'Knee Flexion, Degrees';
    RobotTorque1 = Torque1xM;
    RobotTorque2 = Torque1yM;
    RobotTorque3 = Torque1zM;
    RobotTorque4 = Torque2M;
    RobotTitle1 = 'Robot Hip Torque, bifemlh, X axis';
    RobotTitle2 = 'Robot Hip Torque, bifemlh, Y axis';
    RobotTitle3 = 'Robot Hip Torque, bifemlh, Z axis';
    RobotTitle4 = 'Robot Knee Torque, bifemlh, Z axis';
    
elseif isequal(ChooseJoint, 'Calves')
    %Create a Joint object that calculates things like transformation
    %matrix
    %Note: Currently only goes for the matrices at minimum theta. Will
    %implement some iteration process to go from minimum to maximum. 
    if beginOptimization == 0
        Raxis = [-0.10501355; -0.17402245; 0.97912632];
        MaxTheta = 20*pi/180;
        MinTheta = -50*pi/180;
        Home = [0; -0.43; 0];                   %Home position from the Tibia
        Joint1 = JointData('Ankle', Raxis, MaxTheta, MinTheta, Home, divisions);

        Raxis = [0.7871796; 0.60474746; -0.12094949];
        MaxTheta = 0;
        MinTheta = 0;               %Ben's script lists the min and max, however only 0 is used. Why?
        Home = [-0.04877; -0.04195; 0.00792];   %Home position from the Talus
        Joint2 = JointData('Subtalar', Raxis, MaxTheta, MinTheta, Home, divisions);

        %Knee z rotation
        Raxis = [0; 0; 1];
        MaxTheta = 0.17453293;
        MinTheta = -2.0943951;
        Home = [-0.0707; -0.0661; 0.0835];      %Not actually the home position, but a placeholder
        Joint3 = JointData('Knee', Raxis, MaxTheta, MinTheta, Home, divisions);

        knee_angle_x = [-2.0944; -1.74533; -1.39626; -1.0472; -0.698132; -0.349066; -0.174533;  0.197344;  0.337395;  0.490178;   1.52146;   2.0944];
        knee_x =       [-0.0032;  0.00179;  0.00411;  0.0041;   0.00212;    -0.001;   -0.0031; -0.005227; -0.005435; -0.005574; -0.005435; -0.00525];
        KneeXFunc = fit(knee_angle_x,knee_x,'cubicspline');
        knee_angle_y = [-2.0944; -1.22173; -0.523599; -0.349066; -0.174533;  0.159149; 2.0944];
        knee_y =       [-0.4226;  -0.4082;    -0.399;   -0.3976;   -0.3966; -0.395264; -0.396];
        KneeYFunc = fit(knee_angle_y,knee_y,'cubicspline');

        kneeHome = zeros(3, divisions);
        for j = 1:divisions
            kneeHome(:, j) = [KneeXFunc(Joint3.Theta(j)); KneeYFunc(Joint3.Theta(j)); 0];
        end

        T_a = Joint1.TransformationMat(:, :, :);
        T_s = Joint2.TransformationMat(:, :, :);


        %Create a Mesh of the Ankle and MTP. First two dimensions are the
        %values of the transformation matrics. The third dimension determines
        %the joint being observed, and the fourth dimension is its location
        %in the mesh, which will need to be converted from a one dimensional
        %array to two dimensions
        T = zeros(4, 4, 3, divisions^2);
        ii = 1;
        for i = 1:divisions
            for j = 1:divisions
                T(:, :, 1, ii) = T_a(:, :, i);            %Keep the ankle at one point as the MTP changes
                T(:, :, 2, ii) = T_s(:, :, i);            %Subtalar doesn't change
                ii = ii + 1;
            end
        end
    end
    
    %Soleus a1 -> t1
    if beginOptimization == 0
        Location3 = [0.047, 0;
                    -0.113, 0.031;
                    -0.002, -0.005];
        SCrossPoints = [2 2];
        SMIF = 3549;  %max isometric force
        Axis3 = [3; 1];                           %The axis of interest when calculating the moment arm about each joint        
    end
    

    Muscle3 = PamData('Soleus', Location3, SCrossPoints, SMIF, T, Axis3);
    
    T(:, :, 2:3, :) = T(:, :, 1:2, :);
    ii = 1;
    for i = 1:divisions
        for j = 1:divisions
            T(:, :, 1, ii) = [Joint3.RotMat(:, :, j), kneeHome(:, j); 0, 0, 0, 1]; %Change the knee position
            ii = ii + 1;
        end
    end
    
    %Medial Gastroocnemius a1 -> f4      
    if beginOptimization == 0
        Location1 = [  0.015, -0.03, 0;
                        -0.374, -0.402, 0.031;
                        -0.025, -0.026, -0.005];
        MGCrossPoints = [3 3 3];
        MGMIF = 1558;  %max isometric force
        Axis1 = [3; 3; 1];                           %The axis of interest when calculating the moment arm about each joint
    end  

    Muscle1 = PamData('Medial Gastroocnemius', Location1, MGCrossPoints, MGMIF, T, Axis1);
    
    %Lateral Gastrocenemius a1 -> f5
    if beginOptimization == 0
        Location2 = [0.009, -0.022, 0;
                        -0.378, -0.395, 0.031;
                        0.027, 0.027, -0.005];
                 
        LGCrossPoints = [3 3 3];
        LGMIF = 683;  %max isometric force
        Axis2 = [3; 3; 1];                           %The axis of interest when calculating the moment arm about each joint
    end
    Muscle2 = PamData('Lateral Gastrocenemius', Location2, LGCrossPoints, LGMIF, T, Axis2);
    
    %Torque Calcs, "R" for robot
    Torque1 = Muscle1.Torque(2, :) + Muscle2.Torque(2, :);   %Torque about the ankle
    Torque2 = Muscle1.Torque(1, :) + Muscle2.Torque(1, :);        %Torque about the knee
    Torque3 = Muscle3.Torque(1, :);                       %Torque about Ankle due to Soleus
    
    %Create the Mesh of Torques to corespond with the joint angles
    Torque1M = zeros(divisions, divisions); Torque3M = zeros(divisions, divisions); Torque2M = zeros(divisions, divisions);
    for i = 1:divisions
        Torque1M(:, i) = Torque1(((i-1)*divisions)+1:i*divisions);
        Torque2M(:, i) = Torque2(((i-1)*divisions)+1:i*divisions);
        Torque3M(:, i) = Torque3(((i-1)*divisions)+1:i*divisions);
        
    end
    
    %Including Generic variable name for plotting
    RobotAxis1 = Joint1.Theta;
    RobotAxis1Label = 'Ankle Flexion, Degrees';
    RobotAxis2 = Joint3.Theta;
    RobotAxis2Label = 'Knee Flexion, Degrees';
    RobotTorque1 = Torque2M;
    RobotTorque2 = Torque1M;
    RobotTorque3 = Torque3M;
    RobotTitle1 = 'Robot Knee Torque, Gastrocnemius, Z axis';
    RobotTitle2 = 'Robot Ankle Torque, Gastrocnemius, Z` axis';
    RobotTitle3 = 'Robot Ankle Torque, Soleus, Z` axis';
    
elseif isequal(ChooseJoint, 'Foot')
    if beginOptimization == 0
        Raxis = [-0.10501355; -0.17402245; 0.97912632];
        MaxTheta = 20*pi/180;
        MinTheta = -50*pi/180;
        Home = [0; -0.43; 0];                   %Home position from the Tibia
        Joint1 = JointData('Ankle', Raxis, MaxTheta, MinTheta, Home, divisions);

        Raxis = [0.7871796; 0.60474746; -0.12094949];
        MaxTheta = 35*pi/180;
        MinTheta = -25*pi/180;
        Home = [-0.04877; -0.04195; 0.00792];   %Home position from the Talus
        Joint2 = JointData('Subtalar', Raxis, MaxTheta, MinTheta, Home, divisions);

        T_a = Joint1.TransformationMat(:, :, :);
        T_s = Joint2.TransformationMat(:, :, :);

        %Create a Mesh of the Ankle and MTP. First two dimensions are the
        %values of the transformation matrics. The third dimension determines
        %the joint being observed, and the fourth dimension is its location
        %in the mesh, which will need to be converted from a one dimensional
        %array to two dimensions
        T = zeros(4, 4, 3, divisions^2);
        ii = 1;
        for i = 1:divisions
            for j = 1:divisions
                T(:, :, 1, ii) = T_a(:, :, i);            %Keep the ankle at one point as the MTP changes
                T(:, :, 2, ii) = T_s(:, :, j);            
                ii = ii + 1;
            end
        end
    end
    
    %Tibialis Posterior t4 -> a4
    if beginOptimization == 0
        Location1 = [  -0.02, -0.014, 0.042, 0.077;
                        -0.085, -0.405, 0.033, 0.016;
                        0.002, -0.023, -0.029, -0.028];
        TPCrossPoints = [3 3];
        TPMIF = 3549;  %max isometric force
        Axis1 = [3; 1];                           %The axis of interest when calculating the moment arm about each joint
    end
    Muscle1 = PamData('Tibialis Posterior', Location1, TPCrossPoints, TPMIF, T, Axis1);
    
    %Tibialis Anterior t2 -> a3
    if beginOptimization == 0
        Location2 = [0.006, 0.033, 0.117;
                    -0.062, -0.394, 0.014;
                    0.047, 0.007, -0.036];    
        TACrossPoints = [3 3];
        TAMIF = 905;  %max isometric force
        Axis2 = [3; 1];                           %The axis of interest when calculating the moment arm about each joint
    end
    Muscle2 = PamData('Tibialis Posterior', Location2, TACrossPoints, TAMIF, T, Axis2);
    
    %Peroneus Brevis t2 -> a2
    if beginOptimization == 0
        Location3 = [0.006, -0.02, -0.014, 0.047, 0.079;
                    -0.062, -0.418, -0.429, 0.027, 0.022;
                    0.047, 0.028, 0.029, 0.023, 0.034];
        PBCrossPoints = [4 4];
        PBMIF = 435;  %max isometric force
        Axis3 = [3; 1];                           %The axis of interest when calculating the moment arm about each joint
    end
    Muscle3 = PamData('Peroneus Brevis', Location3, PBCrossPoints, PBMIF, T, Axis3);
    
    %Peroneus Longus t2 -> a3
    if beginOptimization == 0
        Location4 = [0.005, -0.021, -0.016, 0.044, 0.048, 0.085, 0.117;
                    -0.062, -0.42, -0.432, 0.023, 0.011, 0.007, 0.014;
                    0.047, 0.029, 0.029, 0.022, 0.028, 0.012, -0.036];
        PLCrossPoints = [4 4];
        PLMIF = 943;  %max isometric force
        Axis4 = [3; 1];                           %The axis of interest when calculating the moment arm about each joint
    end
    Muscle4 = PamData('Peroneus Longus', Location4, PLCrossPoints, PLMIF, T, Axis4);
    
    %Peroneus Tertius t2 -> a2
    if beginOptimization == 0
        Location5 = [0.006, 0.023, 0.079;
                      -0.062, -0.407, 0.016;
                      0.079, 0.022, 0.034];        
        PTCrossPoints = [3 3];
        PTMIF = 180;  %max isometric force
        Axis5 = [3; 1];                           %The axis of interest when calculating the moment arm about each joint
    end
    Muscle5 = PamData('Peroneus Tertius', Location5, PTCrossPoints, PTMIF, T, Axis5);
    
    %Torque Calcs, "R" for robot
    Torque1 = Muscle1.Torque(1, :) + Muscle2.Torque(1, :) + Muscle3.Torque(1, :) + Muscle4.Torque(1, :) + Muscle5.Torque(1, :);
    Torque2 = Muscle1.Torque(2, :) + Muscle2.Torque(2, :) + Muscle3.Torque(2, :) + Muscle4.Torque(2, :) + Muscle5.Torque(2, :);

    Torque1M = zeros(divisions, divisions); Torque2M = zeros(divisions, divisions);
    %Create the Mesh of Torques to corespond with the joint angles
    for i = 1:divisions
        Torque1M(:, i) = Torque1(((i-1)*divisions)+1:i*divisions);
        Torque2M(:, i) = Torque2(((i-1)*divisions)+1:i*divisions);
    end
    
    %Including Generic variable name for plotting
    RobotAxis1 = Joint1.Theta;
    RobotAxis1Label = 'Ankle Flexion, Degrees';
    RobotAxis2 = Joint2.Theta;
    RobotAxis2Label = 'MTP Flexion, Degrees';
    RobotTorque1 = Torque1M;
    RobotTorque2 = Torque2M;
    RobotTitle1 = 'Robot Ankle Torque, Z Axis';
    RobotTitle2 = 'Robot Subtalar Torque, X Axis';
    
elseif isequal(ChooseJoint, 'Toe')
    if beginOptimization == 0
        Raxis = [-0.10501355; -0.17402245; 0.97912632];
        MaxTheta = 20*pi/180;
        MinTheta = -50*pi/180;
        Home = [0; -0.43; 0];                   %Home position from the Tibia
        Joint1 = JointData('Ankle', Raxis, MaxTheta, MinTheta, Home, divisions);

        Raxis = [0.7871796; 0.60474746; -0.12094949];
        MaxTheta = 0;
        MinTheta = 0;               %Ben's script lists the min and max, however only 0 is used. Why?
        Home = [-0.04877; -0.04195; 0.00792];   %Home position from the Talus
        Joint2 = JointData('Subtalar', Raxis, MaxTheta, MinTheta, Home, divisions);

        Raxis = [-0.5809544; 0; 0.81393611];
        MaxTheta = 80*pi/180;
        MinTheta = -30*pi/180;
        Home = [0.1788; -0.002; 0.00108];       %Home Position from the Calcn
        Joint3 = JointData('MTP', Raxis, MaxTheta, MinTheta, Home, divisions);

        T_a = Joint1.TransformationMat(:, :, :);
        T_s = Joint2.TransformationMat(:, :, :);
        T_m = Joint3.TransformationMat(:, :, :);

        %Create a Mesh of the Ankle and MTP. First two dimensions are the
        %values of the transformation matrics. The third dimension determines
        %the joint being observed, and the fourth dimension is its location
        %in the mesh, which will need to be converted from a one dimensional
        %array to two dimensions
        T = zeros(4, 4, 3, divisions^2);
        ii = 1;
        for i = 1:divisions
            for j = 1:divisions
                T(:, :, 1, ii) = T_a(:, :, i);            %Keep the ankle at one point as the MTP changes
                T(:, :, 2, ii) = T_s(:, :, i);            %Subtalar doesn't change
                T(:, :, 3, ii) = T_m(:, :, j);            %Change the MTP while the subtalar stays the same
                ii = ii + 1;
            end
        end
    end
    
    % Creating PAM class module
    %Looking at the flexor digitorus longus, but now for the bipedal robot
    %The robot uses the same physical skeletal geometry, but changes where
    %the PAMs are attached when compared to muscles. Because of this,
    %transformation matrices from the skeletal structure will be reused
    %from above. 

    %For the robot, the wrapping locations also include a global origin
    %point (in this case, t4) and a global insertion point (in this case,
    %a7).


    %FDL Insertion points, found from AttachPoints_Robot. The first column is
    %the insertion point that shares a point with the tibia (t4). The last
    %point is a7, the insertion point for the foot
    if beginOptimization == 0
        Location1 = [-0.02, -0.015, 0.044, 0.071, 0.166, -0.002, 0.028, 0.044;
                        -0.085, -0.405, 0.032, 0.018, -0.008, -0.008, -0.007, -0.006;
                        0.002, -0.02, -0.028, -0.026, 0.012, 0.015, 0.022, 0.024];    

        Axis1 = [3; 1; 3];                           %The axis of interest when calculating the moment arm about each joint
        FDLCrossPoints = [3, 3, 6];
        FDLMIF = 310;  %max isometric force
    end
    Muscle1 = PamData('Flexor Digitorum Longus', Location1, FDLCrossPoints, FDLMIF, T, Axis1);
    

    %FHL t4 to a8
    if beginOptimization == 0
        Location2 = [-0.02, -0.019, 0.037, 0.104, 0.173, 0.016, 0.056;
                        -0.085, -.408, 0.028, 0.007, -0.005, -0.006, -0.01;
                        0.002, -0.017, -0.024, -0.026, -0.027, -0.026, -0.018];
        FHLCrossPoints = [3, 3, 6];
        FHLMIF = 322;  %max isometric force
        Axis2 = [3; 1; 3];                           %The axis of interest when calculating the moment arm about each joint
    end
    Muscle2 = PamData('Flexor Hallucis Longus', Location2, FHLCrossPoints, FHLMIF, T, Axis1);

    %EDL, t2 to a5
    if beginOptimization == 0
        Location3 = [0.006, 0.029, 0.092, 0.162, 0.005, 0.044;
            -0.062, -0.401, 0.039, 0.006, 0.005, 0.0;
            0.047, 0.007, 0.0, 0.013, 0.015, 0.025];
        EDLCrossPoints = [3, 3, 5];
        EDLMIF = 512;  %max isometric force
    end
    Muscle3 = PamData('Extensor Digitorum Longus', Location3, EDLCrossPoints, EDLMIF, T, Axis1);


    %EHL t2 to a6
    if beginOptimization == 0
        Location4 = [0.006, 0.033, 0.097, 0.129, 0.173, 0.03, 0.056;
                    -0.062, -0.398, 0.039, 0.031, 0.014, 0.004, 0.003;
                    0.047, -0.008, -0.021, -0.026, -0.028, -0.024, -0.019];
        EHLViaPoints = [3, 3, 6];
        EHLMIF = 162;  %max isometric force
    end
    Muscle4 = PamData('Extensor Hallucis Longus', Location4, EHLViaPoints, EHLMIF, T, Axis1);

    %Torque Calcs, "R" for robot
    Torque1 = Muscle1.Torque(1, :, :) + Muscle2.Torque(1, :, :) + Muscle3.Torque(1, :, :) + Muscle4.Torque(1, :, :);
    Torque2 = Muscle1.Torque(2, :, :) + Muscle2.Torque(2, :, :) + Muscle3.Torque(2, :, :) + Muscle4.Torque(2, :, :);
    Torque3 = Muscle1.Torque(3, :, :) + Muscle2.Torque(3, :, :) + Muscle3.Torque(3, :, :) + Muscle4.Torque(3, :, :);

    %Create the Mesh of Torques to corespond with the joint angles
    Torque1M = zeros(divisions, divisions); Torque2M = zeros(divisions, divisions); Torque3M = zeros(divisions, divisions);
    for i = 1:divisions
        Torque1M(:, i) = Torque1(((i-1)*divisions)+1:i*divisions);
        Torque2M(:, i) = Torque2(((i-1)*divisions)+1:i*divisions);
        Torque3M(:, i) = Torque3(((i-1)*divisions)+1:i*divisions);
    end
    
    %Including Generic variable name for plotting
    RobotAxis1 = Joint1.Theta;
    RobotAxis1Label = 'Ankle Flexion, Degrees';
    RobotAxis2 = Joint3.Theta;
    RobotAxis2Label = 'MTP Flexion, Degrees';
    RobotTorque1 = Torque1M;
    RobotTorque2 = Torque2M;
    RobotTorque3 = Torque3M;
    RobotTitle1 = 'Robot Ankle Torque, Z Axis';
    RobotTitle2 = 'Robot Subtalar Torque, X Axis';
    RobotTitle3 = 'Robot MTP Torque, Z Axis';
    
elseif isequal(ChooseJoint, 'Uni_Hip')
    if beginOptimization == 0
        %Hip Joint x rotation
        Raxis = [1; 0; 0];
        MaxTheta = 20.6*pi/180;
        MinTheta = -30*pi/180;
        HomeH = [-0.0707; -0.0661; 0.0835];                   %Home position from the Tibia
        Joint1a = JointData('HipX', Raxis, MaxTheta, MinTheta, HomeH, divisions);  

        %Hip Joint z rotation
        Raxis = [0; 0; 1];
        MaxTheta = 110*pi/180;
        MinTheta = -15*pi/180;
        HomeH = [-0.0707; -0.0661; 0.0835];                   %Home position from the Tibia
        Joint1b = JointData('HipZ', Raxis, MaxTheta, MinTheta, HomeH, divisions);

        %Back rotation
        Raxis = [0; 0; 1];
        MaxTheta = 0;
        MinTheta = 0;
        HomeB = [-0.1007; 0.0815; 0];                   %Home position from the Tibia
        Joint2 = JointData('Back', Raxis, MaxTheta, MinTheta, HomeB, divisions);

        R = zeros(3, 3, 1, divisions^2);
        T = zeros(4, 4, 1, divisions^2);
        ii = 1;
        for i = 1:divisions
            for j = 1:divisions
                R(:, :, 1, ii) = Joint1a.RotMat(:, :, j)*Joint1b.RotMat(:, :, i);
                T(:, :, 1, ii) = [R(:, :, 1, ii), HomeH; 0 0 0 1];
                ii = ii+1;
            end
        end
    end
    
    %Gluteus Maximus p6 -> f3
    if beginOptimization == 0
        Location1 = [-0.162, -0.174, -0.069, -0.046, 0.005;
                      0.04, -0.033, -0.042, -0.116, -0.339;
                      0.023, 0.101, 0.067, 0.06, 0.022];
        GMCrossPoints = 3;
        GMMIF = 5047;  
        Axis1 = [10, 20, 30];
    end
    Muscle1 = PamData('Gluteus Maximus', Location1, GMCrossPoints, GMMIF, T, Axis1);
     
    %Adductor Magnus p9 -> f4
    if beginOptimization == 0
        Location2 = [-0.163, -0.059, -0.059, 0.015;
                      -0.013, -0.108, -0.108, -0.374;
                      0.005, -0.03, -0.03, -0.025];
        AMCrossPoints = 3;
        AMMIF = 2268;  
        Axis1 = [10, 20, 30];
    end
    Muscle2 = PamData('Adductor Magnus', Location2, AMCrossPoints, AMMIF, T, Axis1);
    
    %Iliacus p1 -> f4
    if beginOptimization == 0
        Location3 = [-0.055, -0.024, 0.015;
                    0.091, -0.057, -0.374;
                    0.085, 0.076, -0.025];         
        ICrossPoints = 3;
        IMIF = 1073;  
        Axis1 = [10, 20, 30];
    end
    Muscle3 = PamData('Iliacus', Location3, ICrossPoints, IMIF, T, Axis1);
    
    %Include the back to the transformtion matrix for the Psoas
    if beginOptimization == 0
        T(:, :, 2, :) = T(:, :, 1, :);
        ii = 1;
        for i = 1:divisions
            for j = 1:divisions
                T(:, :, 1, ii) = Joint2.TransformationMat(:, :, j);
                ii = ii+1;
            end
        end
    end
    
    %Psoas b1 -> f4
    if beginOptimization == 0
        Location4 = [0.036, -0.024, 0.015;
                      0.007, -0.057, -0.374;
                      0.029, 0.076, -0.025];
        PCrossPoints = [2 3];
        PMIF = 1113;
        Axis1 = [10 , 20, 30;
                10, 20, 30];
    end
    Muscle4 = PamData('Psoas X', PLocation, PCrossPoints, PMIF, T, Axis1);
    
    HipXTorque = Muscle1.Torque(1, :, 1) + Muscle2.Torque(1, :, 1) + Muscle3.Torque(1, :, 1) + Muscle4.Torque(2, :, 1);
    HipYTorque = Muscle1.Torque(1, :, 2) + Muscle2.Torque(1, :, 2) + Muscle3.Torque(1, :, 2) + Muscle4.Torque(2, :, 2);
    HipZTorque = Muscle1.Torque(1, :, 3) + Muscle2.Torque(1, :, 3) + Muscle3.Torque(1, :, 3) + Muscle4.Torque(2, :, 3);

    %Create the Mesh of Torques to corespond with the joint angles
    HipXTorqueMR = zeros(divisions, divisions); HipYTorqueMR = zeros(divisions, divisions); HipZTorqueMR = zeros(divisions, divisions);
    for i = 1:divisions
        HipXTorqueMR(:, i) = HipXTorque(((i-1)*divisions)+1:i*divisions);
        HipYTorqueMR(:, i) = HipYTorque(((i-1)*divisions)+1:i*divisions);
        HipZTorqueMR(:, i) = HipZTorque(((i-1)*divisions)+1:i*divisions);
    end
    
    %Including Generic variable name for plotting
    RobotAxis1 = Joint1b.Theta;
    RobotAxis1Label = 'Hip Flexion, Degrees';
    RobotAxis2 = Joint1a.Theta;
    RobotAxis2Label = 'Adduction/Abduction, Degrees';
    RobotTorque1 = HipZTorqueMR;
    RobotTorque2 = HipYTorqueMR;
    RobotTorque3 = HipXTorqueMR;
    RobotTitle1 = 'Robot Hip Torque, uniarticular, Z axis';
    RobotTitle2 = 'Robot Hip Torque, uniarticular, Y axis';
    RobotTitle3 = 'Robot Hip Torque, uniarticular, X axis';

end