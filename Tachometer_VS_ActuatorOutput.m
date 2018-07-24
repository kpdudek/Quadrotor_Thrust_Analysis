function Tachometer_VS_ActuatorOutput

filename = 'R2_2018_07_24_manual04';
[ft,px4,tach] = string_form(filename);

omega = read_pixhawk(px4);

[time,force_plot,torque_plot] = read_ft(ft);

[sl_pfx,sl_pfy,sl_pfz,sl_ptx,sl_pty,sl_ptz,t_sl] = filter_ft(time,force_plot,torque_plot);

rpm = read_tachometer(tach);

plot_data(rpm,omega,sl_pty)

[omega_init,rpm_init,ty_init,omega_locs,rpm_locs,ty_locs] = find_peaks(omega(2,:),rpm,sl_pty);

% omega_new = omega(4,:)*6.7857;
% 
% figure('Visible','on')
% plot(1:length(omega(1,:)),omega_new)

[a_rpm,a_omega] = align_data(rpm_init,omega_init,ty_init);


function [ft,px4,tach] = string_form(file)
px4 = sprintf('%s_Px4_actuator_outputs_0.csv',file);
ft = sprintf('%s_FT',file);
tach = sprintf('%s_Tacho.csv',file);

function omega = read_pixhawk(filename)
fid = fopen(filename,'r');

t_s = [];
omega = [];
count = 0;

while ~feof(fid)
    if count == 0
        line = fgetl(fid);
        count = count + 1;
    else
        line = fgetl(fid);
        
        [time,remain] = strtok(line,',');
        [n_o,remain] = strtok(remain,',');
        [m_1,remain] = strtok(remain,',');
        [m_2,remain] = strtok(remain,',');
        [m_3,remain] = strtok(remain,',');
        [m_4,remain] = strtok(remain,',');
        
        t_s(end+1) = (str2double(time)/1000000);
        [r,c] = size(omega);
        omega(1,c+1) = str2double(m_1);
        omega(2,c+1) = str2double(m_2);
        omega(3,c+1) = str2double(m_3);
        omega(4,c+1) = str2double(m_4);
    end
end
fclose(fid);

%Adjust the timescale for plotting
t_shift = (t_s(1)-1); %Makes the first time value == 1 so the plot looks cleaner
tp = t_s - t_shift;

function [time,force_plot,torque_plot] = read_ft(filename)
fid = fopen(filename,'r');

forces = []; %empty matrix for force readings, columns (fx,fy,fz)
torques = []; %empty matrix for torque readings, columns (tx,ty,tz)
time_cap = []; %empty vector with the time-stamp of each data entry in seconds after midnight
coun = 0;

