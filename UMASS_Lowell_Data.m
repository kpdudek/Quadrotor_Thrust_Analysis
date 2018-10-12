function UMASS_Lowell_Data
filename = 'Horizontal_Forward.csv';
[rpm,thrust] = read_file(filename);
[rpm_o,thrust_o] = clean_thrust(thrust,rpm);
s = 36;
e = 1838;
[rpm_crop,thrust_crop] = crop_sets(rpm_o,thrust_o,s,e);

figure
plot(condition(rpm_crop))
hold on
plot(condition(thrust_crop))
legend('RPM','Thrust','Location','Northeast')
xlabel('Time')
ylabel('Magnitude')

linfit_RPMvsThrust(rpm_crop,thrust_crop)




function [rpm,thrust] = read_file(filename)
vals = csvread(filename,1);
rpm = vals(:,14);
thrust = (vals(:,10)).*9.80665;

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

function s_o = condition(s)
mins = min(s);
maxs = max(s);
s_o = (s-mins)./(maxs-mins);

function [rpm_crop,thrust_crop] = crop_sets(rpm,thrust,s,e)
rpm_crop = rpm(s:e);
thrust_crop = thrust(s:e);

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


