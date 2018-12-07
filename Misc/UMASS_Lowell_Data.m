function UMASS_Lowell_Data
% This function exists to provide a baseline rpm vs thrust plot for the
% T-Motor MT2212 motor used on the quadrotor with an 8x5 prop

filename = 'Vertical_Test1.csv';
[rpmv1,thrustv1] = read_file(filename);
[rpm_v1,thrust_v1] = clean_thrust(thrustv1,rpmv1);
s = 36;
e = 1838;
[rpmv1_crop,thrustv1_crop] = crop_sets(rpm_v1,thrust_v1,s,e);
% figure
% plot(rpmv1_crop)

filename = 'Vertical_Test2.csv';
[rpmv2,thrustv2] = read_file(filename);
[rpm_v2,thrust_v2] = clean_thrust(thrustv2,rpmv2);
s = 56;
e = 1646;
[rpmv2_crop,thrustv2_crop] = crop_sets(rpm_v2,thrust_v2,s,e);
% figure
% plot(rpmv2_crop)

filename = 'Horizontal_Forward.csv';
[rpmhf,thrusthf] = read_file(filename);
[rpm_hf,thrust_hf] = clean_thrust(thrusthf,rpmhf);
s = 56;
e = 1857;
[rpmhf_crop,thrusthf_crop] = crop_sets(rpm_hf,thrust_hf,s,e);
% figure
% plot(rpmhf_crop)

filename = 'Horizontal_Left.csv';
[rpmhl,thrusthl] = read_file(filename);
[rpm_hl,thrust_hl] = clean_thrust(thrusthl,rpmhl);
s = 34;
e = 1816;
[rpmhl_crop,thrusthl_crop] = crop_sets(rpm_hl,thrust_hl,s,e);
% figure
% plot(rpmhl_crop)

figure
plot(rpmv1_crop.^2,thrustv1_crop,'.r',rpmv2_crop.^2,thrustv2_crop,'b.',rpmhf_crop.^2,thrusthf_crop,'g.',...
    rpmhl_crop.^2,thrusthl_crop,'k.')
legend('Vertical Close','Vertical Far','Horizontal Close','Horizontal Far','Location','Northeast')
xlabel('\omega^2')
ylabel('Thrust')
title('\omega^2 vs Thrust for all UMASS Tests')

%linfit_RPMvsThrust(rpm_crop,thrust_crop)


%%% Load RPM vs thrust data from quad for comparison
[omega1,thrust1,p1] = load_file('rpm_thrust_20180802_2.mat');
[omega2,thrust2,p2] = load_file('rpm_thrust_20180808_1.mat');
[omega3,thrust3,p3] = load_file('rpm_thrust_20180808_2.mat');

disp('Coefficients of pwm to rpm function *1000')
disp([p1;p2;p3])
p = mean([p1;p2;p3]);
save('coefficients_pwmTOomega','p')

umass_vs_quad(omega1,omega2,omega3,thrust1,thrust2,thrust3,rpmv1_crop,thrustv1_crop,rpmv2_crop,thrustv2_crop)



%This function opens the .csv given and returns the rpm(rad/s) and thrust
%value (kg*f)
function [rpm,thrust] = read_file(filename)
vals = csvread(filename,1);
rpm = vals(:,14);
thrust = (vals(:,10)).*9.80665;

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

% This function normalizes the vector s to be on a scale of 0 --> 1
function s_o = condition(s)
mins = min(s);
maxs = max(s);
s_o = (s-mins)./(maxs-mins);

% This function crops the datasets to start at 's', and end at 'e'
function [rpm_crop,thrust_crop] = crop_sets(rpm,thrust,s,e)
rpm_crop = rpm(s:e);
thrust_crop = thrust(s:e);

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

function [omega,thrust,p] = load_file(filename)
load(filename)
omega = rad_sec;
thrust = thrust;
p = p;

function umass_vs_quad(omega1,omega2,omega3,thrust1,thrust2,thrust3,U_omega1,U_thrust1,U_omega2,U_thrust2)
% Plotting omega for motor 1 versus 1/4 thrust of quad
figure('Name','omega^2 vs Thrust for Quad/Single Motor')
omega1 = (sum(omega1)/4).^2;
omega2 = (sum(omega2)/4).^2;
omega3 = (sum(omega3)/4).^2;
thrust1 = thrust1./4;
thrust2 = thrust2./4;
thrust3 = thrust3./4;
U_omega1 = U_omega1.^2;
U_omega2 = U_omega2.^2;

quad_omega = [omega2,omega3];%omega1,
quad_thrust = [thrust2,thrust3];%thrust1,
u_omega = [U_omega1,U_omega2];
u_thrust = [U_thrust1,U_thrust2];

plot(omega1,thrust1,'.',omega2,thrust2,'.',omega3,thrust3,'.',U_omega1,U_thrust1,'+',U_omega2,U_thrust2,'+')
legend('Ave \omega^2 quad1','Ave \omega^2 quad2','Ave \omega^2 quad3','Umass vertical close','Umass vertical far'...
    ,'Location','eastoutside')
xlabel('\omega^2')
ylabel('Thrust (N)')
title('Raw Single Motor data vs Average Quad \omega w/ thrust/4')

mdl_quad = fitlm(quad_omega,quad_thrust);
bq = table2array(mdl_quad.Coefficients(1,'Estimate'));
mq = table2array(mdl_quad.Coefficients(2,'Estimate'));

mdl_u = fitlm(u_omega,u_thrust);
bu = table2array(mdl_u.Coefficients(1,'Estimate'));
mu = table2array(mdl_u.Coefficients(2,'Estimate'));

hold on
plot(sort(quad_omega),sort(quad_omega).*mq + bq,'r',sort(u_omega),sort(u_omega).*mu + bu,'r')

fprintf('Slope of Umass: %e\nSlope of Quad: %e\n',mu,mq)













