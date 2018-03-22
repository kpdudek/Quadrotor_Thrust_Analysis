% ATI Log Processor
% Creator/Maintainer: Kurt Dudek
% Email: kpdudek@bu.edu
% Created: 02/26/2018
% Updated: 03/22/2018

%% Promt the user for a file to read
filename = input('Enter the file name: ','s');
fid = fopen(filename,'r');  %'test1_2018_02_22'

%% Setup
forces = []; %empty matrix for force readings, columns (fx,fy,fz)
torques = []; %empty matrix for torque readings, columns (tx,ty,tz)
time_cap = []; %empty vector with the time-stamp of each data entry in seconds after midnight
coun = 0; %counter, used to isolate the data in the file, first 8 lines

%% Iterates through the file, and isolates datapoints
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

%% Data Manipulation

%adds the point 0,0,0 to the F/T matricies to correspond with the time vector and improve graph
zero_line = zeros(1,3);
torque_plot = [zero_line;torques];
force_plot = [zero_line;forces];

%further time manipulation
elap_time = time_cap(end) - time_cap(1); %elapsed time
time_split = elap_time / length(time_cap); %time between data points
time = 0:time_split:elap_time; %time vector from 0-->total time counting by split time


%% Beginning of the plotting
FT_Plots = figure('Visible','on','MenuBar','none','ToolBar','none');
%Forces
tab_Fx = uitab('Title','Fx'); %FX Plots
ax_Fx = axes(tab_Fx);
plot(ax_Fx,time,force_plot(:,1),'b',time,zeros(1,length(time)),'r--');
title('FX')
xlabel('Time(s)')
ylabel('Force(N)')

tab_Fy = uitab('Title','Fy'); %FY Plots
ax_Fy = axes(tab_Fy);
plot(ax_Fy,time,force_plot(:,2),'b',time,zeros(1,length(time)),'r--');
title('FY')
xlabel('Time(s)')
ylabel('Force(N)')

tab_Fz = uitab('Title','Fz'); %FZ Plots
ax_Fz = axes(tab_Fz);
plot(ax_Fz,time,force_plot(:,3),'b',time,zeros(1,length(time)),'r--');
title('FZ')
xlabel('Time(s)')
ylabel('Force(N)')

%Torques
tab_Tx = uitab('Title','Tx'); %TX Plots
ax_Tx = axes(tab_Tx);
plot(ax_Tx,time,torque_plot(:,1),'b',time,zeros(1,length(time)),'r--');
title('TX')
xlabel('Time(s)')
ylabel('Force(N)')

tab_Ty = uitab('Title','Ty'); %TY Plots
ax_Ty = axes(tab_Ty);
plot(ax_Ty,time,torque_plot(:,2),'b',time,zeros(1,length(time)),'r--');
title('TY')
xlabel('Time(s)')
ylabel('Force(N)')

tab_Tz = uitab('Title','Tz'); %TZ Plots
ax_Tz = axes(tab_Tz);
plot(ax_Tz,time,torque_plot(:,3),'b',time,zeros(1,length(time)),'r--');
title('TZ')
xlabel('Time(s)')
ylabel('Force(N)')


%% Max values
%max Fx
fx = forces(:,1);
abs_x = abs(fx);
max_fx = max(abs_x);
max_val_x = find(abs_x == max_fx);
res_fx = fx(max_val_x(1));
%Max Fy
fy = forces(:,2);
abs_y = abs(fy);
max_fy = max(abs_y);
max_val_y = find(abs_y == max_fy);
res_fy = fy(max_val_y(1));
%Max Fz
fz = forces(:,3);
abs_z = abs(fz);
max_fz = max(abs_z);
max_val_z = find(abs_z == max_fz);
res_fz = fz(max_val_z(1));
%Max Tx
tx = torques(:,1);
abs_tx = abs(tx);
max_tx = max(abs_tx);
max_val_tx = find(abs_tx == max_tx);
res_tx = tx(max_val_tx(1));
%Max Ty
ty = torques(:,2);
abs_ty = abs(ty);
max_ty = max(abs_ty);
max_val_ty = find(abs_ty == max_ty);
res_ty = ty(max_val_ty(1));
%Max Tz
tz = torques(:,3);
abs_tz = abs(tz);
max_tz = max(abs_tz);
max_val_tz = find(abs_tz == max_tz);
res_tz = tz(max_val_tz(1));
%Print Maxes
fprintf('\n<<Max Values>>\nForces: FX = %f FY = %f FZ = %f\nTorques: TX = %f TY = %f TZ = %f\n\n',res_fx,res_fy,res_fz,res_tx,res_ty,res_tz);

%% Filtering
L = length(force_plot(:,1));
filt_f = zeros(1,L);
alpha = .3;
filt_f(1) = force_plot(1,3) * alpha;
for i = 2:L
    filt_f(i) = filt_f(i-1) + alpha * (force_plot(i,3)-filt_f(i-1));
end
tab_filx = uitab('Title','Filtered'); %TZ Plots
ax_filx = axes(tab_filx);
plot(ax_filx,time,filt_f,'b',time,zeros(1,length(time)),'r--');
title('Filtered')
xlabel('Time(s)')
ylabel('Force(N)')
