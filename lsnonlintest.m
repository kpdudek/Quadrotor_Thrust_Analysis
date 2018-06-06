function lsnonlintest
load('POCidentification_all_coefs_2018_06_06_Circles_Acro.mat')
load('POCidentification_test_span_2018_06_06_Circles_Acro.mat')

fitted_coefs = [];

% for i = 1:length(coef)
%     ct = coef(1,i);
%     d = coef(2,i)/coef(1,i);
%     
%     coef_0 = [ct;d];
%     FT_true = T;
%     
%     fitted_coefs = [fitted_coefs,(lsqnonlin(@(x) residuals(FT_true,omega,x),coef_0))];
%     fprintf('Estimated: ct = %e -- d = %f\nFitted: ct = %e -- d = %f\n',ct,d,fitted_coefs(1),fitted_coefs(2))
% end
% 
% plot_coef_vs_fitted(coef,fitted_coefs)
% 
% use_LS_values(fitted_coefs,omega,T)

fit4 = ct_vs_omega(omega,coef,n1,n2);

plot_ct_all_omega(discreet_coef,omega,n1,n2)

use_model_for_cTs(fit4,omega,T)

plot_function(fit4)

discreet_ct_vs_omega_fit(omega,discreet_coef,n1,n2,T)



function f = residuals(FT_true,omega,x)
f = [];
for i = 1:length(omega)
    f = [f,(FT_true(1:3,i)-model(omega(:,i),x))];
end

function ft = model(omega,x)
ft = [];

ct=x(1);
d=x(2);
dct = ct*d;

coef_mat = [ct,ct,ct,ct;dct,-dct,dct,-dct;-dct,dct,dct,-dct];
ft = (coef_mat*omega);

function use_LS_values(fitted_coefs,omega,T)
FT_true = T;
T_fit = [];
ct = fitted_coefs(1);
d = fitted_coefs(2);
dct = ct * d;
coef_mat = [ct,ct,ct,ct;dct,-dct,dct,-dct;-dct,dct,dct,-dct];

for i = 1:length(omega)
    T_fit = [T_fit,(coef_mat * omega(:,i))];
end

len = 1:length(omega);
figure('Visible','on','Name','Estimated FTs using Least Squares Coefs')
plot(len,T_fit(1,:),'r:',len,T_fit(2,:),'k:',len,T_fit(3,:),'g:',len,FT_true(1,:),'r',len,FT_true(2,:),'k',len,FT_true(3,:),'g')
xlabel('time')
ylabel('Newtons')
legend('LS Fz','LS Tx','LS Ty','Fz','Tx','Ty')

function plot_coef_vs_fitted(coef,fitted_coefs)
ct = coef(1,:);
d = coef(2,:)./coef(1,:);
len = 1:length(fitted_coefs(1,:));
figure('Visible','on','Name','Least Squares vs Matrix Determined')
plot(len,fitted_coefs(1,:),'r:+',len,fitted_coefs(2,:),'k:+',len,ct,'r',len,d,'k')
legend('LS Ct','LS d','Calculated Ct','Calculated d')

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
fun4 = @(x,data) x(1)./(1+x(2)*exp(-x(3).*data));
fit4 = nlinfit(ave_omega,coef(1,:),fun4,x3);
fprintf('beta = %e\ngamma = %e\npower = %e\n',fit4(1),fit4(2),fit4(3))

plot(ave_omega,coef(1,:),ave_omega,fit(1)*log(ave_omega-fit(2)),ave_omega,fit2(1)./(1+(1./(ave_omega-fit2(2)).^fit2(3))),ave_omega,(fit3(1))./(1+fit3(2)*exp(-fit3(3).*ave_omega)),ave_omega,fit4(1)./(1+fit4(2)*exp(-fit4(3).*ave_omega)))
legend('cT','Log Fit','Exponential Fit','1/e^x Fit(curvefit)','1/e^x Fit(nlinfit)')
xlabel('Average Omega')
ylabel('ct')

function plot_ct_all_omega(discreet_coef,omega,n1,n2)
figure('Visible','on','Name','Omega vs Coefs')

omega_ave = mean(omega(:,n1(1):n2(end)));

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
cts = zeros(1,length(omega));
ave_omegas = zeros(1,length(omega));

%USING THE MODEL FOR CT TO CALCULATE THE FT'S
for i = 1:length(omega)
    
    ave_omega = mean(omega(:,i));
    ave_omegas(i) = ave_omega;
    ct = fit4(1)./(1+fit4(2)*exp(-fit4(3).*ave_omega));
    cts(i) = ct;
    dct = ct*.13;
    coef_mat = [ct,ct,ct,ct;dct,-dct,dct,-dct;-dct,dct,dct,-dct];
    
    ft(:,i) = (coef_mat*(omega(:,i).^2));
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
plot(ct_ax,ave_omegas,cts,'.')
xlabel('Average Omega')
ylabel('ct')


%FILTERING THE MODEL PREDICTED DATA
L = length(omega);
w = 26;
w2 = w/2;
t_sl = x(w2+1:end-w2);

sl_fz = [];
ft_sl = ft(1,:);
for i = w2+1:(L-w2)
    vals = ft_sl(i-w2:i+w2);
    sl_fz(end+1) = mean(vals);
end

sl_tx = [];
ft_slx = ft(2,:);
for i = w2+1:(L-w2)
    vals = ft_slx(i-w2:i+w2);
    sl_tx(end+1) = mean(vals);
end

sl_ty = [];
ft_sly = ft(3,:);
for i = w2+1:(L-w2)
    vals = ft_sly(i-w2:i+w2);
    sl_ty(end+1) = mean(vals);
end

tab_sl = uitab('Title','SW Filter on Model Values'); 
ax_sl = axes(tab_sl);
plot(ax_sl,t_sl,sl_ty,'b:',t_sl,T(3,w2+1:L-w2),'b',t_sl,sl_fz,'r:',t_sl,T(1,w2+1:L-w2),'r',t_sl,sl_tx,'g:',t_sl,T(2,w2+1:L-w2),'g');
legend('Filtered Predicted Ty','Ty','Filtered Predicted Fz','Fz','Filtered Predicted Tx','Tx')


function discreet_ct_vs_omega_fit(omega,discreet_coef,n1,n2,T)
figure('Visible','on','Name','Discreet cT vs Omega Fit')

ave_omega = mean(omega);
ave_omega = ave_omega(n1(1):n2(end));

x = [(2.089*10^-6),10245,.007217];
fun = @(x,data) x(1)./(1+x(2)*exp(-x(3).*data));
fit = nlinfit(ave_omega,discreet_coef(1,:),fun,x);
fprintf('beta = %e\ngamma = %e\npower = %e\n',fit(1),fit(2),fit(3))

ft = uitab('Title','Fitted Curve');
ax = axes(ft);
plot(ax,ave_omega,discreet_coef(1,:),'.',ave_omega,fit(1)./(1+fit(2)*exp(-fit(3).*ave_omega)))


ave_omega = mean(omega);
ft = zeros(3,length(omega));
cts = zeros(1,length(ave_omega));
%USING THE MODEL FOR CT TO CALCULATE THE FT'S
for i = 1:length(ave_omega)

    ct = fit(1)./(1+fit(2)*exp(-fit(3).*ave_omega(i)));
    cts(i) = ct;
    dct = ct*.13;
    coef_mat = [ct,ct,ct,ct;dct,-dct,dct,-dct;-dct,dct,dct,-dct];
    
    ft(:,i) = (coef_mat*(omega(:,i).^2));
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
plot(ct_ax,ave_omega,cts,'.')
xlabel('Average Omega')
ylabel('ct')











