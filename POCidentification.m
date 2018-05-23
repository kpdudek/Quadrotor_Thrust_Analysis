function POCidentification
%Loads output of POC_tracks_alignment
load('POC_tracks_alignment_data_2018_05_01.mat')

%Takes the data input, and forms the matricies used in future calculations
[omega,T] = create_matricies(a_o1,a_o2,a_o3,a_o4,a_fz,a_tx,a_ty,a_tz);

%Span to calculate coefficients over
n1 = [1971,11000,21000,27600,34000];
n2 = [10000,20000,27000,33000,41000];
len_n1 = length(n1);
len_n2 = length(n2);

%Solves for the coefficients and then uses them to check theoretical versus
%actual. This is where we see if it is truly a linear system
[coef,coef_ave] = combined_coefficients(omega,T,n1,n2,len_n1,len_n2);
use_coefficients(coef,coef_ave,omega,a_fz,a_tx,a_ty,a_tz,n1,n2,len_n1)

%Furthering the calculations, here a larger matrix is created that solves
%for the coefficients of each motor
%[ct1,ct2,ct3,ct4,dct1,dct2,dct3,dct4,cq1,cq2,cq3,cq4] = independent_coefficients(omega,T,n1,n2);



%Initialize the matricies
function [omega,T] = create_matricies(a_o1,a_o2,a_o3,a_o4,a_fz,a_tx,a_ty,a_tz)
omega = [a_o1;a_o2;a_o3;a_o4];
T = [a_fz;a_tx;a_ty;a_tz];

%Calculates the coefficient matricies assuming they are uniform throughout
%the 4 motors. 
function [coef,coef_ave] = combined_coefficients(omega,T,n1,n2,len_n1,len_n2)
omega_mat = [];
T_mat = [];

for i = 1:len_n1
    for iN = n1(i):n2(i)
        osq = omega(:,iN).^2;
        Ti = T(:,iN);
        mat_o = [sum(osq),0,0;0,osq(1)-osq(2)+osq(3)-osq(4),0;0,-osq(1)+osq(2)+osq(3)-osq(4),0;0,0,-osq(1)+osq(2)-osq(3)+osq(4)];
        %mat_T = Ti;
        
        omega_mat(end+1:end+4,(3*i-2):(i*3)) = mat_o;
        T_mat(end+1:end+4,i) = Ti;
    end
end

%looping and solving for coefficients at each horizontal
coef = [];
for j = 1:len_n1
    fprintf('\n<< Linear system solution for %d - %d >>\n',n1(j),n2(j))
    coef = [coef,(omega_mat(:,(3*j-2):(3*j))\T_mat(:,j))];
    print_coefficients('combined',coef(:,j))
end

%Looping and using the average method to solve for coefficients at each
%horizontal
coef_ave = [];
for m = 1:len_n1
    denominator = n2(m) - n1(m);
    for k = 1:4
        T_ave(k,m) = sum(T_mat(k:4:end,m))/(denominator);
        omega_index = (3*m-2);
        omega_ave(k,omega_index) = sum(omega_mat(k:4:end,omega_index))/(denominator);
        omega_ave(k,omega_index+1) = sum(omega_mat(k:4:end,omega_index+1))/(denominator);
        omega_ave(k,omega_index+2) = sum(omega_mat(k:4:end,omega_index+2))/(denominator);
    end
    
    fprintf('\n<< Averaging solution for %d - %d >>\n',n1(m),n2(m))
    coef_ave = [coef_ave,(omega_ave(:,(3*m-2):(3*m))\T_ave(:,m))];
    print_coefficients('combined',coef_ave(:,m))
end

function [ct1,ct2,ct3,ct4,dct1,dct2,dct3,dct4,cq1,cq2,cq3,cq4] = independent_coefficients(omega,T,n1,n2)
omega_mat = [];
T_mat = [];

for iN = n1:n2
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

function use_coefficients(coef,coef_ave,omega,a_fz,a_tx,a_ty,a_tz,n1,n2,len_n1)
%fig = figure('Visible','on','Name','Check Coefficients');
for i = 1:len_n1
    T_plot = [];
    T_av_plot = [];
    ct = coef(1,i);
    dct = coef(2, i);
    cq = coef(3,i);
    av_ct = coef_ave(1,i);
    av_dct = coef_ave(2,i);
    av_cq = coef_ave(3,i);
    
    coef_mat = [ct,ct,ct,ct;dct,-dct,dct,-dct;-dct,dct,dct,-dct;-cq,cq,-cq,cq];
    av_coef_mat = [av_ct,av_ct,av_ct,av_ct;av_dct,-av_dct,av_dct,-av_dct;-av_dct,av_dct,av_dct,-av_dct;-av_cq,av_cq,-av_cq,av_cq];
    for iN = 1:length(omega)
        osq = omega(:,iN).^2;
        T = coef_mat * osq;
        T_av = av_coef_mat * osq;
        
        T_plot = [T_plot,T];
        T_av_plot = [T_av_plot,T_av];
    end
    figure('Visible','on','Name','Check Coefficients')
    title = sprintf('Matrix Determined %d',i);
    mat_det = uitab('Title',title);
    mat_ax = axes(mat_det);
    title2 = sprintf('Average Determined %d',i);
    av_det = uitab('Title',title2);
    av_ax = axes(av_det);
    
    time = 1:length(T_plot(1,:));
    
    mat = plot(mat_ax,time,T_plot(1,:),time,T_plot(2,:),time,T_plot(3,:),time,T_plot(4,:),time,a_fz,time,a_tx,time,a_ty,time,a_tz);
    legend(mat,'Calculated Fz','Calculated Tx','Calculated Ty','Calculated Tz','Force Z','Torque X','Torque Y','Torque Z','Orientation','horizontal')
    
    av = plot(av_ax,time,T_av_plot(1,:),time,T_av_plot(2,:),time,T_av_plot(3,:),time,T_av_plot(4,:),time,a_fz,time,a_tx,time,a_ty,time,a_tz);
    legend(av,'Calculated Fz','Calculated Tx','Calculated Ty','Calculated Tz','Force Z','Torque X','Torque Y','Torque Z','Orientation','horizontal')
end



% [U,S,V] = svd(omega_mat,'econ');
% s = diag(S);
% d = U'*T_mat;
% coef2 = V*([d(1:3)./s(1:3)]); %;zeros(length(T_mat)-3,1)])
% disp(coef2)

