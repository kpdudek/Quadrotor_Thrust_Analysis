function out = pwm_to_rpm(pwm)
% Using the polynomial fit from the pwm to rpm map, convert the pwm vector to rpm values
% The coefficients are obtainted from
% /Quadrotor_ThrustAnalysis/Misc/UMASS_Lowell_Data.m on 12/07/2018

out = -.0043.*pwm.^2 + 23.084.*pwm - 14292;
end