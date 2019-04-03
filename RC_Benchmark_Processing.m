function data = RC_Benchmark_Processing()

%%% Array to store omega & thrust data
%%% Filenames to read from
%%% r/R values for the trials
data = {};
filenames = {'Test1_NoArm.csv','Test2_Arm_Configuration_0.75.csv','Test3_Arm_Configuration_1.5.csv',...
    'Test4_Arm_Configuration_2.25.csv','Test5_Arm_Configuration_3.00.csv','Test6_Arm_Configuration_3.75.csv'};
r_div_R = {'FS','.1875','.375','.5625','.75','.9375'};

%%% Open a figure and then read then loop to read each file
figure('Name','RPM')
for i = 1: length(filenames)
    filename = filenames{i};
    
    %%% Get rpm and thrust values from RC Benchmarks .csv file
    [rpm,thrust] = read_file(filename);
    
    %%% Crop the zeros from the data sets (due to different sample rates
    [rpm_out,thrust_out] = clean_thrust(thrust,rpm);
    
    %%% Convert RPM to Radians and then square it
    omega_sq = ((rpm_out ./(2*pi))/60).^2;
    
    %%% Plot the cleaned data
    plot(omega_sq,thrust_out,'.')
    hold on
    
    %%% Apply a linear fit to the test runs data
    lin_fit = fitlm(omega_sq,thrust_out,'linear');
    q=table2array(lin_fit.Coefficients(1,'Estimate'));
    p=table2array(lin_fit.Coefficients(2,'Estimate'));
    linfit_vals = omega_sq.*p+q;
    
    plot(omega_sq,linfit_vals)
    hold on
    
    %%% Print the slope and intercept values for the linear fit
    fprintf('Linfit %d: slope: %.4f, intercpt: %.4f\n',i,p,q)
    
    %%% Store the Omega^2 and 
    data{end+1} = [omega_sq;thrust_out];
       
end

%%% Plot properties
title('Omega^2 vs Thrust for Square Tube Blockage')
xlabel('Omega ^2')
ylabel('Thrust')
legend('Free Space','FS linfit','r/R=.1875','linfit1','r/R=.375','linfit2','r/R=.5625','linfit3',...
    'r/R=.75','linfit4','r/R=.9375','linfit5','Location','northwest')

end


%%% -----------
%%% Functions
%%% ----------- 

%This function opens the .csv given and returns the rpm(rad/s) and thrust
%value (kg*f)
function [rpm,thrust] = read_file(filename)
vals = csvread(filename,2);
rpm = vals(:,14);
thrust = (vals(:,10));
end

% This function eliminates the 0 value readings within the dataset
function [rpm_out,thrust_out] = clean_thrust(thrust,rpm)
% out = thrust';
% out(abs([diff(thrust') 0])>0.1)=NaN;
thrust_out = [];
rpm_out = [];
for i = 1:length(thrust)
    if abs(thrust(i)) > .025
        rpm_out(end+1) = rpm(i);
        thrust_out(end+1) = thrust(i);
    end
end
end

% This function normalizes the vector s to be on a scale of 0 --> 1
function s_o = condition(s)
mins = min(s);
maxs = max(s);
s_o = (s-mins)./(maxs-mins);
end

% This function crops the datasets to start at 's', and end at 'e'
function [rpm_crop,thrust_crop] = crop_sets(rpm,thrust,s,e)
rpm_crop = rpm(s:e);
thrust_crop = thrust(s:e);
end

% This function applies a linear fit to the rpm vs thrust plot and displays
% it
function linfit_RPMvsThrust(rpm,thrust)
lin_fit = fitlm(rpm,thrust,'linear');
q=table2array(lin_fit.Coefficients(1,'Estimate'));
p=table2array(lin_fit.Coefficients(2,'Estimate'));

figure
plot(rpm,thrust,'.')
hold on
%plot(t,omega.*p+q,'b',t,rpm,'r')
linfit = rpm.*p+q;
plot(rpm,linfit)

legend('Thrust','Linear Fit','Location','Northwest')
xlabel('\omega^{2}')
ylabel('Thrust')
end