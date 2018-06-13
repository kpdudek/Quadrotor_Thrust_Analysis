function lsnonlintest
load('POCidentification_all_coefs_2018_06_06_Circles_Acro.mat')
load('POCidentification_test_span_2018_06_06_Circles_Acro.mat')

fitted_coefs = non_linear_fit(T,omega,coef);

plot_coef_vs_fitted(coef,fitted_coefs)

use_LS_values(fitted_coefs,omega,T)

fit4 = ct_vs_omega(omega,coef,n1,n2);

use_model_for_cTs(fit4,omega,T)

plot_ct_all_omega(discreet_coef,omega,n1,n2)

plot_function(fit4)

discreet_ct_vs_omega_fit(omega,discreet_coef,n1,n2,T)

fitted = coefs_ct_function_omega(T,omega);

use_nonlin(fitted,omega,T)


function fitted_coefs = non_linear_fit(T,omega,coef)
fitted_coefs = [];

for i = 1:length(coef)
    ct = coef(1,i);
    
    coef_0 = ct;
    FT_true = T;
    
    fitted_coefs = [fitted_coefs,(lsqnonlin(@(x) residuals(FT_true,omega,x),coef_0))];
    fprintf('Estimated: ct = %e\nFitted: ct = %e\n',ct,fitted_coefs(i))
end

function f = residuals(FT_true,omega,x)
f = [];
for i = 1:length(omega)
    f = [f,(FT_true(1:3,i)-model(omega(:,i),x))];
end

function ft = model(omega,x)

if (length(x) == 2) || (length(x) == 1)
    ct = x(1);
    d = .118;
    dct = ct*d;
    
    coef_mat = [ct,ct,ct,ct;dct,-dct,dct,-dct;-dct,dct,dct,-dct];
    ft = coef_mat*omega.^2;
    
else
    ct1 = x(1);
    ct2 = x(2);
    ct3 = x(3);
    ct4 = x(4);
    d = .118;
    
    coef_mat = [ct1,ct2,ct3,ct4;d*ct1,-d*ct2,d*ct3,-d*ct4;-d*ct1,d*ct2,d*ct3,-d*ct4];
    ft = coef_mat*omega.^2;
end

function use_LS_values(fitted_coefs,omega,T)
FT_true = T;
T_fit = [];

for i = 1:length(omega)
    T_fit = [T_fit,model(omega(:,i),fitted_coefs)];
end

len = 1:length(omega);
figure('Visible','on','Name','Estimated FTs using Least Squares Coefs')
plot(len,T_fit(1,:),'r:',len,T_fit(2,:),'k:',len,T_fit(3,:),'g:',len,FT_true(1,:),'r',len,FT_true(2,:),'k',len,FT_true(3,:),'g')
xlabel('time')
ylabel('Newtons')
legend('LS Fz','LS Tx','LS Ty','Fz','Tx','Ty')

function plot_coef_vs_fitted(coef,fitted_coefs)
ct = coef(1,:);
len = 1:length(fitted_coefs(1,:));
figure('Visible','on','Name','Least Squares vs Matrix Determined')
plot(len,fitted_coefs(1,:),'r:+',len,ct,'r')
legend('LS Ct','Calculated Ct')

function fit4 = ct_vs_omega(omega,coef,n1,n2)
len_coef = length(coef);
ave_omega_array = zeros(4,len_coef);
ave_omega = zeros(1,len_coef);

for i = 1:len_coef
    ave_omega_array(1,i) = mean(omega(1,n1(i):n2(i)));
    ave_omega_array(2,i) = mean(omega(2,n1(i):n2(i)));
    ave_omega_array(3,i) = mean(omega(3,n1(i):n2(i)));
    ave_omega_array(4,i) = mean(omega(4,n1(i):n2(i)));
end

for j = 1:len_coef
    ave_omega(j) = mean(ave_omega_array(:,j));
end

figure('Visible','on','Name','Average Omega vs cT and Curve Fits')
xlabel('Omega')
ylabel('ct')

x0 = [.000006,1000];
fun = @(x,data) x(1)*log(data-x(2));
fit = lsqcurvefit(fun,x0,ave_omega,coef(1,:));
fprintf('beta = %e\ngamma = %e\n',fit(1),fit(2))

x1 = [.000006,1000,2];
fun2 = @(x,data) x(1)./(1+(1./(data-x(2)).^x(3)));
fit2 = lsqcurvefit(fun2,x1,ave_omega,coef(1,:));
fprintf('beta = %e\ngamma = %e\npower = %e\n',fit2(1),fit2(2),fit2(3))

