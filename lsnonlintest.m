function lsnonlintest
load('POCidentification_all_coefs_2018_05_31_Manual.mat')
xRecovered = [];

for i = 1:length(coef)
    ct = coef(1,i);
    d = coef(2,i)/coef(1,i);
    
    coef_0 = [ct;d];
    FT_true = T;%(:,i);
    
    %FTmeasured = model(omega,coef);
    xRecovered = [xRecovered,(lsqnonlin(@(x) residuals(FT_true,omega,x),coef_0))];
    fprintf('Estimated: ct = %e -- d = %f\nFitted: ct = %e -- d = %f\n',ct,d,xRecovered(1),xRecovered(2))
end

ct = coef(1,:);
d = coef(2,:)./coef(1,:);
len = 1:length(xRecovered(1,:));
plot(len,xRecovered(1,:),'r:+',len,xRecovered(2,:),'k:+',len,ct,'r',len,d,'k')
legend('LS Ct','LS d','Calculated Ct','Calculated d')


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

% for i = 1:length(omega)
%     ft = [ft,(coef_mat*omega(:,i))];
% end

