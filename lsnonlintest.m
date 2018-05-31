function lsnonlintest
load('POCidentification_all_coefs_2018_05_31_Manual.mat')
fitted_coefs = [];

for i = 1:length(coef)
    ct = coef(1,i);
    d = coef(2,i)/coef(1,i);
    
    coef_0 = [ct;d];
    FT_true = T;%(:,i);
    
    %FTmeasured = model(omega,coef);
    fitted_coefs = [fitted_coefs,(lsqnonlin(@(x) residuals(FT_true,omega,x),coef_0))];
    fprintf('Estimated: ct = %e -- d = %f\nFitted: ct = %e -- d = %f\n',ct,d,fitted_coefs(1),fitted_coefs(2))
end

ct = coef(1,:);
d = coef(2,:)./coef(1,:);
len = 1:length(fitted_coefs(1,:));
figure('Visible','on')
plot(len,fitted_coefs(1,:),'r:+',len,fitted_coefs(2,:),'k:+',len,ct,'r',len,d,'k')
legend('LS Ct','LS d','Calculated Ct','Calculated d')

use_LS_values(fitted_coefs,omega,T)


function f=residuals(FT_true,omega,x)
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
figure('Visible','on')
plot(len,T_fit(1,:),'r:',len,T_fit(2,:),'k:',len,T_fit(3,:),'g:',len,FT_true(1,:),'r',len,FT_true(2,:),'k',len,FT_true(3,:),'g')
% for i = 1:length(omega)
%     ft = [ft,(coef_mat*omega(:,i))];
% end

