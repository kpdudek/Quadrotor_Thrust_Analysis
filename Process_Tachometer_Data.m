function Process_Tachometer_Data
load('Tachometer_VS_ActuatorOutput_sensor_data.mat')
%load('num_peaks.mat')

% Resample datasets so they are all at the sample rate of the FT sensor and
% then plot the results
% FT Sensor = 126 Hz
% PX4 = 10 Hz
% Tachometer = 1 Hz
[omega_resamp,rpm_resamp] = resample_sets(omega,rpm);
plot_data(rpm_resamp,omega_resamp,ft(3,:))



%%%%%% TODO: Sliding window filter on the RPM dataset !!!!!



%%%  Values for the number of peaks to isolate, number of peaks is the
%%%  number of RC inputs during test run
r = 5; %RPM
o = 5; %Omega plot (PX4)
t = 5; %Torque
% Find the specified number of peaks and then crop the rest of the dataset
% after them
[omega_init,rpm_init,ty_init,omega_locs,rpm_locs,ty_locs] = find_peaks(omega_resamp(2,:),rpm_resamp,ft(3,:),r,o,t);


% Determine which sensor began recording first, then crop the other
% datasets so the timescales align
% Outputs the number of datapoints that need to be cropped from the
% beginning of each dataset
[rpm_offset,omega_offset,ty_offset] = align_data(rpm_init,omega_init,ty_init);
save('offsets','rpm_offset','omega_offset','ty_offset')
%load('offsets.mat')


% In case the auto-alignment is off, specify the number of data points to
% be added to the existing offset values
omega_shift = 0;
rpm_shift = 0;
ty_shift = 0;
[rpm_offset,omega_offset,ty_offset] = manual_shift(rpm_resamp,omega_resamp(2,:),ft(3,:),omega_shift,rpm_shift,ty_shift,rpm_offset,omega_offset,ty_offset);


% Take the offset values from align_data() & manual_shift() and crop the
% Full datasets
[a_FT,a_Omega,a_RPM] = aligned_data(ft,omega_resamp,rpm_resamp,rpm_offset,omega_offset,ty_offset,omega_locs,rpm_locs,ty_locs,r,o,t);

% Plot the pixhawk actuator outputs versus the readings from the
% tachometer, apply a linear fit and create an equation for rpm as a
% function of omega (actuator output)
[p,q] = test_linear(a_Omega(2,:),a_RPM);

% Use the equation from test_linear() to convert the pixhawk actuator
% output plots to true rpm values
true_rpm = px4_to_rpm(a_Omega,p,q);

%save('num_peaks','r','o','t')


% Resample the PX4 data set and the tachometer 
function [omega_resamp,rpm_resamp] = resample_sets(omega,rpm)
rpm_length = length(rpm);
omega_length = length(omega);

rpm_rate = rpm_length * 125;
omega_rate = ceil(omega_length * 12.5);

rpm_resamp = interp1(1:rpm_length,rpm,linspace(1,rpm_length,rpm_rate));

omega_resamp = [];
for i = 1:4
    omega_resamp = [omega_resamp;interp1(1:omega_length,omega(i,:),linspace(1,omega_length,omega_rate))];
end

%Function that plots the raw data
function plot_data(rpm,omega,ty)
len_rpm = 1:length(rpm);
len_omega = 1:length(omega(1,:));
len_ft = 1:length(ty);

figure('Visible','on','Name','Sensor Data')
rpmtab = uitab('Title','RPM');
rpmax = axes(rpmtab);
plot(rpmax,len_rpm,rpm)

o1 = uitab('Title','Motor 1');
o1ax = axes(o1);
plot(o1ax,len_omega,omega(1,:))
o2 = uitab('Title','Motor 2');
o2ax = axes(o2);
plot(o2ax,len_omega,omega(2,:))
o3 = uitab('Title','Motor 3');
o3ax = axes(o3);
plot(o3ax,len_omega,omega(3,:))
o4 = uitab('Title','Motor 4');
o4ax = axes(o4);
plot(o4ax,len_omega,omega(4,:))
all = uitab('Title','All');
allax = axes(all);
plot(allax,len_omega,omega(1,:),len_omega,omega(2,:),len_omega,omega(3,:),len_omega,omega(4,:))

