function Check_JR3_Overload
filename = 'R2_2018_07_13_4Corners_2Indicators_Acro';
[time,force_plot,torque_plot] = read_ft(filename);
check_overload(force_plot,torque_plot)


% Parse the FT sensor and store the values in matricies 
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

% Passes the F/T readings at each timestep into the JR3 overload calculation
% to enusure sensor safety
function check_overload(force,torque)
fx = force(:,1);
fy = force(:,2);
fz = force(:,3);

mx = torque(:,1);
my = torque(:,2);
mz = torque(:,3);

a = 470;
b = 600;
c = 490;
d = 1900;
e = 40;
f = 105;
g = 28;
h = 22;

load_1 = zeros(1,length(fz));
load_2 = zeros(1,length(fz));
load_3 = zeros(1,length(fz));

for i = 1:length(fx)
    load_1(i) = (fx(i)/a) + (fy(i)/a) + (fz(i)/d) + (mx(i)/e) + (my(i)/e) + (mz(i)/h);
    load_2(i) = (fx(i)/b) + (fy(i)/c) + (fz(i)/d) + (mx(i)/f) + (my(i)/g) + (mz(i)/h);
    load_3(i) = (fx(i)/c) + (fy(i)/b) + (fz(i)/d) + (mx(i)/g) + (my(i)/f) + (mz(i)/h);
end

fail_1 = find(load_1 > 1);
fail_2 = find(load_2 > 1);
fail_3 = find(load_3 > 1);

disp(fail_1)
disp(fail_2)
disp(fail_3)