x2 = [(2.089*10^-6),10245,.007217];
fun3 = @(x,data) x(1)./(1+x(2)*exp(-x(3).*data));
fit3 = lsqcurvefit(fun3,x2,ave_omega,coef(1,:));
fprintf('beta = %e\ngamma = %e\npower = %e\n',fit3(1),fit3(2),fit3(3))

x3 = [(2.089*10^-6),10245,.007217];
fun4 = @(x,data) x(1)./(1+x(2).*exp(-x(3).*data));
fit4 = nlinfit(ave_omega,coef(1,:),fun4,x3);
fprintf('beta = %e\ngamma = %e\npower = %e\n',fit4(1),fit4(2),fit4(3))

plot(ave_omega,coef(1,:),ave_omega,fit(1)*log(ave_omega-fit(2)),ave_omega,fit2(1)./(1+(1./(ave_omega-fit2(2)).^fit2(3))),ave_omega,(fit3(1))./(1+fit3(2)*exp(-fit3(3).*ave_omega)),ave_omega,fit4(1)./(1+fit4(2)*exp(-fit4(3).*ave_omega)))
legend('cT','Log Fit','Exponential Fit','1/e^x Fit(curvefit)','1/e^x Fit(nlinfit)')
xlabel('Average Omega')
ylabel('ct')

function plot_ct_all_omega(discreet_coef,omega,n1,n2)
figure('Visible','on','Name','Omega vs Coefs')
omega = omega(:,n1(1):n2(end));
omega_ave = mean(omega);

ct = uitab('Title','Average Omega vs ct');
ct_ax = axes(ct);
plot(ct_ax,omega_ave,discreet_coef(1,:),'.') %,1:length(omega_ave),condition(omega_ave),
xlabel('Average Omega')
ylabel('ct')

ctt = uitab('Title','t vs ct');
ctt_ax = axes(ctt);
plot(ctt_ax,1:length(omega_ave),discreet_coef(1,:),'.')
xlabel('time')
ylabel('ct')

dt = uitab('Title','Average Omega vs d');
d_ax = axes(dt);
d = discreet_coef(2,:)./discreet_coef(1,:);
plot(d_ax,omega_ave,d,'.')
xlabel('Average Omega')
ylabel('d')

function s_conditioned = condition(s)
s=shiftdim(s);
sMax=max(s);
sMin=min(s);
s_conditioned=(s-sMin)/(sMax-sMin);

function plot_function(fit4)

func = sprintf('\n\ncT = %f/(1 + %f * exp(-%f * omega))\n\n',fit4(1),fit4(2),fit4(3));
fprintf(func)

function use_model_for_cTs(fit4,omega,T)

ft = zeros(3,length(omega));
cts = zeros(4,length(omega));

%USING THE MODEL FOR CT TO CALCULATE THE FT'S
for i = 1:length(omega)
    for j = 1:4
        cts(j,i) = ct_for_omega(fit4,omega(j,i));
    end
    ft(:,i) = model(omega(:,i),cts(:,i));
end

x = 1:length(omega);
figure('Visible','on','Name','FTs using model predicted ct')

%PLOTTING MODEL FTS VS ACTUAL FTS
fts = uitab('Title','Predicted FTs');
ft_ax = axes(fts);
plot(ft_ax,x,ft(1,:),'r:',x,ft(2,:),'g:',x,ft(3,:),'b:',x,T(1,:),'r',x,T(2,:),'g',x,T(3,:),'b')
legend('Predicted Fz','Predicted Tx','Predicted Ty','Fz','Tx','Ty')

%PLOTTING THE PREDICTED CTS VS OMEGA
ctp = uitab('Title','Predicted Ct vs omega');
ct_ax = axes(ctp);
plot(ct_ax,omega(1,:),cts(1,:),'.',omega(2,:),cts(2,:),'.',omega(3,:),cts(3,:),'.',omega(4,:),cts(4,:),'.')
xlabel('Average Omega')
ylabel('ct')

function discreet_ct_vs_omega_fit(omega,discreet_coef,n1,n2,T)
figure('Visible','on','Name','Discreet cT vs Omega Fit')

ave_omega = mean(omega);

fit = ct_nlinfit(ave_omega(:,n1(1):n2(end)),discreet_coef(1,:));

