function Process_Tachometer_Data(varargin)
% This funcion depends on Tachometer_VS_ActuatorOutput() to parse the .csv's
% and store into the .mat file loaded below
load('Tachometer_VS_ActuatorOutput_sensor_data.mat')

% Apply a sliding window filter
% Window = 16
rpm = filter_rpm(rpm);

% Resample datasets so they are all at the sample rate of the FT sensor and
% then plot the results
% FT Sensor = 126 Hz
% PX4 = 10 Hz
% Tachometer = 10 Hz
%%% NOTE: all tests before R2_2018_08_02_ThrustOnly_manual_2 have the
%%% tachometer set to 1hz. In the function resample sets, change the
%%% multiplier for rpm from 12.5 to 125
[omega_resamp,rpm_resamp] = resample_sets(omega,rpm);
plot_data(rpm_resamp,omega_resamp,ft(3,:))



%%% ARE YOU TWEAKING THE ALIGNMENT?
% read = 0 --> use local variables for alignment
% read = 1 --> open mat file of values
%%% if read = 0 write will be used
% write = 0 --> dont save local alignment values
% write = 1 --> data is aligned, save local values
if nargin == 0 % Enter your preferences here
    read = 1;
    write = 0;
else % Ensures that nothin is over written when function is called elsewhere
    read = 1;
    write = 0;
end

%%%   Alignment   %%%
if ((fopen('num_peaks.mat')&&fopen('offsets.mat')&&fopen('peak_data.mat'))~=-1) && read == 1
    fprintf("Loading saved data...\n")
    load('num_peaks.mat')
    load('offsets.mat')
    load('peak_data.mat')
else
    fprintf("Manual alignment chosen...\n")
    %%% Values for the number of peaks to isolate, number of peaks is the
    %%% number of RC inputs during test run
    % These values do not need to be saved like the end peaks, since they
    % are only used to get the offset values, then those are saved instead
    
    % Omega minumum height and separation of peaks
    o_min = 1380;o_sep=450;
    % Torque minumum height and separation of peaks
    ty_min=.25;ty_sep=350;
    % Rpm minimum height and separation of peaks
    rpm_min=9500;rpm_sep=350;
    num = 6; % Number of end peaks. Used to crop the end of the data set
    
    % Find the specified number of peaks and then crop the rest of the dataset
    % after them
    [omega_init,rpm_init,ty_init,omega_locs,rpm_locs,ty_locs] = find_peaks(omega_resamp(2,:),rpm_resamp,ft(3,:),o_min,o_sep,ty_min,ty_sep,rpm_min,rpm_sep,num);

    % Determine which sensor began recording first, then crop the other
    % datasets so the timescales align
    % Outputs the number of datapoints that need to be cropped from the
    % beginning of each dataset
    [rpm_offset,omega_offset,ty_offset] = align_data(rpm_init,omega_init,ty_init);
    
    %%% Values for end peak finder
    % Omega minumum height and separation of peaks
    o_min = 1440;o_sep=200;
    % Torque minumum height and separation of peaks
    ty_min=.15;ty_sep=450;
    % Rpm minimum height and separation of peaks
    rpm_min=9500;rpm_sep=350;
    num_end = 5; % Number of end peaks. Used to crop the end of the data set
    
    %%% Is the data aligned?
    if write == 1
        fprintf("\nSaving local variables to .mat file...\n")
        save('num_peaks','num')
        save('offsets','rpm_offset','omega_offset','ty_offset','omega_locs','rpm_locs','ty_locs')
        save('peak_data','o_min','o_sep','ty_min','ty_sep','rpm_min','rpm_sep','num_end')
    end
end


% In case the auto-alignment is off, specify the number of data points to
% be added to the existing offset values
omega_shift = 0;
rpm_shift = 0;
ty_shift = 0;
[rpm_offset,omega_offset,ty_offset] = manual_shift(rpm_resamp,omega_resamp(2,:),ft(3,:),omega_shift,rpm_shift,ty_shift,rpm_offset,omega_offset,ty_offset);

% Take the offset values from align_data() & manual_shift() and crop the
% Full datasets
[a_FT,a_Omega,a_RPM] = aligned_data(ft,omega_resamp,rpm_resamp,rpm_offset,omega_offset,ty_offset,omega_locs,rpm_locs,ty_locs,num,o_min,o_sep,ty_min,ty_sep,rpm_min,rpm_sep,num_end);


%%%   Beginning of Analysis Calls   %%%
% Plot the pixhawk actuator outputs versus the readings from the
% tachometer, apply a linear fit and create an equation for rpm as a
% function of omega (actuator output)
[p,q] = test_linear(a_Omega(2,:),a_RPM);


