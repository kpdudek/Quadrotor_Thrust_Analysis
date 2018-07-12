function [o1,o2,o3,o4,tp] = PX4_CSV_Plotter_V2(file)
[sc,va,ao] = string_form(file);
[g0,g1,g2,a0,a1,a2,t_sc] = read_sensor_combined(sc);
plot_sensor_combined(g0,g1,g2,a0,a1,a2,t_sc)
[r_s,p_s,y_s,t_a] = read_attitude(va);
plot_attitude(r_s,p_s,y_s,t_a)
[o1,o2,o3,o4,tp] = read_actuator_outputs(ao);
plot_actuator_outputs(o1,o2,o3,o4,tp)

function [sc,va,ao] = string_form(file)
sc = sprintf('%s_sensor_combined_0.csv',file);
va = sprintf('%s_vehicle_attitude_0.csv',file);
ao = sprintf('%s_actuator_outputs_0.csv',file);

function [g0,g1,g2,a0,a1,a2,tp_1] = read_sensor_combined(filename_1)
fid_1 = fopen(filename_1,'r');

t_s_1 = [];
g0 = [];
g1 = [];
g2 = [];
a0 = [];
a1 = [];
a2 = [];
count_1 = 0;

while ~feof(fid_1)
    if count_1 == 0
        line = fgetl(fid_1);
        count_1 = count_1 + 1;
    else
        line = fgetl(fid_1);
        
        
        [time,remain] = strtok(line,',');
        [g_0,remain] = strtok(remain,',');
        [g_1,remain] = strtok(remain,',');
        [g_2,remain] = strtok(remain,',');
        [g_int,remain] = strtok(remain,',');
        [a_time,remain] = strtok(remain,',');
        [a_0,remain] = strtok(remain,',');
        [a_1,remain] = strtok(remain,',');
        [a_2,remain] = strtok(remain,',');
        
        t_s_1(end+1) = (str2double(time)/1000000);
        g0(end+1) = str2double(g_0);
        g1(end+1) = str2double(g_1);
        g2(end+1) = str2double(g_2);
        a0(end+1) = str2double(a_0);
        a1(end+1) = str2double(a_1);
        a2(end+1) = str2double(a_2);
    end
end
fclose(fid_1);

t_1_shift = (t_s_1(1)-1); %Makes the first time value == 1 so the plot looks cleaner
tp_1 = t_s_1 - t_1_shift;

function plot_sensor_combined(g0,g1,g2,a0,a1,a2,tp_1)
%Figure Setup
gy_acc_plot = figure('Visible','on','Name','PX4 Accelerometer & Gyro');
tg = uitabgroup(gy_acc_plot);
%Plot Gyro 0
tab_g0 = uitab(tg,'Title','Gyro 0');
ax_g0 = axes(tab_g0);
plot(ax_g0,tp_1,g0,'b');
title('Gyro 0')
xlabel('Time(s)')
ylabel('Gyro')
%Plot Gyro 1
tab_g1 = uitab(tg,'Title','Gyro 1');
ax_g1 = axes(tab_g1);
plot(ax_g1,tp_1,g1,'b');
title('Gyro 1')
xlabel('Time(s)')
ylabel('Gyro')
%Plot Gyro 2
tab_g2 = uitab(tg,'Title','Gyro 2');
ax_g2 = axes(tab_g2);
plot(ax_g2,tp_1,g2,'b');
title('Gyro 2')
xlabel('Time(s)')
ylabel('Gyro')

%Plot Accelerometer 0
tab_a0 = uitab(tg,'Title','Accelerometer 0');
ax_a0 = axes(tab_a0);
plot(ax_a0,tp_1,a0,'b');
title('Accelerometer 0')
xlabel('Time(s)')
ylabel('Accelerometer')
%Plot Accelerometer 1
tab_a1 = uitab(tg,'Title','Accelerometer 1');
ax_a1 = axes(tab_a1);
plot(ax_a1,tp_1,a1,'b');
title('Accelerometer 1')
xlabel('Time(s)')
ylabel('Accelerometer')
%Plot Accelerometer 2
tab_a2 = uitab(tg,'Title','Accelerometer 2');
ax_a2 = axes(tab_a2);
plot(ax_a2,tp_1,a2,'b');
title('Accelerometer 2')
xlabel('Time(s)')
ylabel('Accelerometer')

%Sliding filter on all data sets

L = length(g0);
w = 100;
w2 = w/2;
t_sl_1 = tp_1(w2+1:end-w2);


%Filter Roll Speed
sl_pg0 = [];
sl_g0 = g0;
for i = w2+1:(L-w2)
    vals = sl_g0(i-w2:i+w2);
    sl_pg0(end+1) = mean(vals);
end
tab_slg0 = uitab(tg,'Title','SW Filter Gyro 0'); 
ax_slg0 = axes(tab_slg0);
plot(ax_slg0,t_sl_1,sl_pg0,'b');
title('Sliding Window Filter Gyro 0')
xlabel('Time(s)')
ylabel('Gyro')

