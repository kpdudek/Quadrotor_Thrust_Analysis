function ActuatorOutput_vs_Rpm
file = 'Strobe_log_20180626';
dir = string_form(file);

cd(dir)

for i = 1:16
    folder = sprintf('%s/%s',file,num2str(i));
    dir = string_form(folder);
    cd(dir)
    ao = file_form(num2str(i));
    [o1,o2,o3,o4] = read_actuator_outputs(ao);
    plot_actuator_outputs(o1,o2,o3,o4)
    fprintf('%s\n',dir)
end


function directory = string_form(file)
directory = sprintf('/home/kurt/ATI_Log_Processor/Test_Data/%s',file);

function actuator = file_form(file)
actuator = sprintf('%s_actuator_outputs_0.csv',file);

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

function plot_actuator_outputs(o1,o2,o3,o4)

figure('Visible','on','Name','Actuator Outputs')

x = 1:length(o1);
plot(x,o1,x,o2,x,o3,x,o4)