%This function plots the horizontal portions of the Pixhawk motor commands
%against the resulting RPM. Multiple fits are then applied to determine the
%relationship
p = poly_fit(a_Omega(2,:),a_RPM);

% Use the equation from poly_fit to convert omega values to rpm, then save
% values
rpm_vs_thrust(a_Omega,a_FT(1,:),p)





                         %%%   Setup   %%%

% Applies a sliding window filter to the rpm data. With an increased
% sample rate came an increase in noise
function filtered = filter_rpm(rpm)
L = length(rpm);
time = 1:L;
w = 16;
w2 = w/2;
t_sl = time(w2+1:end-w2);

%Filter Fx
filtered = [];
for i = w2+1:(L-w2)
    vals = rpm(i-w2:i+w2);
    filtered(end+1) = mean(vals);
end

% Resample the PX4 data set and the tachometer to match the frequency of
% the FT sensor
function [omega_resamp,rpm_resamp] = resample_sets(omega,rpm)
rpm_length = length(rpm);
omega_length = length(omega);

rpm_rate = ceil(rpm_length * 12.5);
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


          %%%%%    The data set is now being aligned    %%%%%
          
%Function that pulls out the indicator portions by isolating the first n
%peaks,
function [omega_init,rpm_init,ty_init,omega_locs,rpm_locs,ty_locs] = find_peaks(omega,rpm,ty,o_min,o_sep,ty_min,ty_sep,rpm_min,rpm_sep,num)
figure('Visible','on','Name','Peaks')

tab_s1 = uitab('Title','Actuator Output 2');
ax_s1 = axes(tab_s1);
t1 = 1:length(omega);
plot(ax_s1,t1,omega)
hold on
[pks1,omega_locs] = findpeaks(omega,'MinPeakHeight',o_min,'MinPeakDistance',o_sep);
plot(ax_s1,t1(omega_locs),pks1,'ko')

tab_s2 = uitab('Title','Filtered Force Y');
ax_s2 = axes(tab_s2);
t2 = 1:length(ty);
plot(ax_s2,t2,ty)
hold on
[pks2,ty_locs] = findpeaks(ty,'MinPeakHeight',ty_min,'MinPeakDistance',ty_sep);
plot(ax_s2,t2(ty_locs),pks2,'ko')

tab_s3 = uitab('Title','RPM');
ax_s3 = axes(tab_s3);
t3 = 1:length(rpm);
plot(ax_s3,t3,rpm)
hold on
[pks3,rpm_locs] = findpeaks(rpm,'MinPeakHeight',rpm_min,'MinPeakDistance',rpm_sep);
plot(ax_s3,t3(rpm_locs),pks3,'ko')

omega_init = omega(1:(omega_locs(num)+450));
ty_init = ty(1:(ty_locs(num)+300));
rpm_init = rpm(1:(rpm_locs(num)+300));

%Align the rpm dataset and the pixhawk dataset to the FT set. Since the FT
%set is the highest samplerate, the RPM/PX4 have to be resampled
function [rpm_offset,omega_offset,ty_offset] = align_data(rpm,omega,ty)
%Beginning of the signal analysis
c_rpm = condition(rpm);
c_omega = condition(omega);
c_ty = condition(ty);

%Setup of variables for use in looping for best resample and offset
lags=1:40:2500;
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
function [omega_locs,rpm_locs,ty_locs] = end_peaks(omega,rpm,ty,o_min,o_sep,ty_min,ty_sep,rpm_min,rpm_sep)
figure('Visible','on','Name','End Peaks')

tab_s1 = uitab('Title','Actuator Output 2');
ax_s1 = axes(tab_s1);
t1 = 1:length(omega);
plot(ax_s1,t1,omega)
hold on
[pks1,omega_locs] = findpeaks(omega,'MinPeakHeight',o_min,'MinPeakDistance',o_sep);
plot(ax_s1,t1(omega_locs),pks1,'ko')

tab_s2 = uitab('Title','Filtered Force Y');
ax_s2 = axes(tab_s2);
t2 = 1:length(ty);
plot(ax_s2,t2,ty)
hold on
[pks2,ty_locs] = findpeaks(ty,'MinPeakHeight',ty_min,'MinPeakDistance',ty_sep);
plot(ax_s2,t2(ty_locs),pks2,'ko')

tab_s3 = uitab('Title','RPM');
ax_s3 = axes(tab_s3);
t3 = 1:length(rpm);
plot(ax_s3,t3,rpm)
hold on
[pks3,rpm_locs] = findpeaks(rpm,'MinPeakHeight',rpm_min,'MinPeakDistance',rpm_sep);
plot(ax_s3,t3(rpm_locs),pks3,'ko')


