function RC_Benchmark_Processing()

filename = 'System_Test.csv';
[rpm,thrust] = read_file(filename);

[rpm_out,thrust_out] = clean_thrust(thrust,rpm);

end


%%% -----------
%%% Functions
%%% ----------- 

%This function opens the .csv given and returns the rpm(rad/s) and thrust
%value (kg*f)
function [rpm,thrust] = read_file(filename)
vals = csvread(filename,3);
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
rpm_sq = rpm.^2;
lin_fit = fitlm(rpm_sq,thrust,'linear');
q=table2array(lin_fit.Coefficients(1,'Estimate'));
p=table2array(lin_fit.Coefficients(2,'Estimate'));

figure
plot(rpm_sq,thrust,'.')
hold on
%plot(t,omega.*p+q,'b',t,rpm,'r')
linfit = rpm_sq.*p+q;
plot(rpm_sq,linfit)

legend('Thrust','Linear Fit','Location','Northwest')
xlabel('\omega^{2}')
ylabel('Thrust')
end