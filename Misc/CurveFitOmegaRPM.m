function CurveFitOmegaRPM
%This function is a test to play around with different curve fits. Never
%got used. 
omega = [7826,8594,9360,10090,10720,11360,11920,12420,12930];
ct = [1.088,1.365,1.634,1.848,2.004,2.176,2.219,2.252,2.267];
ct = ct.*10^-6;

figure
plot(omega,ct,'-+')