function [r_s,p_s,y_s,tp_0] = read_attitude(filename_0)
fid_0 = fopen(filename_0,'r');

t_s_0 = [];
r_s = [];
p_s = [];
y_s = [];
count_0 = 0;

while ~feof(fid_0)
    
    if count_0 == 0
        line = fgetl(fid_0);
        count_0 = count_0 + 1;
    else
        line = fgetl(fid_0);
        
        [time,remain] = strtok(line,',');
        [r_s_l,remain] = strtok(remain,',');
        [p_s_l,remain] = strtok(remain,',');
        [y_s_l,remain] = strtok(remain,',');
        
        t_s_0(end+1) = (str2double(time)/1000000);
        r_s(end+1) = str2double(r_s_l);
        p_s(end+1) = str2double(p_s_l);
        y_s(end+1) = str2double(y_s_l);
    end
    
end
fclose(fid_0);

%Adjust the timescale for plotting
t_0_shift = (t_s_0(1)-1); %Makes the first time value == 1 so the plot looks cleaner
tp_0 = t_s_0 - t_0_shift;

function plot_attitude(r_s,p_s,y_s,tp_0)
%Figure Setup
att_plot = figure('Visible','on','Name','PX4 Attitude');

%Plot Roll Speed
tab_rs = uitab('Title','Roll Speed');
ax_rs = axes(tab_rs);
plot(ax_rs,tp_0,r_s,'b');
title('Roll Speed')
xlabel('Time(s)')
ylabel('Speed')

%Plot Pitch Speed
tab_ps = uitab('Title','Pitch Speed');
ax_ps = axes(tab_ps);
plot(ax_ps,tp_0,p_s,'b');
title('Pitch Speed')
xlabel('Time(s)')
ylabel('Speed')

%Plot Yaw Speed
tab_ys = uitab('Title','Yaw Speed');
ax_ys = axes(tab_ys);
plot(ax_ys,tp_0,y_s,'b');
title('Yaw Speed')
xlabel('Time(s)')
ylabel('Speed')


%Sliding Filter on Roll Speed
L = length(r_s);
w = 24;
w2 = w/2;
t_sl = tp_0(w2+1:end-w2);


%Filter Roll Speed
sl_prs = [];
sl_rs = r_s;
for i = w2+1:(L-w2)
    vals = sl_rs(i-w2:i+w2);
    sl_prs(end+1) = mean(vals);
end
tab_slrs = uitab('Title','SW Filter Roll Speed'); 
ax_slrs = axes(tab_slrs);
plot(ax_slrs,t_sl,sl_prs,'b');
title('Sliding Window Filter Roll Speed')
xlabel('Time(s)')
ylabel('Speed')

function [o1,o2,o3,o4,tp] = read_actuator_outputs(filename)
fid = fopen(filename,'r');

t_s = [];
o1 = [];
o2 = [];
o3 = [];
o4 = [];
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
        o1(end+1) = str2double(m_1);
        o2(end+1) = str2double(m_2);
        o3(end+1) = str2double(m_3);
        o4(end+1) = str2double(m_4);
    end
end
fclose(fid);

%Adjust the timescale for plotting
t_shift = (t_s(1)-1); %Makes the first time value == 1 so the plot looks cleaner
tp = t_s - t_shift;

function plot_actuator_outputs(o1,o2,o3,o4,tp)
%Figure Setup
out_plot = figure('Visible','on','Name','PX4 Actuator Outputs');

%Plot motor 1
tab_m1 = uitab('Title','Motor 1');
ax_m1 = axes(tab_m1);
plot(ax_m1,tp,o1,'b');
title('Motor 1')
xlabel('Time(s)')
ylabel('RPM * constant')

%Plot motor 2
tab_m2 = uitab('Title','Motor 2');
ax_m2 = axes(tab_m2);
plot(ax_m2,tp,o2,'b');
title('Motor 2')
xlabel('Time(s)')
ylabel('RPM * constant')

%Plot motor 3
tab_m3 = uitab('Title','Motor 3');
ax_m3 = axes(tab_m3);
plot(ax_m3,tp,o3,'b');
title('Motor 3')
xlabel('Time(s)')
ylabel('RPM * constant')

%Plot motor 4
tab_m4 = uitab('Title','Motor 4');
ax_m4 = axes(tab_m4);
plot(ax_m4,tp,o4,'b');
title('Motor 4')
xlabel('Time(s)')
ylabel('RPM * constant')

%Plot all motors
tab_all = uitab('Title','All Motors');
ax_all = axes(tab_all);
plot(ax_all,tp,o1,'r',tp,o2,'k',tp,o3,'b',tp,o4,'g');
legend(ax_all,'Motor 1','Motor 2','Motor 3','Motor 4');

