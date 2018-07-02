function POCidentification
%Loads output of POC_tracks_alignment
load('POC_tracks_alignment_data_2018_07_02_4Corners_2Indicators_Manual.mat')  %   POC_tracks_alignment_data_2018_06_19_ThrustUpDown_4Corners_Acro.mat

%Takes the data input, and forms the matricies used in future calculations
[omega,T] = create_matricies(a_o1,a_o2,a_o3,a_o4,a_fz,a_tx,a_ty,a_tz);
d = .118;

%Span to calculate coefficients over
%load('POCidentification_test_span_2018_06_19_ThrustUpDown_4Corners_Acro.mat')
n1 = [1];
n2 = [length(omega)];
len_n1 = length(n1);

figures = [];

%Solves for the coefficients and then uses them to check theoretical versus
%actual. This is where we see if it is truly a linear system
coef = combined_coefficients(omega,T,n1,n2,len_n1);

%Stars for clarity
print_stars()

coef_ave = average_combined_coefficients(omega,T,n1,n2,len_n1);
figures = use_coefficients(coef,coef_ave,omega,a_fz,a_tx,a_ty,a_tz,n1,n2,len_n1,figures,d);
figures = plot_coefficients(coef,coef_ave,figures);

%Stars for clarity
print_stars()

%Calculate and plot coefficients for the entire data set assuming combined
%coefficients
figures = combined_whole_dataset(omega,T,a_fz,a_tx,a_ty,a_tz,figures);


%Stars for clarity
print_stars()


%Furthering the calculations, here a larger matrix is created that solves
%for the coefficients of each motor
independent_coef = independent_coefficients(omega,T,n1,n2,len_n1);
figures = use_independent(independent_coef,omega,a_fz,a_tx,a_ty,a_tz,n1,n2,len_n1,figures);
figures = plot_independent_coef(independent_coef,figures);

%Stars for clarity
print_stars()

figures = independent_whole_dataset(omega,T,a_fz,a_tx,a_ty,a_tz,figures);

%Stars for clarity
print_stars()

%average_independent_coefficients(omega,T,n1,n2,len_n1)


discreet_coef = discreet_coefs(omega,T,n1,n2);


savefig(figures,'Figures_data_2018_07_02_4Corners_2Indicators_Manual.fig')  
save([mfilename '_all_coefs_data_2018_07_02_4Corners_2Indicators_Manual.mat'],'coef','coef_ave','independent_coef','discreet_coef','omega','T')  
save([mfilename '_test_span_data_2018_07_02_4Corners_2Indicators_Manual.mat'],'n1','n2')  



%Initialize the matricies
function [omega,T] = create_matricies(a_o1,a_o2,a_o3,a_o4,a_fz,a_tx,a_ty,a_tz)
omega = [a_o1;a_o2;a_o3;a_o4];
T = [a_fz;a_tx;a_ty;a_tz];

%Calculates the coefficients using matricies for each point along the horizontal 
function coef = combined_coefficients(omega,T,n1,n2,len_n1)
coef = [];
for i = 1:len_n1
    [omega_mat,T_mat] = combined_matricies(omega(:,n1(i):n2(i)),T(:,n1(i):n2(i)));
    %looping and solving for coefficients at each horizontal
    fprintf('\n<< Linear system solution for %d - %d >>\n',n1(i),n2(i))
    coef = [coef,(omega_mat\T_mat)];
    print_coefficients('no_d',coef(:,i))
end

%Calculates the combined coefficients using the averave values of w and t
%over the horizontals
function coef_ave = average_combined_coefficients(omega,T,n1,n2,len_n1)
coef_ave = [];
for m = 1:len_n1
    T_ave = [];
    omega_ave = [];
    [omega_mat,T_mat] = combined_matricies(omega(:,n1(m):n2(m)),T(:,n1(m):n2(m)));

    denominator = n2(m) - n1(m);
    for k = 1:4
        T_ave(k,1) = sum(T_mat(k:4:end))/(denominator);
        omega_ave(k,1) = sum(omega_mat(k:4:end,1))/(denominator);
        omega_ave(k,2) = sum(omega_mat(k:4:end,2))/(denominator);
    end
    
    fprintf('\n<< Averaging solution for %d - %d >>\n',n1(m),n2(m))
    coef_ave = [coef_ave,(omega_ave\T_ave)];
    print_coefficients('no_d',coef_ave(:,m))
end

