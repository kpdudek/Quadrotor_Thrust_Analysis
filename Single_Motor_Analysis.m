function Single_Motor_Analysis
%%% This function takes the aligned datasets from Single_Motor_Test() and
%%% calculates the value of C_t as well as using that value of C_t to check
%%% if the linear model fits the test. 
%%% This function has been replaced by Single_Motor_Arduino()

file = 'Single_Motor_Test_WithFT_20180711';

load('Single_Motor_Test_data_2018_07_11_Single_Motor_Test_WithFT.mat')

ct = check_linear_relationship(a_fz,a_o2);
plot_omega_ct(a_o2,ct)

matrix_ct = matrix_determined_ct(a_fz,a_o2);
disp(matrix_ct)
predict_fts(a_fz,a_o2,matrix_ct)


% Checking the linear relationship using
% Thrust = Ct * omega
% Solve for Ct at each discreet point, then plot Ct vs omega
% Ct versus omega should be linear

%Append suffixes to the filename to open the corresponding .csv
function directory = string_form(file)
directory = sprintf('/home/kurt/ATI_Log_Processor/Test_Data/%s',file);

%Calculates the value of C_t at each timestep
function ct = check_linear_relationship(a_fz,a_o2)
ct = zeros(1,length(a_o2));
for i = 1:length(a_o2)
    ct(i) = a_fz(i)/(a_o2(i)^2);
end

%Plots the value of C_t over the entirety of the test
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

%Average value of C_t determined using the matrix approximation
function ct = matrix_determined_ct(a_fz,a_o2)

a_fz = a_fz';
a_o2 = a_o2'.^2;

ct = a_o2\a_fz;

%Use the matrix determined C_t to solve for expected FTs using the omega
%values from the test. If the linear model matches reality, this function
%should match the FT values from the FT sensor
function predict_fts(a_fz,a_o2,matrix_ct)
estim_fz = zeros(1,length(a_o2));
for i = 1:length(a_o2)
    estim_fz(i) = matrix_ct * (a_o2(i)^2);
end

len = 1:length(a_o2);
figure('Visible','on','Name','Predicted Fts')
plot(len,estim_fz,'g',len,a_fz,'k:')
legend('Estimated Fz','Actual Fz')
xlabel('Time')
ylabel('Fz (N)')