%Takes the raw datasets and offsets them by the calculated lag in
%align_data()
function [a_FT,a_Omega,a_RPM] = aligned_data(ft,omega,rpm,rpm_offset,omega_offset,ty_offset,omega_locs,rpm_locs,ty_locs,num,o_min,o_sep,ty_min,ty_sep,rpm_min,rpm_sep,num_end)
%[omega_resamp,rpm_resamp] = resamp(ft,omega,rpm);

a_ft = ft(:,ty_offset+1+ty_locs(num):end);
a_omega = omega(:,omega_offset+1+ty_locs(num):end);
a_rpm = rpm(rpm_offset+1+ty_locs(num):end);

[omega_locs,rpm_locs,ty_locs] = end_peaks(a_omega(2,:),a_rpm,a_ft(3,:),o_min,o_sep,ty_min,ty_sep,rpm_min,rpm_sep);

% takes the datasets that have already have their beginning sections
% aligned, and uses the end peak data to crop the ending sections
a_ft = a_ft(:,1:ty_locs(end-(num_end-1)));
a_omega = a_omega(:,1:omega_locs(end-(num_end-1)));
a_rpm = a_rpm(1:rpm_locs(end-(num_end-1)));


[omega_resamp,rpm_resamp] = resamp(a_ft,a_omega,a_rpm);

figure('Name','Aligned Data')
plot(condition(a_ft(3,:)))
hold on
plot(condition(omega_resamp(2,:)))
hold on
plot(condition(rpm_resamp))

legend('Ty','PX4','RPM')

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



                        %%%   Analysis   %%%
%Function that pulls out the horizontal portions of the dataset
function [omegaMasked,rpmMasked] = mask_data(omega,rpm)
omegaMasked=omega;
omegaMasked(abs([diff(omega) 0])>0.5)=NaN;
rpmMasked=rpm;
rpmMasked(abs([diff(rpm) 0])>4)=NaN;

%Function that resamples the rpm data, and then scales the corresponding
%omega plot to check if its linear
function [p,q] = test_linear(omega,rpm)
len_omega = length(omega);
t = 1:len_omega;

[omegaMasked,rpmMasked] = mask_data(omega,rpm);

figure('Name','RPM Scaling Scatter')
mdl=fitlm(omegaMasked,rpmMasked);
plot(mdl)
xlabel('Pixhawk Motor Command')
ylabel('Tachometer Data')
q=table2array(mdl.Coefficients(1,'Estimate'));
p=table2array(mdl.Coefficients(2,'Estimate'));
legend('Location','northwest')

figure('Name','RPM After Fit')
plot(t,omega.*p+q,'b',t,rpm,'r')
hold on
plot(t,omegaMasked.*p+q,'b.',t,rpmMasked,'r.')
hold off
xlabel('time')
ylabel('RPM')
legend('omega','rpm','omegaMasked','rpmMasked','Location','northwest')

%This function applies fits to the omega vs rpm plot to check the
%relationship
function p = poly_fit(omega,rpm)
t = 1:length(omega);
[omegaMasked,rpmMasked] = mask_data(omega,rpm);
figure('Name','Fits')

scatter(omegaMasked,rpmMasked,'.')
hold on

isolated_omega_masked = [];
isolated_rpm_masked = [];
for i = 1:length(omegaMasked)
    if (num2str(omegaMasked(i)) ~= "NaN") && (num2str(rpmMasked(i)) ~= "NaN")
        isolated_omega_masked(end+1) = omegaMasked(i);
        isolated_rpm_masked(end+1) = rpmMasked(i);
    end
end

p = polyfit(isolated_omega_masked,isolated_rpm_masked,2);
%rpm_fit = polyval(p,isolated_omega_masked);

%fprintf('%e %e %e \n',p(1),p(2),p(3))
rpm_fit = p(1).*(isolated_omega_masked.^2) + p(2).*(isolated_omega_masked) + p(3);
plot(sort(isolated_omega_masked),sort(rpm_fit))
xlabel('PX4 PWM')
ylabel('Tachometer RPM')

figure('Name','RPM with function')
rpm_new = polyval(p,omega);
plot(t,rpm_new,t,rpm)
legend('adjusted PX4','RPM')

function rpm_vs_thrust(omega,fz,p)
% Equation for rpm as a function of pixhawk pwm signals
rpm = p(1).*(omega.^2) + p(2).*(omega) + p(3);

% Convert rpm to rad/s 
rad_sec = 0.104719755.*rpm;

%Output the thrust
thrust = fz;

save('rpm_thrust','thrust','rad_sec','p')