ft = uitab('Title','FT Sensor');
ftax = axes(ft);
plot(ftax,len_ft,ty)

%Function that resamples the rpm data, and then scales the corresponding
%omega plot to check if its linear
function [p,q] = test_linear(omega,rpm)
len_omega = length(omega);
t = 1:len_omega;
% figure('Name','RPM Scaling')
% plot(t,omega*6.7857,t,rpm)
% ylabel('Note: pixhawk reading is manually scaled')
omegaMasked=omega;
omegaMasked(abs([diff(omega) 0])>0.5)=NaN;
rpmMasked=rpm;
rpmMasked(abs([diff(rpm) 0])>4)=NaN;
figure('Name','RPM Scaling Scatter')
mdl=fitlm(omegaMasked,rpmMasked);
plot(mdl)
q=table2array(mdl.Coefficients(1,'Estimate'));
p=table2array(mdl.Coefficients(2,'Estimate'));
figure('Name','RPM After Fit')
plot(t,omega.*p+q,'b',t,rpm,'r')
hold on
plot(t,omegaMasked.*p+q,'b.',t,rpmMasked,'r.')
hold off
legend('omega','rpm','omegaMasked','rpmMasked')

%%%%%    The data set is now being aligned    %%%%%

%Function that pulls out the indicator portions by isolating the first n
%peaks,
function [omega_init,rpm_init,ty_init,omega_locs,rpm_locs,ty_locs] = find_peaks(omega,rpm,ty,r,o,t)
figure('Visible','on','Name','Peaks')

tab_s1 = uitab('Title','Actuator Output 2');
ax_s1 = axes(tab_s1);
t1 = 1:length(omega);
plot(ax_s1,t1,omega)
hold on
[pks1,omega_locs] = findpeaks(omega,'MinPeakHeight',1350,'MinPeakDistance',350);
plot(ax_s1,t1(omega_locs),pks1,'ko')

tab_s2 = uitab('Title','Filtered Force Y');
ax_s2 = axes(tab_s2);
t2 = 1:length(ty);
plot(ax_s2,t2,ty)
hold on
[pks2,ty_locs] = findpeaks(ty,'MinPeakHeight',.3,'MinPeakDistance',350);
plot(ax_s2,t2(ty_locs),pks2,'ko')

tab_s3 = uitab('Title','RPM');
ax_s3 = axes(tab_s3);
t3 = 1:length(rpm);
plot(ax_s3,t3,rpm)
hold on
[pks3,rpm_locs] = findpeaks(rpm,'MinPeakHeight',8600,'MinPeakDistance',350);
plot(ax_s3,t3(rpm_locs),pks3,'ko')

omega_init = omega(1:(omega_locs(o)+450));
ty_init = ty(1:(ty_locs(t)+300));
rpm_init = rpm(1:(rpm_locs(r)+300));

%Align the rpm dataset and the pixhawk dataset to the FT set. Since the FT
%set is the highest samplerate, the RPM/PX4 have to be resampled
function [rpm_offset,omega_offset,ty_offset] = align_data(rpm,omega,ty)
%Beginning of the signal analysis
c_rpm = condition(rpm);
c_omega = condition(omega);
c_ty = condition(ty);

%Setup of variables for use in looping for best resample and offset
lags=1:50:2000;
Nlags=length(lags);

%Empty matrix to contain correlation between data
scores=[];

%Running data to find best correlation and the indexes for offset and lag
score_max = 0;
Lags = [];

%Looping to find correlation at varying offsets and lags
% [omega_resamp,rpm_resamp] = resamp(c_ty,c_omega,c_rpm);
% omega_resamp = omega_resamp';
% rpm_resamp = rpm_resamp';

