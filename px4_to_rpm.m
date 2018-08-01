function out = px4_to_rpm(omega,p,q)
out = omega.*p+q;
end