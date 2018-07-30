function Tachometer_VS_ActuatorOutput

filename = 'R2_2018_07_27_manual02';
[ft,px4,tach] = string_form(filename);

omega = read_pixhawk(px4);

[time,force_plot,torque_plot] = read_ft(ft);

[sl_pfx,sl_pfy,sl_pfz,sl_ptx,sl_pty,sl_ptz,t_sl] = filter_ft(time,force_plot,torque_plot);
ft = [sl_pfz;sl_ptx;sl_pty;sl_ptz];
rpm = read_tachometer(tach);

save([mfilename '_sensor_data'],'rpm','omega','ft')


%Takes the standard naming syntax and adds suffixes to open the different
%.csv files from the sensors
function [ft,px4,tach] = string_form(file)
px4 = sprintf('%s_Px4_actuator_outputs_0.csv',file);
ft = sprintf('%s_FT',file);
tach = sprintf('%s_Tacho.csv',file);

%Parse the pixhawk Actuator Output .csv and store the values in matrix
%omega with size 4 x n
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

%Parse the FT sensor and store the values in matricies 
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

%Apply sliding window filter to the FT values
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

%Parse the tachometer .csv and store in a vector
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