while ~feof(fid)
    if coun < 8 %read the first 8 lines, and do nothing
        coun = coun+1;
        line = fgetl(fid);
        
    else %read and manipulate the remaining lines of the file
        line = fgetl(fid);
        
        %isolates each component of the line
        [hex,remain] = strtok(line,','); %isolate the status(hex), and store as l1
        [RDT,remain] = strtok(remain,','); %isolate the RDT sequence and store as RDT
        [FT,remain] = strtok(remain,','); %isolate the F/T sequence and store as FT
        [fx,remain] = strtok(remain,','); %isolate the Fx value
        [fy,remain] = strtok(remain,','); %isolate the Fy value
        [fz,remain] = strtok(remain,','); %isolate the Fz value
        [tx,remain] = strtok(remain,','); %isolate the Tx value
        [ty,remain] = strtok(remain,','); %isolate the Ty value
        [tz,remain] = strtok(remain,','); %isolate the Tz value
        
        %erase extraneous characters and convert the hex value to type double
        hex = erase(hex,'"'); 
        RDT = str2double(erase(RDT,'"')); 
        FT = str2double(erase(FT,'"')); 
        fx = str2double(erase(fx,'"')); 
        fy = str2double(erase(fy,'"')); 
        fz = str2double(erase(fz,'"')); 
        tx = str2double(erase(tx,'"')); 
        ty = str2double(erase(ty,'"')); 
        tz = str2double(erase(tz,'"'));

        %isolate the time value: month,day,year,24hr-time(hour,min,sec,am_pm)
        time = erase(remain,["""",","]); 
        [mon,remain] = strtok(strtrim(time)); 
        [day,remain] = strtok(strtrim(remain)); 
        [year,remain] = strtok(strtrim(remain)); 
        [hour,remain] = strtok(strtrim(remain),':'); 
        hour = str2double(hour); 
        [min,remain] = strtok(strtrim(remain),':');
        min = str2double(min);
        [sec,remain] = strtok(strtrim(remain));
        sec = str2double(erase(sec,':'));
        am_pm = strtrim(remain);
        
        %convert time to seconds since midnight
        time_sec = sec + (min*60) + (hour*3600);
        time_cap(end+1) = time_sec; %stores timestamp in time_cap vector

        %add F/T values to new row of respective matrix
        forces(end+1,1) = fx;
        [r,c] = size(forces);
        forces(r,2) = fy;
        forces(r,3) = fz;

        torques(end+1,1) = tx;
        [r1,c1] = size(torques);
        torques(r1,2) = ty;
        torques(r1,3) = tz;
    end
end
fclose(fid); %close the file

%adds the point 0,0,0 to the F/T matricies to correspond with the time vector and improve graph
zero_line = zeros(1,3);
torque_plot = [zero_line;torques];
force_plot = [zero_line;forces];

%further time manipulation
elap_time = time_cap(end) - time_cap(1); %elapsed time
time_split = elap_time / length(time_cap); %time between data points
time = 0:time_split:elap_time; %time vector from 0-->total time counting by split time

function [sl_pfx,sl_pfy,sl_pfz,sl_ptx,sl_pty,sl_ptz,t_sl] = filter_ft(time,force_plot,torque_plot)
L = length(force_plot(:,1));
w = 26;
w2 = w/2;
t_sl = time(w2+1:end-w2);

%Filter Fx
sl_pfx = [];
sl_fx = force_plot(:,1);
for i = w2+1:(L-w2)
    vals = sl_fx(i-w2:i+w2);
    sl_pfx(end+1) = mean(vals);
end

%Filter Fy
sl_pfy = [];
sl_fy = force_plot(:,2);
for i = w2+1:(L-w2)
    vals = sl_fy(i-w2:i+w2);
    sl_pfy(end+1) = mean(vals);
end

%Filter Fz
sl_pfz = [];
sl_fz = force_plot(:,3);
for i = w2+1:(L-w2)
    vals = sl_fz(i-w2:i+w2);
    sl_pfz(end+1) = mean(vals);
end

%Filter Tx
sl_ptx = [];
sl_tx = torque_plot(:,1);
for i = w2+1:(L-w2)
    vals = sl_tx(i-w2:i+w2);
    sl_ptx(end+1) = mean(vals);
end

%Filter Ty
sl_pty = [];
sl_ty = torque_plot(:,2);
for i = w2+1:(L-w2)
    vals = sl_ty(i-w2:i+w2);
    sl_pty(end+1) = mean(vals);
end

%Filter Tz
sl_ptz = [];
sl_tz = torque_plot(:,3);
for i = w2+1:(L-w2)
    vals = sl_tz(i-w2:i+w2);
    sl_ptz(end+1) = mean(vals);
end

function rpm = read_tachometer(file)
fid = fopen(file,'r');
rpm = [];
counter = 1;

while ~feof(fid)
    if counter < 8
        line = fgetl(fid);
        counter = counter + 1;
    else
        line = fgetl(fid);
        
        [num,remain] = strtok(line,',');
        reading = erase(remain,',');
        rpm(end+1) = str2double(reading);
        
    end
end
fclose(fid);

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

function [omega_init,rpm_init,ty_init,omega_locs,rpm_locs,ty_locs] = find_peaks(omega,rpm,ty)
figure('Visible','on','Name','Peaks')

tab_s1 = uitab('Title','Actuator Output 1');
ax_s1 = axes(tab_s1);
t1 = 1:length(omega);
plot(ax_s1,t1,omega)
hold on
[pks1,omega_locs] = findpeaks(omega,'MinPeakHeight',1220,'MinPeakDistance',8);
plot(ax_s1,t1(omega_locs),pks1,'ko')

tab_s2 = uitab('Title','Filtered Force Y');
ax_s2 = axes(tab_s2);
t2 = 1:length(ty);
plot(ax_s2,t2,ty)
hold on
[pks2,ty_locs] = findpeaks(ty,'MinPeakHeight',.06,'MinPeakDistance',90);
plot(ax_s2,t2(ty_locs),pks2,'ko')

tab_s3 = uitab('Title','RPM');
ax_s3 = axes(tab_s3);
t3 = 1:length(rpm);
plot(ax_s3,t3,rpm)
hold on
[pks3,rpm_locs] = findpeaks(rpm,'MinPeakHeight',7700,'MinPeakDistance',2);
plot(ax_s3,t3(rpm_locs),pks3,'ko')

omega_init = omega(1:(omega_locs(10)+20));
ty_init = ty(1:(ty_locs(10)+200));
rpm_init = rpm(1:(rpm_locs(10)+2));

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
omega_resamp = resample(c_omega,ft_length,rotor_length);
rpm_resamp = resample(c_rpm,ft_length,rpm_length);

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

function score=align_score(s1_resampled,s2,lag)
[s1_lag,s2_lag] = lag_signals(s1_resampled,s2,lag);

score=correlation(s1_lag,s2_lag);

%Conditions the data to a 0 though 1 scale
function s_conditioned=condition(s)
s=shiftdim(s);
sMax=max(s);
sMin=min(s);
s_conditioned=(s-sMin)/(sMax-sMin);

%Crops the data set to the specified lag
function [s1_lag,s2_lag]=lag_signals(s1,s2,lag)
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
function c=correlation(s1,s2)
N=min(length(s1),length(s2));
c=sum(s1(1:N).*s2(1:N));

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