ft = uitab('Title','Fitted Curve');
ax = axes(ft);
plot(ax,ave_omega(:,n1(1):n2(end)),discreet_coef(1,:),'.',ave_omega(:,n1(1):n2(end)),fit(1)./(1+fit(2)*exp(-fit(3).*ave_omega(:,n1(1):n2(end)))))

%USING THE MODEL FOR CT TO CALCULATE THE FT'S
ct = zeros(4,length(omega));
for j = 1:4
    ct(j,:) = ct_for_omega(fit,omega(j,:));
end
ft = zeros(3,length(omega));
for k = 1:length(omega)
    ft(:,k) = plot_using_calculated_cts(ct(:,k),omega(:,k));
end

x = 1:length(omega);
%PLOTTING MODEL FTS VS ACTUAL FTS
fts = uitab('Title','Predicted FTs');
ft_ax = axes(fts);
plot(ft_ax,x,ft(1,:),'r:',x,ft(2,:),'g:',x,ft(3,:),'b:',x,T(1,:),'r',x,T(2,:),'g',x,T(3,:),'b')
legend('Predicted Fz','Predicted Tx','Predicted Ty','Fz','Tx','Ty')

%PLOTTING THE PREDICTED CTS VS OMEGA
ctp = uitab('Title','Predicted Ct vs omega');
ct_ax = axes(ctp);
plot(ct_ax,omega(1,:),ct(1,:),'.',omega(2,:),ct(2,:),'.',omega(3,:),ct(3,:),'.',omega(4,:),ct(4,:),'.')
xlabel('Average Omega')
ylabel('ct')

ctt = uitab('Title','Predicted Ct vs Time');
ctt_ax = axes(ctt);
plot(ctt_ax,x,ct(1,:),'.',x,ct(2,:),'.',x,ct(3,:),'.',x,ct(4,:),'.')
xlabel('Average Omega')
ylabel('ct')

function ct = ct_for_omega(fit,omega)
ct = fit(1)./(1+fit(2)*exp(-fit(3).*omega));

function T_plot = plot_using_calculated_cts(coef,omega)
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

coef_mat = [ct1,ct2,ct3,ct4;dct1,-dct2,dct3,-dct4;-dct1,dct2,dct3,-dct4];

for iN = 1:length(omega(1,:))
    osq = omega(:,iN).^2;
    T = coef_mat * osq;
   
    T_plot = [T_plot,T];
end

function fit = ct_nlinfit(omega,ct)
x = [(2.089*10^-6),10245,.007217];
fun = @(x,data) x(1)./(1+x(2).*exp(-x(3).*data));
fit = nlinfit(omega,ct,fun,x);
fprintf('beta = %e\ngamma = %e\npower = %e\n',fit(1),fit(2),fit(3))

function fitted = coefs_ct_function_omega(T,omega)
fitted = [];

coef_0 = [.000002323570,210370.240755,.009541519];
FT_true = T;

fitted = [fitted,(lsqnonlin(@(x) resid(FT_true,omega,x),coef_0))];

fprintf('Estimated: x1 = %e\nEstimated: x2 = %e\nEstimated: x3 = %e\n',fitted(1),fitted(2),fitted(3))

function f = resid(FT_true,omega,x)
f = [];
for i = 1:length(omega)
    f = [f,(FT_true(1:3,i)-model2(omega(:,i),x))];
end

function ft = model2(omega,x)
ct = zeros(1,4);
for i = 1:4
    ct(i) = x(1)/(1+x(2)*exp(-x(3)*omega(i)));
end
ct1 = ct(1);
ct2 = ct(2);
ct3 = ct(3);
ct4 = ct(4);
d = .118;

coef_mat = [ct1,ct2,ct3,ct4;d*ct1,-d*ct2,d*ct3,-d*ct4;-d*ct1,d*ct2,d*ct3,-d*ct4];
ft = coef_mat*omega.^2;

function use_nonlin(fitted,omega,T)
ft = [];
for i = 1:length(omega)
    ft = [ft,model2(omega(:,i),fitted)];
end

x = 1:length(ft(1,:));
figure('Visible','on','Name','Non lin fit with ct(w)')
fts = uitab('Title','Predicted FTs');
ft_ax = axes(fts);
plot(ft_ax,x,ft(1,:),'r:',x,ft(2,:),'g:',x,ft(3,:),'b:',x,T(1,:),'r',x,T(2,:),'g',x,T(3,:),'b')
legend('Predicted Fz','Predicted Tx','Predicted Ty','Fz','Tx','Ty')



