for iLags=1:Nlags
    for jLags=1:Nlags
        for kLags=1:Nlags
            
            score = align_score(c_omega,c_rpm,c_ty,lags(iLags),lags(jLags),lags(kLags));
            scores = [scores,score];
            
            if score > score_max
                score_max = score;
                Lags = [iLags,jLags,kLags]; % omega , rpm , FT
            end
        end
    end
end
%Processing the output of the looping
[rpm_offset,omega_offset,ty_offset] = surf_scores(scores,Lags,lags);
check_alignment(c_omega,c_rpm,c_ty,rpm_offset,omega_offset,ty_offset)

%Conditions the data to a 0 though 1 scale
function s_conditioned=condition(s)
s=shiftdim(s);
sMax=max(s);
sMin=min(s);
s_conditioned=(s-sMin)/(sMax-sMin);

%Function that offsets the dataset and then calculates the correlation 
function score=align_score(omega_resamp,rpm_resamp,c_ty,iLag,jLag,kLag)
lag_set = [iLag,jLag,kLag];
[ft_lag,omega_lag,rpm_lag] = lag_sets(omega_resamp,rpm_resamp,c_ty,lag_set);

score = correlation(ft_lag,omega_lag,rpm_lag);

% Three datasets are passed to this function and a vector containing the
% three values for the sets to be offset by. The vector of offsets must go
% in this order: omega (PX4), rpm, FT sensor
function [ft_lag,omega_lag,rpm_lag] = lag_sets(omega_resamp,rpm_resamp,c_ty,lags)
omega_lag = omega_resamp(lags(1)+1:end);
rpm_lag = rpm_resamp(lags(2)+1:end);
ft_lag = c_ty(lags(3)+1:end);

%Crops the data set to the specified lag --Currently replaced by
%lag_sets()--
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
function c = correlation(ft_lag,omega_lag,rpm_lag)
N = min([length(ft_lag),length(omega_lag),length(rpm_lag)]);
c = sum(ft_lag(1:N).*omega_lag(1:N).*rpm_lag(1:N));

%Function that locates the peaks at the end of the data sets to use for
%cropping
function [omega_locs,rpm_locs,ty_locs] = end_peaks(omega,rpm,ty)
figure('Visible','on','Name','End Peaks')

tab_s1 = uitab('Title','Actuator Output 2');
ax_s1 = axes(tab_s1);
t1 = 1:length(omega);
plot(ax_s1,t1,omega)
hold on
[pks1,omega_locs] = findpeaks(omega,'MinPeakHeight',1432,'MinPeakDistance',350);
plot(ax_s1,t1(omega_locs),pks1,'ko')

tab_s2 = uitab('Title','Filtered Force Y');
ax_s2 = axes(tab_s2);
t2 = 1:length(ty);
plot(ax_s2,t2,ty)
hold on
[pks2,ty_locs] = findpeaks(ty,'MinPeakHeight',.3,'MinPeakDistance',350);
plot(ax_s2,t2(ty_locs),pks2,'ko')

tab_s3 = uitab('Title','RPM');
ax_s3 = axes(tab_s3);
t3 = 1:length(rpm);
plot(ax_s3,t3,rpm)
hold on
[pks3,rpm_locs] = findpeaks(rpm,'MinPeakHeight',9100,'MinPeakDistance',350);
plot(ax_s3,t3(rpm_locs),pks3,'ko')


%Takes the raw datasets and offsets them by the calculated lag in
%align_data()
function [a_FT,a_Omega,a_RPM] = aligned_data(ft,omega,rpm,rpm_offset,omega_offset,ty_offset,omega_locs,rpm_locs,ty_locs,r,o,t)
%[omega_resamp,rpm_resamp] = resamp(ft,omega,rpm);

a_ft = ft(:,ty_offset+1+ty_locs(t):end);
a_omega = omega(:,omega_offset+1+ty_locs(t):end);
a_rpm = rpm(rpm_offset+1+ty_locs(t):end);