%Uses the coefficients from each horizontal to solve for the F/Ts at given
%omegas
function figures = use_coefficients(coef,coef_ave,omega,a_fz,a_tx,a_ty,a_tz,n1,n2,len_n1,figures,d)
%fig = figure('Visible','on','Name','Check Coefficients');
for i = 1:len_n1
    
    T_plot = plot_using_combined_coefs(coef(:,i),omega);
    
    T_av_plot = plot_using_combined_coefs(coef_ave(:,i),omega);

    figures(end+1) = figure('Visible','on','Name','Check Coefficients');
    title = sprintf('Matrix Determined %d - %d',n1(i),n2(i));
    mat_det = uitab('Title',title);
    mat_ax = axes(mat_det);
    title2 = sprintf('Average Determined %d - %d',n1(i),n2(i));
    av_det = uitab('Title',title2);
    av_ax = axes(av_det);
    
    time = 1:length(T_plot(1,:));
    
    mat = plot(mat_ax,time,T_plot(1,:),'r:',time,T_plot(2,:),'k:',time,T_plot(3,:),'g:',time,T_plot(4,:),'b:',time,a_fz,'r',time,a_tx,'k',time,a_ty,'g',time,a_tz,'b');
    rectangle(mat_ax,'Position',[(n1(i)-350) (a_fz(n1(i))-3) ((n2(i)-n1(i))+700) (abs((a_fz(n2(i)))-(a_fz(n1(i))))+6)],'EdgeColor','r')
    legend(mat,'Calculated Fz','Calculated Tx','Calculated Ty','Calculated Tz','Force Z','Torque X','Torque Y','Torque Z','Orientation','horizontal')
    
    av = plot(av_ax,time,T_av_plot(1,:),time,T_av_plot(2,:),time,T_av_plot(3,:),time,T_av_plot(4,:),time,a_fz,time,a_tx,time,a_ty,time,a_tz);
    rectangle(av_ax,'Position',[(n1(i)-350) (a_fz(n1(i))-3) ((n2(i)-n1(i))+700) (abs((a_fz(n2(i)))-(a_fz(n1(i))))+6)],'EdgeColor','r')
    legend(av,'Calculated Fz','Calculated Tx','Calculated Ty','Calculated Tz','Force Z','Torque X','Torque Y','Torque Z','Orientation','horizontal')
end

%Plots the coefficients at each horizontal to check for trends. Also
%divides dct by ct to solve for d. d should be ~13cm
function figures = plot_coefficients(coef,coef_ave,figures)
figures(end+1) = figure('Visible','on','Name','Plotted Coefficients');
t = 1:length(coef(1,:));

tab = uitab('Title','Coefficients');
ax = axes(tab);
coef_plot = plot(ax,t,coef(1,:),'b',t,coef(2,:),'k',t,coef_ave(1,:),'b--+',t,coef_ave(2,:),'k--');
legend(coef_plot,'Ct','cq','ave_Ct','ave_cq')

%Solves for the coefficients using the entire data set
function figures = combined_whole_dataset(omega,T,a_fz,a_tx,a_ty,a_tz,figures)

[omega_mat,T_mat] = combined_matricies(omega,T);

%Solve for coefficients
coef = omega_mat\T_mat;
fprintf('\n<< Combined Linear system solution for entire data set >>\n')
print_coefficients('no_d',coef)

%Lets use the calculated coefficient matrix to solve for the F/Ts and compare to experimental results

T_plot = [];
d = .118;
ct = coef(1);
cq = coef(2);
dct = ct*d;

coef_mat = [ct,ct,ct,ct;dct,-dct,dct,-dct;-dct,dct,dct,-dct;-cq,cq,-cq,cq];

for iN = 1:length(omega)
    osq = omega(:,iN).^2;
    T = coef_mat * osq;
   
    T_plot = [T_plot,T];
end
figures(end+1) = figure('Visible','on','Name','Check Combined Coefficients Over Whole Set');
title = sprintf('Combined Matrix Determined over entire set');
mat_det = uitab('Title',title);
mat_ax = axes(mat_det);

time = 1:length(T_plot(1,:));

mat = plot(mat_ax,time,T_plot(1,:),'r:',time,T_plot(2,:),'k:',time,T_plot(3,:),'g:',time,T_plot(4,:),'b:',time,a_fz,'r',time,a_tx,'k',time,a_ty,'g',time,a_tz,'b');
legend(mat,'Calculated Fz','Calculated Tx','Calculated Ty','Calculated Tz','Force Z','Torque X','Torque Y','Torque Z','Orientation','horizontal')




