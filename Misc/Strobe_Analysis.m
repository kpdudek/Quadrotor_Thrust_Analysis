function Strobe_Analysis
% This function plots the rpm reading from the strobometer against the pwm
% signal. The motors rpm proved to be too inconsistent for this method to
% work.
% This function was replaced by Single_Motor_Arduino
date = 05;
file = create_file(date);
dir = string_form(file);
strobe = load_strobe_data(date);
cd(dir)

omega = create_omega_mat(file,date);
[omega,strobe] = eliminate_outliers(omega,strobe);

plot_omegaVSstrobe(omega,strobe)


% This function appeds suffixes to the filenames so they can be
function file = create_file(num)
if num == 25
    file = 'Strobe_log_20180625';
    fprintf('Loading file "Strobe_log_20180625"...\n\n')
elseif num == 26
    file = 'Strobe_log_20180626';
    fprintf('Loading file "Strobe_log_20180626"...\n\n')
elseif num == 05
    file = 'Strobe_log_20180705';
    fprintf('Loading file "Strobe_log_20180626"...\n\n')
else
    error('File doesnt exist')
end

% This function selects the correct vector of strobe data from the given
% date
function strobe = load_strobe_data(date)
if date == 25
    strobe = [1200,1380,2460,2367,2478,2855,5160,0,7984,0,0,2404,2680,4550,6852,0];
elseif date == 05
    strobe = [416.4,432.4,444.3,486.5,498.1,553,582,413,450,463];
else
    strobe = [0,562,540,511,473,445,425,396,382,413,473,433,485,409.5,433.5,450];
end

% This function forms the string corresponding to the filepath the data is
% located in
function directory = string_form(file)
directory = sprintf('/home/kurt/ATI_Log_Processor/Test_Data/%s',file);

% This function forms the string of the filename
function actuator = file_form(file)
actuator = sprintf('%s_actuator_outputs_0.csv',file);

% This function opens and parses the file containing the actuator output
% values
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

% This function plots the actuator outputs 
function plot_actuator_outputs(o1,o2,o3,o4)
figure('Visible','on','Name','Actuator Outputs')

x = 1:length(o1);
plot(x,o1,'b:',x,o2,'b:',x,o3,'k',x,o4,'b:')

% This function creates the matricies of omega values based on the filename
% given and date
function omega = create_omega_mat(file,date)
if date == 05
    num = 10;
else
    num = 16;
end

omega = zeros(4,num);
for i = 1:num
    folder = sprintf('%s/%s',file,num2str(i));
    dir = string_form(folder);
    cd(dir)
    ao = file_form(num2str(i));
    [o1,o2,o3,o4] = read_actuator_outputs(ao);
    index = find(o1 > 1200);
    o1 = o1(index);
    o2 = o2(index);
    o3 = o3(index);
    o4 = o4(index);
    plot_actuator_outputs(o1,o2,o3,o4)
    fprintf('%s\n',dir)
    
    omega(1,i) = mean(o1);
    omega(2,i) = mean(o2);
    omega(3,i) = mean(o3);
    omega(4,i) = mean(o4);
end

% This function eliminates the outliers from the dataset
function [omega,strobe] = eliminate_outliers(omega,strobe)
index = find(strobe ~= 0);
strobe = (strobe(index)./2)*60;
omega = omega(:,index);

% This function plots the omega values versus the corresponding strobe
% values
function plot_omegaVSstrobe(omega,strobe)
omega = omega(3,:);
[calculated,b] = linear_regression(strobe,omega);
%poly_fit_plot = poly_fit(strobe,omega);

omega_max = [1 2000]*b;
omega_min = [1 1250]*b;
fprintf('\nThe minimum motor rpm using 1250 PX4 reading is predicted to be: %f\n',omega_min)
fprintf('The maximum motor rpm using 2000 PX4 reading is predicted to be: %f\n',omega_max)

fprintf('The calculated max RPM of the motor using 16.8V * 1100KV is 18480 RPM\n\n')

figure('Visible','on','Name','Strobe vs Omega')
plot(omega,strobe,'b*',omega,calculated,'r',2000,omega_max,'k+',1250,omega_min,'k+')%,omega,poly_fit_plot,'g')
xlabel('Omega Value')
ylabel('Strobe Frequency (rpm)')
legend('Strobe Measurements','Linear Regression','Minimum RPM using Fit','Max RPM using Fit')%,'Poly Fit')

% This function applies a linear fit to the omega versus strobe plot
function [calculated,b] = linear_regression(strobe,omega)
x = length(omega);
Omega = [ones(x,1) omega'];
b = Omega\(strobe');
calculated = Omega * b;

% This function applies a polynomial fit to the omega versus strobe plot
function calculated = poly_fit(strobe,omega)
coef = polyfit(omega,strobe,2);
calculated = polyval(coef,omega);







