function POCidentification
%Loads output of POC_tracks_alignment
load('POC_tracks_alignment_data_2018_06_01_4Corners_Acro.mat')

%Takes the data input, and forms the matricies used in future calculations
[omega,T] = create_matricies(a_o1,a_o2,a_o3,a_o4,a_fz,a_tx,a_ty,a_tz);

%Span to calculate coefficients over
load('POCidentification_test_span_2018_06_01_4Corners_Acro.mat')
%n1 = [599,4661,8307,12470,16980];
%n2 = [4535,7954,12120,16740,20880];
len_n1 = length(n1);
len_n2 = length(n2);

figures = [];

%Solves for the coefficients and then uses them to check theoretical versus
%actual. This is where we see if it is truly a linear system
coef = combined_coefficients(omega,T,n1,n2,len_n1,len_n2);

%Stars for clarity
print_stars()

coef_ave = average_combined_coefficients(omega,T,n1,n2,len_n1,len_n2);
figures = use_coefficients(coef,coef_ave,omega,a_fz,a_tx,a_ty,a_tz,n1,n2,len_n1,figures);
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



%savefig(figures,'Figures_POC_tracks_alignment_data_2018_05_29.fig')
save([mfilename '_all_coefs_2018_06_01_4Corners_Acro.mat'],'coef','coef_ave','independent_coef','omega','T')
%save([mfilename '_test_span_2018_06_01_4Corners_Acro.mat'],'n1','n2')



%Initialize the matricies
function [omega,T] = create_matricies(a_o1,a_o2,a_o3,a_o4,a_fz,a_tx,a_ty,a_tz)
omega = [a_o1;a_o2;a_o3;a_o4];
T = [a_fz;a_tx;a_ty;a_tz];

%Calculates the coefficients using matricies for each point along the horizontal 
function coef = combined_coefficients(omega,T,n1,n2,len_n1,len_n2)
coef = [];
for i = 1:len_n1
    omega_mat = [];
    T_mat = [];
    for iN = n1(i):n2(i)
        osq = omega(:,iN).^2;
        Ti = T(:,iN);
        mat_o = [sum(osq),0,0;0,osq(1)-osq(2)+osq(3)-osq(4),0;0,-osq(1)+osq(2)+osq(3)-osq(4),0;0,0,-osq(1)+osq(2)-osq(3)+osq(4)];
        %mat_T = Ti;
        
        omega_mat = [omega_mat;mat_o];
        T_mat = [T_mat;Ti];
    end
    %looping and solving for coefficients at each horizontal
    fprintf('\n<< Linear system solution for %d - %d >>\n',n1(i),n2(i))
    coef = [coef,(omega_mat\T_mat)];
    print_coefficients('combined',coef(:,i))
end

%Calculates the combined coefficients using the averave values of w and t
%over the horizontals
function coef_ave = average_combined_coefficients(omega,T,n1,n2,len_n1,len_n2)
coef_ave = [];
for m = 1:len_n1
    omega_mat = [];
    T_mat = [];
    T_ave = [];
    omega_ave = [];
    for iN = n1(m):n2(m)
        osq = omega(:,iN).^2;
        Ti = T(:,iN);
        mat_o = [sum(osq),0,0;0,osq(1)-osq(2)+osq(3)-osq(4),0;0,-osq(1)+osq(2)+osq(3)-osq(4),0;0,0,-osq(1)+osq(2)-osq(3)+osq(4)];
        %mat_T = Ti;
        
        omega_mat = [omega_mat;mat_o];
        T_mat = [T_mat;Ti];
    end
    denominator = n2(m) - n1(m);
    for k = 1:4
        T_ave(k,1) = sum(T_mat(k:4:end))/(denominator);
        omega_ave(k,1) = sum(omega_mat(k:4:end,1))/(denominator);
        omega_ave(k,2) = sum(omega_mat(k:4:end,2))/(denominator);
        omega_ave(k,3) = sum(omega_mat(k:4:end,3))/(denominator);
    end
    
    fprintf('\n<< Averaging solution for %d - %d >>\n',n1(m),n2(m))
    coef_ave = [coef_ave,(omega_ave\T_ave)];
    print_coefficients('combined',coef_ave(:,m))
end

%Uses the coefficients from each horizontal to solve for the F/Ts at given
%omegas
function figures = use_coefficients(coef,coef_ave,omega,a_fz,a_tx,a_ty,a_tz,n1,n2,len_n1,figures)
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
coef_plot = plot(ax,t,coef(1,:),'b',t,coef(2,:),'k',t,coef(3,:),'r',t,coef_ave(1,:),'b--+',t,coef_ave(2,:),'k--',t,coef_ave(3,:),'r--');
legend(coef_plot,'Ct','dCt','cq','ave_Ct','ave_dCt','ave_cq')