%Solves for the coeffients of each motor using a matrix at each data point
function independent_coef = independent_coefficients(omega,T,n1,n2,len_n1)
independent_coef = [];
for i = 1:len_n1
    [omega_mat,T_mat] = independent_matricies(omega(:,n1(i):n2(i)),T(:,n1(i):n2(i)));
    
    fprintf('\n<< Independent Values for %d - %d >>\n',n1(i),n2(i))
    independent_coef = [independent_coef,(omega_mat\T_mat)];
    print_coefficients('all',independent_coef(:,i))
end

%Yields no useable output, since single matrix cannot determine all
%independent coefficients
function average_independent_coefficients(omega,T,n1,n2,len_n1)
ave_independent_coef = [];
for i = 1:len_n1
    T_ave = [];
    omega_ave = [];
    [omega_mat,T_mat] = independent_matricies(omega(:,n1(i):n2(i)),T(:,n1(i):n2(i)));
    
    denominator = n2(i) - n1(i);
    for k = 1:4
        T_ave(k,1) = sum(T_mat(k:4:end))/(denominator);
        omega_ave(k,1) = sum(omega_mat(k:4:end,1))/(denominator);
        omega_ave(k,2) = sum(omega_mat(k:4:end,2))/(denominator);
        omega_ave(k,3) = sum(omega_mat(k:4:end,3))/(denominator);
        omega_ave(k,4) = sum(omega_mat(k:4:end,4))/(denominator);
        omega_ave(k,5) = sum(omega_mat(k:4:end,5))/(denominator);
        omega_ave(k,6) = sum(omega_mat(k:4:end,6))/(denominator);
        omega_ave(k,7) = sum(omega_mat(k:4:end,7))/(denominator);
        omega_ave(k,8) = sum(omega_mat(k:4:end,8))/(denominator);
    end
    
    fprintf('\n<< Average Independent Values for %d - %d >>\n',n1(i),n2(i))
    ave_independent_coef = [ave_independent_coef,(omega_ave\T_ave)];
    print_coefficients('all',ave_independent_coef(:,i))
end

%Uses the coefficients for each motor to solve for the F/Ts at a given
%omega
function figures = use_independent(independent_coef,omega,a_fz,a_tx,a_ty,a_tz,n1,n2,len_n1,figures)

for i = 1:len_n1
    
    T_plot = plot_using_independent_coefs(independent_coef(:,i),omega);
    
    figures(end+1) = figure('Visible','on','Name','Check Independent Coefficients');
    title = sprintf('Matrix Determined %d - %d',n1(i),n2(i));
    mat_det = uitab('Title',title);
    mat_ax = axes(mat_det);
    
    time = 1:length(T_plot(1,:));
    
    mat = plot(mat_ax,time,T_plot(1,:),'r:',time,T_plot(2,:),'k:',time,T_plot(3,:),'g:',time,T_plot(4,:),'b:',time,a_fz,'r',time,a_tx,'k',time,a_ty,'g',time,a_tz,'b');
    rectangle(mat_ax,'Position',[(n1(i)-350) (a_fz(n1(i))-3) ((n2(i)-n1(i))+700) (abs((a_fz(n2(i)))-(a_fz(n1(i))))+6)],'EdgeColor','r')
    legend(mat,'Calculated Fz','Calculated Tx','Calculated Ty','Calculated Tz','Force Z','Torque X','Torque Y','Torque Z','Orientation','horizontal')
    
end

%Plots the independent coeffients to check for trends. Also divides dct by
%ct to solve for d. d should be ~13cm
function figures = plot_independent_coef(independent_coef,figures)
figures(end+1) = figure('Visible','on','Name','Plotted Independent Coefficients');
t = 1:length(independent_coef(1,:));

tab_ct = uitab('Title','CT');
ax_ct = axes(tab_ct);
plot(ax_ct,t,independent_coef(1,:),t,independent_coef(2,:),t,independent_coef(3,:),t,independent_coef(4,:));

tab_cq = uitab('Title','CQ');
ax_cq = axes(tab_cq);
plot(ax_cq,t,independent_coef(5,:),t,independent_coef(6,:),t,independent_coef(7,:),t,independent_coef(8,:));

%Solves for the independent coefficients using the entire data set
function figures = independent_whole_dataset(omega,T,a_fz,a_tx,a_ty,a_tz,figures)

[omega_mat,T_mat] = independent_matricies(omega,T);

%Solve for coefficients
coef = omega_mat\T_mat;
fprintf('\n<< Independent Linear system solution for entire data set >>\n')
print_coefficients('all',coef)

%Lets use the calculated coefficient matrix to solve for the F/Ts and compare to experimental results

