function QuadR2_PlotDecibels()
% This function loads in the data taken during the quadrotor slowmotion
% video testing and plots against time
%
% The test took place on 2019/02/01
% The duration was 33.148 seconds
load('dbz.mat')

time = linspace(0,33.148,length(dbz));

max_db = find(dbz == max(dbz));
max_db_label = sprintf('Max dbz = %.2f',dbz(max_db));

figure('Name','Decibels at Max Throttle')
plot(time,dbz,'k',time(max_db),dbz(max_db),'ro')
xlabel('Time')
ylabel('Decibels')
title('Decibels Produced by a Quad from 0-->Max Throttle')
legend('Decibels',max_db_label,'Location','Northwest')
    

end