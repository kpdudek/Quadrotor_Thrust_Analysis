function Process_Tachometer_Data
load('sensor_data.mat')
load('num_peaks.mat')

%Values for the number of peaks to crop after for the indicator portions
r = 10; %RPM
o = 13; %Omega plot (PX4)
t = 11; %Torque

plot_data(rpm,omega,sl_pty)

[omega_init,rpm_init,ty_init,omega_locs,rpm_locs,ty_locs] = find_peaks(omega(2,:),rpm,sl_pty,r,o,t);

test_linear(omega(4,:),rpm)

[a_rpm,a_omega] = align_data(rpm_init,omega_init,ty_init);

%save('num_peaks','r','o','t')




%Function that plots the raw data
function plot_data(rpm,omega,ty)
len_rpm = 1:length(rpm);
len_omega = 1:length(omega(1,:));
len_ft = 1:length(ty);

figure('Visible','on','Name','RPM')
plot(len_rpm,rpm)

figure('Visible','on','Name','Omega')
plot(len_omega,omega(4,:))

figure('Visible','on','Name','Ty')
plot(len_ft,ty)

%Function that pulls out the indicator portions by isolating the first n
%peaks,
function [omega_init,rpm_init,ty_init,omega_locs,rpm_locs,ty_locs] = find_peaks(omega,rpm,ty,r,o,t)
figure('Visible','on','Name','Peaks')

tab_s1 = uitab('Title','Actuator Output 1');
ax_s1 = axes(tab_s1);
t1 = 1:length(omega);
plot(ax_s1,t1,omega)
hold on
[pks1,omega_locs] = findpeaks(omega,'MinPeakHeight',1275,'MinPeakDistance',8);
plot(ax_s1,t1(omega_locs),pks1,'ko')

tab_s2 = uitab('Title','Filtered Force Y');
ax_s2 = axes(tab_s2);
t2 = 1:length(ty);
plot(ax_s2,t2,ty)
hold on
[pks2,ty_locs] = findpeaks(ty,'MinPeakHeight',.07,'MinPeakDistance',150);
plot(ax_s2,t2(ty_locs),pks2,'ko')

tab_s3 = uitab('Title','RPM');
ax_s3 = axes(tab_s3);
t3 = 1:length(rpm);
plot(ax_s3,t3,rpm)
hold on
[pks3,rpm_locs] = findpeaks(rpm,'MinPeakHeight',7425,'MinPeakDistance',2);
plot(ax_s3,t3(rpm_locs),pks3,'ko')

omega_init = omega(1:(omega_locs(o)+20));
ty_init = ty(1:(ty_locs(t)+200));
rpm_init = rpm(1:(rpm_locs(r)+2));

%Function that resamples the rpm data, and then scales the corresponding
%omega plot to check if its linear
function test_linear(omega,rpm)
len_omega = length(omega);
len_rpm = length(rpm);
t = 1:len_omega;

rpm = resample(rpm,len_omega,len_rpm);

figure('Visible','on','Name','RPM Scaling')
plot(t,omega*6.7857,t,rpm)


%Align the rpm dataset and the pixhawk dataset to the FT set. Since the FT
%set is the highest samplerate, the RPM/PX4 have to be resampled
function [a_rpm,a_omega] = align_data(rpm,omega,ty)
%Beginning of the signal analysis
c_rpm = condition(rpm);
c_omega = condition(omega);
c_ty = condition(ty);

%Setup of variables for use in looping for best resample and offset
lags=-450:450;
Nlags=length(lags);

%Empty matrix to contain correlation between data
scores=zeros(2,Nlags);

%Running data to find best correlation and the indexes for offset and lag
rpm_max = 0;
rpm_iLag = 0;
omega_max = 0;
omega_iLag = 0;

%Looping to find correlation at varying offsets and lags
ft_length = length(c_ty);
rotor_length = length(c_omega);
rpm_length = length(c_rpm);
%ft_dec = /ft_length;

omega_resamp = interp1(1:rotor_length,c_omega,1:(rotor_length/ft_length):rotor_length)';
rpm_resamp = interp1(1:rpm_length,c_rpm,1:(rpm_length/ft_length):rpm_length)';
% omega_resamp = resample(c_omega,ft_length,rotor_length);
% rpm_resamp = resample(c_rpm,ft_length,rpm_length);

for iLags=1:Nlags
    score_omega = align_score(omega_resamp,c_ty,lags(iLags));
    score_rpm = align_score(rpm_resamp,c_ty,lags(iLags));
    
    scores(1,iLags) = score_omega; %Score for the correlation between FT sensor and pixhawk plot
    scores(2,iLags) = score_rpm; %Score for the correlation between FT sensor and tachometer
    
    if score_omega > omega_max
        omega_max = score_omega;
        omega_iLag = iLags;
    end
    
    if score_rpm > rpm_max
        rpm_max = score_rpm;
        rpm_iLag = iLags;
    end
end

%Processing the output of the looping
[rpm_offset,omega_offset] = surf_scores(scores,rpm_iLag,omega_iLag,lags);
check_alignment(omega_resamp,rpm_resamp,c_ty,rpm_offset,omega_offset)
%[a_fz,a_tx,a_ty,a_tz,a_o1,a_o2,a_o3,a_o4] = aligned_data(ffz,ftx,fty,ftz,o1,o2,o3,o4,offset,locs1,locs2);
a_rpm = 0;
a_omega = 0;