T_plot = plot_using_independent_coefs(coef,omega);

figures(end+1) = figure('Visible','on','Name','Check Independent Coefficients Over Whole Set');
title = sprintf('Independent Matrix Determined over entire set');
mat_det = uitab('Title',title);
mat_ax = axes(mat_det);

time = 1:length(T_plot(1,:));

mat = plot(mat_ax,time,T_plot(1,:),'r:',time,T_plot(2,:),'k:',time,T_plot(3,:),'g:',time,T_plot(4,:),'b:',time,a_fz,'r',time,a_tx,'k',time,a_ty,'g',time,a_tz,'b');
legend(mat,'Calculated Fz','Calculated Tx','Calculated Ty','Calculated Tz','Force Z','Torque X','Torque Y','Torque Z','Orientation','horizontal')




%Calculates the coefficients at each data instance
function discreet_coef = discreet_coefs(omega,T,n1,n2)
discreet_coef = [];
d = .118;
for i = n1(1):n2(end)
    osq = omega(:,i).^2;
    osqd = osq.*d;
    Ti = T(:,i);
    mat_o = [sum(osq),0;osqd(1)-osqd(2)+osqd(3)-osqd(4),0;-osqd(1)+osqd(2)+osqd(3)-osqd(4),0;0,-osq(1)+osq(2)-osq(3)+osq(4)];
    coefs = mat_o\Ti;
    discreet_coef = [discreet_coef,coefs];
end


%Returns the matricies of omega values and FT values used for calculating
%ct
function [omega_mat,T_mat] = combined_matricies(omega,T)
d = .118;
omega_mat = [];
T_mat = [];

for i = 1:length(omega)
    osq = omega(:,i).^2;
    osqd = osq.*d;
    Ti = T(:,i);
    mat_o = [sum(osq),0;osqd(1)-osqd(2)+osqd(3)-osqd(4),0;-osqd(1)+osqd(2)+osqd(3)-osqd(4),0;0,-osq(1)+osq(2)-osq(3)+osq(4)];
    
    omega_mat = [omega_mat;mat_o];
    T_mat = [T_mat;Ti];
end

%Plots the estimated F/T values using provided ct and omega
%Provide: single ct and omega vector, or single ct and omega matrix
function T_plot = plot_using_combined_coefs(coef,omega)
    d = .118;
    T_plot = [];
    
    ct = coef(1);
    cq = coef(2);
    dct = ct .* d;
    
    coef_mat = [ct,ct,ct,ct;dct,-dct,dct,-dct;-dct,dct,dct,-dct;-cq,cq,-cq,cq];
    
    for iN = 1:length(omega)
        osq = omega(:,iN).^2;
        T = coef_mat * osq;
        
        T_plot = [T_plot,T];
    end


%Returns the matiricies of omega values and FT values used to calculate the
%individual cts
function [omega_mat,T_mat] = independent_matricies(omega,T)
d = .118;
omega_mat = [];
T_mat = [];

for i = 1:length(omega)
    osq = omega(:,i).^2;
    osqd = osq.*d;
    Ti = T(:,i);
    mat_o = [osq(1),osq(2),osq(3),osq(4),0,0,0,0;
        osqd(1),-osqd(2),osqd(3),-osqd(4),0,0,0,0;
        -osqd(1),osqd(2),osqd(3),-osqd(4),0,0,0,0;
        0,0,0,0,-osq(1),osq(2),-osq(3),osq(4)];
    
    omega_mat = [omega_mat;mat_o];
    T_mat = [T_mat;Ti];
end

%Plots the estimated F/T values using the coefficients of each motor.
%Provide: vector of ct's and omega vector, or vector of ct's and matrix of
%omegas
function T_plot = plot_using_independent_coefs(coef,omega)
d = .118;
T_plot = [];

ct1 = coef(1);
ct2 = coef(2);
ct3 = coef(3);
ct4 = coef(4);
dct1 = ct1*d;
dct2 = ct2*d;
dct3 = ct3*d;
dct4 = ct4*d;
cq1 = coef(5);
cq2 = coef(6);
cq3 = coef(7);
cq4 = coef(8);

coef_mat = [ct1,ct2,ct3,ct4;dct1,-dct2,dct3,-dct4;-dct1,dct2,dct3,-dct4;-cq1,cq2,-cq3,cq4];

for iN = 1:length(omega)
    osq = omega(:,iN).^2;
    T = coef_mat * osq;
   
    T_plot = [T_plot,T];
end




%Prints a line of asteriscs for output separation
function print_stars()
fprintf('\n*************************************************************\n')
