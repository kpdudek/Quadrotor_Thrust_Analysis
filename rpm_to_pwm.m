function out = rpm_to_pwm(rpm)
% Using the polynomial fit from the pwm to rpm map, convert an RPM vector
% to pwm values for a quadrotor
% The coefficients are obtainted from
% /Quadrotor_ThrustAnalysis/Misc/UMASS_Lowell_Data.m on 12/07/2018

% rpm = ax^2 + bx + c
a = -0.0043;
b = 23.084;
c = -14292-rpm;

discrim = sqrt(b^2 - 4*a*c);

b_plus = (-b + discrim) / (2*a);
b_minus = (-b - discrim) / (2*a);

out = [b_plus];
end