%Function that offsets the dataset and then calculates the correlation 
function score=align_score(s1_resampled,s2,lag)
[s1_lag,s2_lag] = lag_signals(s1_resampled,s2,lag);

score = correlation(s1_lag,s2_lag);

%Conditions the data to a 0 though 1 scale
function s_conditioned=condition(s)
s=shiftdim(s);
sMax=max(s);
sMin=min(s);
s_conditioned=(s-sMin)/(sMax-sMin);

%Crops the data set to the specified lag
function [s1_lag,s2_lag] = lag_signals(s1,s2,lag)
if lag>0
    s1_lag=s1;
    s2_lag=s2(lag+1:end);
elseif lag<0
    s1_lag=s1(-lag+1:end);
    s2_lag=s2;
else
    s1_lag=s1;
    s2_lag=s2;
end

%Finds the correlation between the data sets
function c = correlation(s1,s2)
N = min(length(s1),length(s2));
c = sum(s1(1:N).*s2(1:N));

%Takes the raw datasets and offsets them by the calculated lag in
%align_data()
function [a_fz,a_tx,a_ty,a_tz,out_o1,out_o2,out_o3,out_o4] = aligned_data(ffz,ftx,fty,ftz,o1,o2,o3,o4,offset,locs1,locs2)
FT_length = length(ffz);
rotor_length = length(o1);
so1 = resample(o1,FT_length,rotor_length);
so2 = resample(o2,FT_length,rotor_length);
so3 = resample(o3,FT_length,rotor_length);
so4 = resample(o4,FT_length,rotor_length);

if offset > 0
    a_fz = ffz((offset+1)+(locs2(3)+300):end);
    a_tx = ftx(offset+1+(locs2(3)+300):end);
    a_ty = fty(offset+1+(locs2(3)+300):end);
    a_tz = ftz(offset+1+(locs2(3)+300):end);
    a_o1 = so1(1+(locs2(3)+300):end);
    a_o2 = so2(1+(locs2(3)+300):end);
    a_o3 = so3(1+(locs2(3)+300):end);
    a_o4 = so4(1+(locs2(3)+300):end);
elseif offset < 0
    a_fz = ffz(1+(locs2(3)+300):end);
    a_tx = ftx(1+(locs2(3)+300):end);
    a_ty = fty(1+(locs2(3)+300):end);
    a_tz = ftz(1+(locs2(3)+300):end);
    a_o1 = so1((-offset+1)+(locs2(3)+300):end);
    a_o2 = so2((-offset+1)+(locs2(3)+300):end);
    a_o3 = so3((-offset+1)+(locs2(3)+300):end);
    a_o4 = so4((-offset+1)+(locs2(3)+300):end);
else
    a_fz = ffz((locs2(3)+300):end);
    a_tx = ftx((locs2(3)+300):end);
    a_ty = fty((locs2(3)+300):end);
    a_tz = ftz((locs2(3)+300):end);
    a_o1 = so1((locs2(3)+300):end);
    a_o2 = so2((locs2(3)+300):end);
    a_o3 = so3((locs2(3)+300):end);
    a_o4 = so4((locs2(3)+300):end);
end

[locs1,locs2] = end_peaks(a_o2,a_ty);

a_o1 = a_o1(1:locs1(end)+50);
a_o2 = a_o2(1:locs1(end)+50);
a_o3 = a_o3(1:locs1(end)+50);
a_o4 = a_o4(1:locs1(end)+50);
a_fz = a_fz(1:locs2(end)+50);
a_tx = a_tx(1:locs2(end)+50);
a_ty = a_ty(1:locs2(end)+50);
a_tz = a_tz(1:locs2(end)+50);

FT_length = length(a_fz);
rotor_length = length(a_o1);
out_o1 = resample(a_o1,FT_length,rotor_length);
out_o2 = resample(a_o2,FT_length,rotor_length);
out_o3 = resample(a_o3,FT_length,rotor_length);
out_o4 = resample(a_o4,FT_length,rotor_length);

%Pulls out the greatest correlation and the corresponding index value that
%will be used to align the raw datasets
function [rpm_offset,omega_offset] = surf_scores(scores,rpm_iLag,omega_iLag,lags)
POC_plot = figure('Visible','on','Name','FT & PX4 Offset');
len = 1:length(scores(1,:));
plot(len,scores(1,:),len,scores(2,:))
legend('PX4 Correlation','RPM Correlation')

rpm_offset = lags(rpm_iLag);
rpm_offset_ind = rpm_iLag;
fprintf('RPM Offset(index): %f - Offset: %f\n',rpm_offset_ind,rpm_offset)

omega_offset = lags(omega_iLag);
omega_offset_ind = omega_iLag;
fprintf('Omega Offset(index): %f - Offset: %f\n',omega_offset_ind,omega_offset)

%Plots aligned data to visually check alignment
function check_alignment(omega_resamp,rpm_resamp,c_ty,rpm_offset,omega_offset)
figure('Visible','on','Name','RPM Alignment')
[rpm, ty] = lag_signals(rpm_resamp,c_ty,rpm_offset);
plot(rpm)
hold on
plot(ty)
hold off

figure('Visible','on','Name','Omega Alignment')
[omega, ty] = lag_signals(omega_resamp,c_ty,omega_offset);
plot(omega)
hold on
plot(ty)
hold off



