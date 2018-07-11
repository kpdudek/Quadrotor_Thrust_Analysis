function Single_Motor_Analysis
load('Single_Motor_Test_data_2018_07_11_Single_Motor_Test_WithFT.mat')

ct = check_linear_relationship(a_fz,a_o2);
plot_omega_ct(a_o2,ct)

matrix_ct = matrix_determined_ct(a_fz,a_o2);
disp(matrix_ct)

% Checking the linear relationship using
% Thrust = Ct * omega
% Solve for Ct at each discreet point, then plot Ct vs omega
% Ct versus omega should be linear
function ct = check_linear_relationship(a_fz,a_o2)
ct = zeros(1,length(a_o2));
for i = 1:length(a_o2)
    ct(i) = a_fz(i)/(a_o2(i)^2);
end

function plot_omega_ct(a_o2,ct)
figure('Visible','on','Name','Omega vs Ct')

tab = uitab('Title','Omega vs Ct');
ax = axes(tab);
plot(ax,a_o2,ct,'.')
xlabel('Omega')
ylabel('Ct')


tab2 = uitab('Title','Ct vs Time');
ax2 = axes(tab2);
plot(ax2,1:length(ct),ct,'.')
xlabel('Time')
ylabel('Ct')

function ct = matrix_determined_ct(a_fz,a_o2)

a_fz = a_fz';
a_o2 = a_o2'.^2;

ct = a_o2\a_fz;




