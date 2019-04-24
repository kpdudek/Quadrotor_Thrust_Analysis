function data = RC_Benchmark_Processing()

%%% Array to store omega & thrust data
%%% Filenames to read from
%%% r/R values for the trials
data = struct('Omega_SQ',[],'Thrust',[],'Omega_SQ_Masked',[],'Thrust_Masked',[],'Tare',0,'Length',[],'Masked_Length',[]);

%%% Open the RC Benchmark .csv files in the current folder
%%% NOTE: the current directory must contain only the RC Benchmark .csv
%%% files and the .mat file with the prop to tip distances
%%%     r = []; %containing the prop to tip distances
%%%     RC Benchmark files should start with the free space test and then
%%%     the varying distances to the object
%%%     NOTE: The RC Benchmark files must be sorted since they are read
%%%     sequentially by the program
filenames = dir('*.csv');
load('r.mat')

%%% Calculate the distance from prop tip to 'ground' divided by prop radius
r_div_R = r./4;

%%% Open a figure and then read then loop to read each file
%figure('Name','RPM')
for i = 1: length(filenames)
    filename = filenames(i).name;
    
    %%% Get rpm and thrust values from RC Benchmarks .csv file
    [rpm,thrust] = read_file(filename);
    
    %%% Crop the zeros from the data sets (due to different sample rates
    [rpm_out,thrust_out] = clean_thrust(thrust,rpm);
    
    %%% Convert RPM to Radians and then square it
    omega_sq = ((rpm_out ./(2*pi))/60).^2;
    
    
    %%% Loop through the RPM values and find the average tare reading for
    %%% thrust
    tare = [];
    for j = 1:length(omega_sq)
        if omega_sq(j) == 0
            tare(end+1) = thrust_out(j);
        else
            break
        end
    end
    
    %%% Check to make sure tare has values to prevent mean(tare) from being
    %%% NaN
    if length(tare) ~= 0
        tare = mean(tare); % calculate the average tare
    else
        tare = 0;
    end
    thrust_out = thrust_out - tare; % adjust the thrust readings by the tare value
    
    data(i).Omega_SQ = omega_sq;
    data(i).Thrust = thrust_out;
    data(i).Tare = tare;
    data(i).Length = 1:length(thrust_out);
    
    %%% Plot raw thrust data
    %     name = sprintf('Test %d',i);
    %     figure('Name',name)
    %     plot(thrust_out)
    
    
    % Mask the data to pull out only the horizontal portions
    [omegaMasked,thrustMasked] = mask_data(omega_sq,thrust_out);
    data(i).Omega_SQ_Masked = omegaMasked;
    data(i).Thrust_Masked = thrustMasked;
    data(i).Masked_Length = 1:length(thrustMasked);
    
    % figure('Name','Omega'); plot(omegaMasked,'.');
    % figure('Name','Thrust'); plot(thrustMasked,'.');
    
    
    %%% Plot the cleaned data. If statement sets the legend entry to be
    %%% that for free space or the corrent r/R value
    if i == 1
        leg = sprintf('Free Space');
    else
        leg = sprintf('r/R = %.3f',r_div_R(i-1));
    end
    plot(omegaMasked,thrustMasked,'.','DisplayName',leg)
    hold on
    
    %%% Apply a linear fit to the test runs data. If statement sets the
    %%% legend to be for free space or the correct r/R value
    lin_fit = fitlm(omegaMasked,thrustMasked,'linear');
    q=table2array(lin_fit.Coefficients(1,'Estimate'));
    p=table2array(lin_fit.Coefficients(2,'Estimate'));
    linfit_vals = omegaMasked.*p+q;
    
    if i == 1
        leg = sprintf('FS LinFit');
    else
        leg = sprintf('LinFit%d',i-1);
    end
    plot(omegaMasked,linfit_vals,'-','DisplayName',leg)
    hold on
    
    %%% Print the slope and intercept values for the linear fit
    fprintf('Linfit %d: slope: %.4f, intercpt: %.4f\n',i,p,q)
    fprintf('Rsquared for linfit %d = %.3f\n\n',i,lin_fit.Rsquared.Ordinary)
    
end

%%% Plot properties
title('Omega^2 vs Thrust')
xlabel('Omega ^2')
ylabel('Thrust')
legend('show')

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

%Function that pulls out the horizontal portions of the dataset
function [omegaMasked_out,thrustMasked_out] = mask_data(omega,thrust)
omegaMasked=omega;
omegaMasked(abs([diff(omega) 0])>0.8)=NaN;
thrustMasked=thrust;
thrustMasked(abs([diff(thrust) 0])>.075)=NaN;

omegaMasked_out = [];
thrustMasked_out = [];
for i = 1:length(omegaMasked)
    if (num2str(omegaMasked(i)) ~= "NaN") && (num2str(thrustMasked(i)) ~= "NaN")
        omegaMasked_out(end+1) = omegaMasked(i);
        thrustMasked_out(end+1) = thrustMasked(i);
    end
end

end