% tab2 = uitab('Title','Average Coefficients');
% ax_average = axes(tab2);
% coef_ave_plot = plot(ax_average,t,coef_ave(1,:),t,coef_ave(2,:),t,coef_ave(3,:));
% legend(coef_ave_plot,'Ct','dCt','cq')

tab2 = uitab('Title','dct/ct');
ax2 = axes(tab2);
coef_plot2 = plot(ax2,t,coef(1,:),'b',t,coef(2,:),'k',t,(coef(2,:)./coef(1,:)),'r');
legend(coef_plot2,'ct','dct','dct/ct')

%Solves for the coefficients using the entire data set
function figures = combined_whole_dataset(omega,T,a_fz,a_tx,a_ty,a_tz,figures)
omega_mat = [];
T_mat = [];

for iN = 1:length(omega)
    osq = omega(:,iN).^2;
    Ti = T(:,iN);
    mat_o = [sum(osq),0,0;0,osq(1)-osq(2)+osq(3)-osq(4),0;0,-osq(1)+osq(2)+osq(3)-osq(4),0;0,0,-osq(1)+osq(2)-osq(3)+osq(4)];
    %mat_T = Ti;
    
    omega_mat = [omega_mat;mat_o];
    T_mat = [T_mat;Ti];
end

%Solve for coefficients
coef = omega_mat\T_mat;
fprintf('\n<< Combined Linear system solution for entire data set >>\n')
print_coefficients('combined',coef)

%Lets use the calculated coefficient matrix to solve for the F/Ts and compare to experimental results

T_plot = [];

ct = coef(1);
dct = coef(2);
cq = coef(3);

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
    omega_mat = [];
    T_mat = [];
    for iN = n1(i):n2(i)
        osq = omega(:,iN).^2;
        Ti = T(:,iN);
        mat_o = [osq(1),osq(2),osq(3),osq(4),0,0,0,0,0,0,0,0;
            0,0,0,0,osq(1),-osq(2),osq(3),-osq(4),0,0,0,0;
            0,0,0,0,-osq(1),osq(2),osq(3),-osq(4),0,0,0,0;
            0,0,0,0,0,0,0,0,-osq(1),osq(2),-osq(3),osq(4)];
        
        omega_mat = [omega_mat;mat_o];
        T_mat = [T_mat;Ti];
    end
    
    fprintf('\n<< Independent Values for %d - %d >>\n',n1(i),n2(i))
    independent_coef = [independent_coef,(omega_mat\T_mat)];
    print_coefficients('all',independent_coef(:,i))
end

%%%%%YIELDS WEIRD OUTPUT
function average_independent_coefficients(omega,T,n1,n2,len_n1)
ave_independent_coef = [];
for i = 1:len_n1
    omega_mat = [];
    T_mat = [];
    T_ave = [];
    omega_ave = [];
    for iN = n1(i):n2(i)
        osq = omega(:,iN).^2;
        Ti = T(:,iN);
        mat_o = [osq(1),osq(2),osq(3),osq(4),0,0,0,0,0,0,0,0;
            0,0,0,0,osq(1),-osq(2),osq(3),-osq(4),0,0,0,0;
            0,0,0,0,-osq(1),osq(2),osq(3),-osq(4),0,0,0,0;
            0,0,0,0,0,0,0,0,-osq(1),osq(2),-osq(3),osq(4)];
        
        omega_mat = [omega_mat;mat_o];
        T_mat = [T_mat;Ti];
    end
    
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
        omega_ave(k,9) = sum(omega_mat(k:4:end,9))/(denominator);
        omega_ave(k,10) = sum(omega_mat(k:4:end,10))/(denominator);
        omega_ave(k,11) = sum(omega_mat(k:4:end,11))/(denominator);
        omega_ave(k,12) = sum(omega_mat(k:4:end,12))/(denominator);
    end
    
    fprintf('\n<< Average Independent Values for %d - %d >>\n',n1(i),n2(i))
    ave_independent_coef = [ave_independent_coef,(omega_ave\T_ave)];
    print_coefficients('all',ave_independent_coef(:,i))
end

%Uses the coefficients for each motor to solve for the F/Ts at a given
%omega
function figures = use_independent(independent_coef,omega,a_fz,a_tx,a_ty,a_tz,n1,n2,len_n1,figures)

