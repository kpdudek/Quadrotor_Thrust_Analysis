function plots_for_poster()
%plots single case of motor outputs and resulting force in Z for airshow
%poster

load('POC_tracks_alignment_data_2018_05_01_Thrust_Acro.mat')
x = 1:length(a_o1);

figure('Visible','on','Name','Sensor Data')
plot(a_fz)
title('Force Readings')
xlabel('Time')
ylabel('Force (N)')

figure('Visible','on','Name','Motor Outputs')
plot(x,a_o1,x,a_o2,x,a_o3,x,a_o4)
title('Motor Outputs')
xlabel('Time')
ylabel('Angular Velocity')
