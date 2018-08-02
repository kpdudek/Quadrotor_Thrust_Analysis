function Single_Motor_Arduino
file = 'Single_Motor_2018_08_01_03';
[ft,tach] = string_form(file);

%[fz,rpm] = read_files(ft,tach);
load('data.mat')
plot_data(rpm,sl_pfz)


% Manually align the datasets and crop
fz_isolated = sl_pfz(2500:23820);
rpm_isolated = rpm(11:181);

len_fz = length(fz_isolated);
len_rpm = length(rpm_isolated);
t = 1:len_fz;
rpm_isolated = interp1(1:len_rpm,rpm_isolated,linspace(1,len_rpm,len_fz));

figure('Name','Isoalted Portions')
plot(t,condition(fz_isolated),t,condition(rpm_isolated))


% Solve for c_T
ct = rpm_isolated'\fz_isolated';
fz_estimated = rpm_isolated * ct;

figure('Name','CT')
plot(fz_isolated,'k')
hold on
plot(fz_estimated,'cyan')
legend('True','Predicted')


function [ft,tach] = string_form(file)
ft = sprintf('%s_FT',file);
tach = sprintf('%s_Tacho.csv',file);


function [sl_pfz,rpm] = read_files(ft,tach)
[time,force_plot,torque_plot] = read_ft(ft);
[sl_pfx,sl_pfy,sl_pfz,sl_ptx,sl_pty,sl_ptz,t_sl] = filter_ft(time,force_plot,torque_plot);
rpm = read_tachometer(tach);
save('data','sl_pfz','rpm')


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


function plot_data(rpm,fz)
len_rpm = 1:length(rpm);
len_ft = 1:length(fz);

figure('Visible','on','Name','Sensor Data')

omega = uitab('Title','RPM');
omegaax = axes(omega);
plot(omegaax,len_rpm,rpm)

ft = uitab('Title','Fz');
ftax = axes(ft);
plot(ftax,len_ft,fz)


function s_conditioned=condition(s)
s=shiftdim(s);
sMax=max(s);
sMin=min(s);
s_conditioned=(s-sMin)/(sMax-sMin);









