function lsnonlintest
A=randn(100,2);
xTrue=[2e-3;0.1];
x0=[1e-3;0.2];

yMeasured=model(A,xTrue)+1e-6*randn(size(A,1),1);

xRecovered=lsqnonlin(@(x) residuals(yMeasured,A,x),x0);

disp([x0 xRecovered xTrue])


function f=residuals(y,A,x)
f=y-model(A,x);

function y=model(A,x)
cT=x(1);
d=x(2);
y=A*[cT;cT*d];
