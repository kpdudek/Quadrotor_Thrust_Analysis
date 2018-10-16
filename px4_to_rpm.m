function out = px4_to_rpm(omega,p,q)
% Using the linear model from the pwm to rpm map, convert the pwm vector to rpm values 
out = omega.*p+q;
end