[omega_locs,rpm_locs,ty_locs] = end_peaks(a_omega(2,:),a_rpm,a_ft(3,:));

a_ft = a_ft(:,1:ty_locs(end-4));
a_omega = a_omega(:,1:omega_locs(end-4));
a_rpm = a_rpm(1:rpm_locs(end-4));


[omega_resamp,rpm_resamp] = resamp(a_ft,a_omega,a_rpm);

figure('Name','Aligned Data')
plot(condition(a_ft(3,:)))
hold on
plot(condition(omega_resamp(2,:)),'.-')
hold on
plot(condition(rpm_resamp),'.-')

legend('Ty','PX4','RPM')

%TODO: outputs of this function NEED to be the same size otherwise
%TestLinear() will break for reasons only god knows. Aparently my matrix
%was 15.6 GB. Sure MATLAB... that makes sense

a_FT = a_ft;
a_Omega = omega_resamp;
a_RPM = rpm_resamp;


%Pulls out the greatest correlation and the corresponding index value that
%will be used to align the raw datasets
function [rpm_offset,omega_offset,ty_offset] = surf_scores(scores,Lags,lags)
% POC_plot = figure('Visible','on','Name','FT & PX4 Offset');
% plot(scores)

rpm_offset = lags(Lags(2));
rpm_offset_ind = Lags(2);
fprintf('RPM Offset(index): %f - Offset: %f\n',rpm_offset_ind,rpm_offset)

omega_offset = lags(Lags(1));
omega_offset_ind = Lags(1);
fprintf('Omega Offset(index): %f - Offset: %f\n',omega_offset_ind,omega_offset)

ty_offset = lags(Lags(3));
ty_offset_ind = Lags(3);
fprintf('FT sensor Offset(index): %f - Offset: %f\n',ty_offset_ind,ty_offset)

%Plots aligned data to visually check alignment
function check_alignment(omega_resamp,rpm_resamp,c_ty,rpm_offset,omega_offset,ty_offset)
figure('Visible','on','Name','Alignment')
Lags = [omega_offset,rpm_offset,ty_offset];
[ft,omega,rpm] = lag_sets(omega_resamp,rpm_resamp,c_ty,Lags);
plot(rpm)
hold on
plot(omega)
hold on
plot(ft)


% This function takes the calculated offsets from align_data(), and adds the
% user inputed offsets 
function [rpm_out,omega_out,ty_out] = manual_shift(rpm,omega,ty,omega_shift,rpm_shift,ty_shift,rpm_offset,omega_offset,ty_offset)
[omega_resamp,rpm_resamp] = resamp(ty,omega,rpm);

rpm_offset = rpm_offset + rpm_shift;
omega_offset = omega_offset + omega_shift;
ty_offset = ty_offset + ty_shift;

rpm_temp = rpm_resamp(rpm_offset+1:end);
omega_temp = omega_resamp(omega_offset+1:end);
ty_temp = ty(ty_offset+1:end);


% figure('Name','Manual Shift')
% plot(condition(ty_temp))
% hold on
% plot(condition(omega_temp))
% hold on
% plot(condition(rpm_temp))

rpm_out = rpm_offset;
omega_out = omega_offset;
ty_out = ty_offset;

% This function takes three vectors (ft,omega,rpm) and resamples omega and
% rpm to have the same number of data points as the ft vector
function [omega_resamp,rpm_resamp] = resamp(ft,omega,rpm)
ft_length = length(ft);
omega_length = length(omega);
rpm_length = length(rpm);

rpm_resamp = interp1(1:rpm_length,rpm,linspace(1,rpm_length,ft_length));

[r,c] = size(omega);
if r == 4
    omega_resamp = [];
    for i = 1:4
        omega_resamp = [omega_resamp;interp1(1:omega_length,omega(i,:),linspace(1,omega_length,ft_length))];
    end
else
    omega_resamp = interp1(1:omega_length,omega,linspace(1,omega_length,ft_length));
end