for i = 1:len_n1
    
    T_plot = [];
    
    ct1 = independent_coef(1,i);
    ct2 = independent_coef(2,i);
    ct3 = independent_coef(3,i);
    ct4 = independent_coef(4,i);
    dct1 = independent_coef(5,i);
    dct2 = independent_coef(6,i);
    dct3 = independent_coef(7,i);
    dct4 = independent_coef(8,i);
    cq1 = independent_coef(9,i);
    cq2 = independent_coef(10,i);
    cq3 = independent_coef(11,i);
    cq4 = independent_coef(12,i);
    
    coef_mat = [ct1,ct2,ct3,ct4;dct1,-dct2,dct3,-dct4;-dct1,dct2,dct3,-dct4;-cq1,cq2,-cq3,cq4];
    
    for iN = 1:length(omega)
        osq = omega(:,iN).^2;
        T = coef_mat * osq;
        
        T_plot = [T_plot,T];
    end
    
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

tab_dct = uitab('Title','dCT');
ax_dct = axes(tab_dct);
plot(ax_dct,t,independent_coef(5,:),t,independent_coef(6,:),t,independent_coef(7,:),t,independent_coef(8,:));

tab_cq = uitab('Title','CQ');
ax_cq = axes(tab_cq);
plot(ax_cq,t,independent_coef(9,:),t,independent_coef(10,:),t,independent_coef(11,:),t,independent_coef(12,:));

tab_div = uitab('Title','dct/ct');
ax_div = axes(tab_div);
plot(ax_div,t,(independent_coef(8,:)./independent_coef(4,:)),t,(independent_coef(7,:)./independent_coef(3,:)),t,(independent_coef(6,:)./independent_coef(2,:)),t,(independent_coef(5,:)./independent_coef(1,:)));

%Solves for the independent coefficients using the entire data set
function figures = independent_whole_dataset(omega,T,a_fz,a_tx,a_ty,a_tz,figures)
omega_mat = [];
T_mat = [];

for iN = 1:length(omega)
    osq = omega(:,iN).^2;
    Ti = T(:,iN);
    mat_o = [osq(1),osq(2),osq(3),osq(4),0,0,0,0,0,0,0,0;
            0,0,0,0,osq(1),-osq(2),osq(3),-osq(4),0,0,0,0;
            0,0,0,0,-osq(1),osq(2),osq(3),-osq(4),0,0,0,0;
            0,0,0,0,0,0,0,0,-osq(1),osq(2),-osq(3),osq(4)];
    
    omega_mat = [omega_mat;mat_o];
    T_mat = [T_mat;Ti];
end

%Solve for coefficients
coef = omega_mat\T_mat;
fprintf('\n<< Independent Linear system solution for entire data set >>\n')
print_coefficients('all',coef)

%Lets use the calculated coefficient matrix to solve for the F/Ts and compare to experimental results

T_plot = [];

ct1 = coef(1);
ct2 = coef(2);
ct3 = coef(3);
ct4 = coef(4);
dct1 = coef(5);
dct2 = coef(6);
dct3 = coef(7);
dct4 = coef(8);
cq1 = coef(9);
cq2 = coef(10);
cq3 = coef(11);
cq4 = coef(12);

coef_mat = [ct1,ct2,ct3,ct4;dct1,-dct2,dct3,-dct4;-dct1,dct2,dct3,-dct4;-cq1,cq2,-cq3,cq4];

for iN = 1:length(omega)
    osq = omega(:,iN).^2;
    T = coef_mat * osq;
   
    T_plot = [T_plot,T];
end
figures(end+1) = figure('Visible','on','Name','Check Independent Coefficients Over Whole Set');
title = sprintf('Independent Matrix Determined over entire set');
mat_det = uitab('Title',title);
mat_ax = axes(mat_det);

time = 1:length(T_plot(1,:));

mat = plot(mat_ax,time,T_plot(1,:),'r:',time,T_plot(2,:),'k:',time,T_plot(3,:),'g:',time,T_plot(4,:),'b:',time,a_fz,'r',time,a_tx,'k',time,a_ty,'g',time,a_tz,'b');
legend(mat,'Calculated Fz','Calculated Tx','Calculated Ty','Calculated Tz','Force Z','Torque X','Torque Y','Torque Z','Orientation','horizontal')

%Prints a line of asteriscs for output separation
function print_stars()
fprintf('\n*************************************************************\n')



% [U,S,V] = svd(omega_mat,'econ');
% s = diag(S);
% d = U'*T_mat;
% coef2 = V*([d(1:3)./s(1:3)]); %;zeros(length(T_mat)-3,1)])
% disp(coef2)

