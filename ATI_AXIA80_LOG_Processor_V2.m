function [ffz,ftx,fty,ftz,t_sl] = ATI_AXIA80_LOG_Processor_V2(file)
%%% This function reads the .csv file from the AXIA80 FT Sensor, and
%%% outputs the FT readings as well as elapsed time

[time,elap_time,forces,torques] = readfile(file);
%ty = torques(:,2);
max_values(forces,torques)
plot_ft(time,forces,torques)
[ffx,ffy,ffz,ftx,fty,ftz,t_sl] = filter_ft(time,forces,torques);
%time_split(time,elap_time,forces,torques,21)

%save([filename '_processed.mat'],fty)
end


% This function parses the .csv from the Axia80 FT sensor
function [time,elap_time,force_plot,torque_plot] = readfile(filename)
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

end

% This function pulls out the max forces and torques, and prints them
function max_values(forces,torques)
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
fprintf('\n\n\t<< Max Values >>\n\tForces: FX = %f FY = %f FZ = %f\n\tTorques: TX = %f TY = %f TZ = %f\n\n',res_fx,res_fy,res_fz,res_tx,res_ty,res_tz);
end

% This function plots the forces and torques taken from the .csv
function plot_ft(time,force_plot,torque_plot)
FT_Plots = figure('Visible','on','Name','Force Torque');
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
end

% This function applies a sliding window filter to the FT readings
function [sl_pfx,sl_pfy,sl_pfz,sl_ptx,sl_pty,sl_ptz,t_sl] = filter_ft(time,force_plot,torque_plot)
L = length(force_plot(:,1));
w = 26;
w2 = w/2;
t_sl = time(w2+1:end-w2);
% for i = 1: length(t_sl)
% fprintf('%f\n',t_sl(i))
% end

%Filter Fx
sl_pfx = [];
sl_fx = force_plot(:,1);
for i = w2+1:(L-w2)
    vals = sl_fx(i-w2:i+w2);
    sl_pfx(end+1) = mean(vals);
end
tab_slx = uitab('Title','SW Filter Fx'); 
ax_slx = axes(tab_slx);
plot(ax_slx,t_sl,sl_pfx,'b',time,zeros(1,length(time)),'r--');
title('Sliding Window Filter Fx')
xlabel('Time(s)')
ylabel('Force(N)')

%Filter Fy
sl_pfy = [];
sl_fy = force_plot(:,2);
for i = w2+1:(L-w2)
    vals = sl_fy(i-w2:i+w2);
    sl_pfy(end+1) = mean(vals);
end
tab_sly = uitab('Title','SW Filter Fy'); 
ax_sly = axes(tab_sly);
plot(ax_sly,t_sl,sl_pfy,'b',time,zeros(1,length(time)),'r--');
title('Sliding Window Filter Fy')
xlabel('Time(s)')
ylabel('Force(N)')

%Filter Fz
sl_pfz = [];
sl_fz = force_plot(:,3);
for i = w2+1:(L-w2)
    vals = sl_fz(i-w2:i+w2);
    sl_pfz(end+1) = mean(vals);
end
tab_sl = uitab('Title','SW Filter Fz'); 
ax_sl = axes(tab_sl);
plot(ax_sl,t_sl,sl_pfz,'b',time,zeros(1,length(time)),'r--');
title('Sliding Window Filter Fz')
xlabel('Time(s)')
ylabel('Force(N)')

%Filter Tx
sl_ptx = [];
sl_tx = torque_plot(:,1);
for i = w2+1:(L-w2)
    vals = sl_tx(i-w2:i+w2);
    sl_ptx(end+1) = mean(vals);
end
tab_sltx = uitab('Title','SW Filter Tx'); 
ax_sltx = axes(tab_sltx);
plot(ax_sltx,t_sl,sl_ptx,'b',time,zeros(1,length(time)),'r--');
title('Sliding Window Filter Tx')
xlabel('Time(s)')
ylabel('Force(N)')

%Filter Ty
sl_pty = [];
sl_ty = torque_plot(:,2);
for i = w2+1:(L-w2)
    vals = sl_ty(i-w2:i+w2);
    sl_pty(end+1) = mean(vals);
end
tab_slty = uitab('Title','SW Filter Ty'); 
ax_slty = axes(tab_slty);
plot(ax_slty,t_sl,sl_pty,'b',time,zeros(1,length(time)),'r--');
title('Sliding Window Filter Ty')
xlabel('Time(s)')
ylabel('Force(N)')

%Filter Tz
sl_ptz = [];
sl_tz = torque_plot(:,3);
for i = w2+1:(L-w2)
    vals = sl_tz(i-w2:i+w2);
    sl_ptz(end+1) = mean(vals);
end
tab_sltz = uitab('Title','SW Filter Tz'); 
ax_sltz = axes(tab_sltz);
plot(ax_sltz,t_sl,sl_ptz,'b',time,zeros(1,length(time)),'r--');
title('Sliding Window Filter Tz')
xlabel('Time(s)')
ylabel('Force(N)')
end

% This function prints the FT readings at the provided time t
function time_split(time,elap_time,force_plot,torque_plot,t)
%t = 21;
step_size = elap_time / length(time);
time_index = ceil(t / step_size);

Fxs = force_plot(time_index,1);
Fys = force_plot(time_index,2);
Fzs = force_plot(time_index,3);
Txs = torque_plot(time_index,1);
Tys = torque_plot(time_index,2);
Tzs = torque_plot(time_index,3);

fprintf("\n\t<< F/T's at time %.4f(s) >>\n\tFx = %f Fy = %f Fz = %f\n\tTx = %f Ty = %f Tz = %f\n\n",t,Fxs,Fys,Fzs,Txs,Tys,Tzs);
end

