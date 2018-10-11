function UMASS_Lowell_Data
filename = 'Log_2018-10-11_125849.csv';
[rpm,thrust2] = readfile(filename);

load('Rpm_Thrust.mat')

figure
plot(rpm)

figure
plot(thrust2)



function [rpm,thrust] = readfile(filename)
fid = fopen(filename,'r');

thrust = []; %empty matrix for force readings, columns (fx,fy,fz)
rpm = []; %empty matrix for torque readings, columns (tx,ty,tz)
coun = 0;

while ~feof(fid)
    if coun < 2 %read the first 8 lines, and do nothing
        coun = coun+1;
        line = fgetl(fid);
        
    else %read and manipulate the remaining lines of the file
        line = fgetl(fid);
        
        %isolates each component of the line
        [time,remain] = strtok(line,','); %isolate the status(hex), and store as l1
        [ESC,remain] = strtok(remain,','); %isolate the RDT sequence and store as RDT
        [S1,remain] = strtok(remain,','); %isolate the F/T sequence and store as FT
        [S2,remain] = strtok(remain,','); %isolate the Fx value
        [S3,remain] = strtok(remain,','); %isolate the Fy value
        [Ax,remain] = strtok(remain,','); %isolate the Fz value
        [Ay,remain] = strtok(remain,','); %isolate the Tx value
        [Az,remain] = strtok(remain,','); %isolate the Ty value
        [T,remain] = strtok(remain,','); %isolate the Tz value
        [Thrust,remain] = strtok(remain,','); %isolate the status(hex), and store as l1
        [V,remain] = strtok(remain,','); %isolate the RDT sequence and store as RDT
        [C,remain] = strtok(remain,','); %isolate the F/T sequence and store as FT
        [Me,remain] = strtok(remain,','); %isolate the Fx value
        [RPM,remain] = strtok(remain,','); %isolate the Fy value
%         [E,remain] = strtok(remain,','); %isolate the Fz value
%         [M,remain] = strtok(remain,','); %isolate the Tx value
%         [E,remain] = strtok(remain,','); %isolate the Ty value
%         [tz,remain] = strtok(remain,','); %isolate the Tz value
%         [tx,remain] = strtok(remain,','); %isolate the Tx value
%         [ty,remain] = strtok(remain,','); %isolate the Ty value
%         [tz,remain] = strtok(remain,','); %isolate the Tz value
        
    
    rpm = [rpm,str2double(RPM)];
    thrust = [thrust,str2double(Thrust)];
    end
end
fclose(fid); %close the file

