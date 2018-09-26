function Single_Motor_Arduino

if fopen('data.mat') ~= -1
    load('data.mat')
else
    file = 'Single_Motor_Upright_Noninsulated';
    [ft,tach] = string_form(file);
    [sl_pfz,rpm] = read_files(ft,tach);
end

% [sl_pfz,rpm] = read_files(ft,tach);

rpm = filter_rpm(rpm);
plot_data(rpm,sl_pfz)
flagSkip=rpm<10050;
figure
rpmNoSkip=rpm;
rpmNoSkip(flagSkip)=NaN;
rpmSkip=rpm;
rpmSkip(~flagSkip)=NaN;
plot(1:length(rpm),rpmNoSkip,'b',1:length(rpm),rpmSkip,'r')


rpm_start = 133;
rpm_end = 2900;
fz_start = 1550;
fz_end = 35240;

% [fz_isolated,rpm_isolated] = align_datasets(sl_pfz,rpm,rpm_start,rpm_end,fz_start,fz_end);
% 
% ct = matrix_average_cT(rpm_isolated,fz_isolated);
% 
% ct_vec = discreet_ct(rpm_isolated,fz_isolated);



% Take the generic filename and append the suffixes used to denote the
% separate sensor files
function [ft,tach] = string_form(file)
ft = sprintf('%s_FT',file);
tach = sprintf('%s_Tacho.csv',file);

% Open the .csv file from the FT sensor, parse, and store the values in two
% matricies, one for forces, one for torques and a time vector
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

% Apply a sliding window filter to the FT data sets
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

% Open the tachometer's .csv file and store the data in a vector
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

% Call the functions that read the sensor files, and output the data to be
% used later on
function [sl_pfz,rpm] = read_files(ft,tach)
[time,force_plot,torque_plot] = read_ft(ft);
[sl_pfx,sl_pfy,sl_pfz,sl_ptx,sl_pty,sl_ptz,t_sl] = filter_ft(time,force_plot,torque_plot);
rpm = read_tachometer(tach);
save('data','sl_pfz','rpm')


                      %%%-  LATER ON  -%%%
% Take the raw data and plot against time
function plot_data(rpm,fz)
len_rpm = 1:length(rpm);
len_ft = 1:length(fz);

figure('Visible','on','Name','Sensor Data')

omega = uitab('Title','RPM');
omegaax = axes(omega);
plot(omegaax,len_rpm,rpm)
xlabel('Time (10Hz sample)')
ylabel('RPM')
title('RPM readings from Shimpo DT2100')

ft = uitab('Title','Fz');
ftax = axes(ft);
plot(ftax,len_ft,fz)
xlabel('Time (125Hz sample rate)')
ylabel('Force (N)')
title('AXIA80 Sensor Readings')

% Conditions the passed dataset to be on a scale of 0 --> 1
function s_conditioned=condition(s)
s=shiftdim(s);
sMax=max(s);
sMin=min(s);
s_conditioned=(s-sMin)/(sMax-sMin);

% This function takes the values for start and end set by the user and
% crops the datasets, The rpm set is then resampled to contain the same
% number of points as the FT sensor
function [fz_isolated,rpm_isolated] = align_datasets(sl_pfz,rpm,rpm_start,rpm_end,fz_start,fz_end)
% Manually align the datasets and crop
fz_isolated = sl_pfz(fz_start:fz_end);
rpm_isolated = rpm(rpm_start:rpm_end);

len_fz = length(fz_isolated);
len_rpm = length(rpm_isolated);
t = 1:len_fz;
rpm_isolated = interp1(1:len_rpm,rpm_isolated,linspace(1,len_rpm,len_fz));

figure('Name','Isoalted Portions')
plot(t,(fz_isolated/max(fz_isolated)),t,(rpm_isolated/max(rpm_isolated)).^2)%condition(rpm_isolated))

% This function solves for the matrix average value of c_T. If the system
% is truly linear, this c_T should solve Fz = c_T * w^2
function ct = matrix_average_cT(rpm_isolated,fz_isolated)
% Solve for average c_T
ct = rpm_isolated'\fz_isolated';
fz_estimated = rpm_isolated * ct;

figure('Name','CT')
plot(fz_isolated,'k')
hold on
plot(fz_estimated,'cyan')
legend('True','Predicted')

% This function solves for the value of c_T at every time step. c_T is then
% plotted against the value of w^2 at that time step
function ct_vec = discreet_ct(rpm_isolated,fz_isolated)
%Solve for time step c_T
ct_vec = zeros(1,length(fz_isolated));
for i = 1:length(fz_isolated)
    ct_vec(i) = fz_isolated(i)/rpm_isolated(i);
end
figure('Name','c_T vs Time')
plot(rpm_isolated.^2,ct_vec,'.')








