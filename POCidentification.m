function POCidentification
load('POC_tracks_alignment_data_2018_05_01.mat')

[omega,T] = create_matricies(a_o1,a_o2,a_o3,a_o4,a_fz,a_tx,a_ty,a_tz);

[ct,dct,cq,av_ct,av_dct,av_cq] = combined_coefficients(omega,T);
use_coefficients(ct,dct,cq,av_ct,av_dct,av_cq,omega,a_fz,a_tx,a_ty,a_tz)

[ct1,ct2,ct3,ct4,dct1,dct2,dct3,dct4,cq1,cq2,cq3,cq4] = independent_coefficients(omega,T);



function [omega,T] = create_matricies(a_o1,a_o2,a_o3,a_o4,a_fz,a_tx,a_ty,a_tz)
omega = [a_o1;a_o2;a_o3;a_o4];
T = [a_fz;a_tx;a_ty;a_tz];

function [ct,dct,cq,av_ct,av_dct,av_cq] = combined_coefficients(omega,T)
omega_mat = [];
T_mat = [];

for iN = 12000:20000
    osq = omega(:,iN).^2;
    Ti = T(:,iN);
    mat_o = [sum(osq),0,0;0,osq(1)-osq(2)+osq(3)-osq(4),0;0,-osq(1)+osq(2)+osq(3)-osq(4),0;0,0,-osq(1)+osq(2)-osq(3)+osq(4)];
    mat_T = Ti;
    
    omega_mat = [omega_mat;mat_o];
    T_mat = [T_mat;Ti];
end

fprintf('<< Linear system solution >>\n')
coef = omega_mat\T_mat;
ct = coef(1);
dct = coef(2);
cq = coef(3);
print_coefficients('combined',coef)

% [U,S,V] = svd(omega_mat,'econ');
% s = diag(S);
% d = U'*T_mat;
% coef2 = V*([d(1:3)./s(1:3)]); %;zeros(length(T_mat)-3,1)])
% disp(coef2)

for j = 1:4
    T_ave(j) = sum(T_mat(j:4:end))/(6000-4750);
    omega_ave(j,1) = sum(omega_mat(j:4:end,1))/(6000-4750);
    omega_ave(j,2) = sum(omega_mat(j:4:end,2))/(6000-4750);
    omega_ave(j,3) = sum(omega_mat(j:4:end,3))/(6000-4750);
end

fprintf('\n<< Averaging solution >>\n')
out = omega_ave\T_ave';
print_coefficients('combined',out)
av_ct = out(1);
av_dct = out(2);
av_cq = out(3);

function [ct1,ct2,ct3,ct4,dct1,dct2,dct3,dct4,cq1,cq2,cq3,cq4] = independent_coefficients(omega,T)
omega_mat = [];
T_mat = [];

for iN = 12000:20000
    osq = omega(:,iN).^2;
    Ti = T(:,iN);
    mat_o = [osq(1),osq(2),osq(3),osq(4),0,0,0,0,0,0,0,0;
             0,0,0,0,osq(1),-osq(2),osq(3),-osq(4),0,0,0,0;
             0,0,0,0,-osq(1),osq(2),osq(3),-osq(4),0,0,0,0;
             0,0,0,0,0,0,0,0,-osq(1),osq(2),-osq(3),osq(4)];
    mat_T = Ti;
    
    omega_mat = [omega_mat;mat_o];
    T_mat = [T_mat;Ti];
end

fprintf('\n<< Independent Values >>\n')
out = omega_mat\T_mat;
print_coefficients('all',out)
% disp(out)
ct1 = out(1);
ct2 = out(2);
ct3 = out(3);
ct4 = out(4);
dct1 = out(5);
dct2 = out(6);
dct3 = out(7);
dct4 = out(8);
cq1 = out(9);
cq2 = out(10);
cq3 = out(11);
cq4 = out(12);

function use_coefficients(ct,dct,cq,av_ct,av_dct,av_cq,omega,a_fz,a_tx,a_ty,a_tz)
coef_mat = [ct,ct,ct,ct;dct,-dct,dct,-dct;-dct,dct,dct,-dct;-cq,cq,-cq,cq];
av_coef_mat = [av_ct,av_ct,av_ct,av_ct;av_dct,-av_dct,av_dct,-av_dct;-av_dct,av_dct,av_dct,-av_dct;-av_cq,av_cq,-av_cq,av_cq];
T_plot = [];
T_av_plot = [];

for iN = 1:length(omega)
    osq = omega(:,iN).^2;
    T = coef_mat * osq;
    T_av = av_coef_mat * osq;
    
    T_plot = [T_plot,T];
    T_av_plot = [T_av_plot,T_av];
end

figure('Visible','on','Name','Check Coefficients')
mat_det = uitab('Title','Matrix Determined');
mat_ax = axes(mat_det);
av_det = uitab('Title','Average Determined');
av_ax = axes(av_det);

time = 1:length(T_plot(1,:));

mat = plot(mat_ax,time,T_plot(1,:),time,T_plot(2,:),time,T_plot(3,:),time,T_plot(4,:),time,a_fz,time,a_tx,time,a_ty,time,a_tz);
legend(mat,'Calculated Fz','Calculated Tx','Calculated Ty','Calculated Tz','Force Z','Torque X','Torque Y','Torque Z','Orientation','horizontal')

av = plot(av_ax,time,T_av_plot(1,:),time,T_av_plot(2,:),time,T_av_plot(3,:),time,T_av_plot(4,:),time,a_fz,time,a_tx,time,a_ty,time,a_tz);
legend(av,'Calculated Fz','Calculated Tx','Calculated Ty','Calculated Tz','Force Z','Torque X','Torque Y','Torque Z','Orientation','horizontal')

