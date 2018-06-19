function Create_Nonlinear_Test_Data
%Creating a set of omegas, and the resulting FT's, then adding noise to the
%dataset and seeing how my model deals with it

%Im going to use a fixed value of ct, d, and cq
%Then ill create omegas and solve for the FT values
%Then ill add noise to the dataset and plug into my analysis program

%My analysis program should return the same ct, d, and cq 

omega = create_omega();
omega_noise = noise(omega,18);

cts = create_cts(omega_noise);

fts = model(cts,omega_noise);

a_fz = fts(1,:);
a_tx = fts(2,:);
a_ty = fts(3,:);
a_tz = fts(4,:);
a_o1 = omega_noise(1,:);
a_o2 = omega_noise(2,:);
a_o3 = omega_noise(3,:);
a_o4 = omega_noise(4,:);

plot_fts(fts)
plot_omegas(omega_noise)


save([mfilename '_nonlinear_data_2018_06_18_Sample_Data'],'a_fz','a_tx','a_ty','a_tz','a_o1','a_o2','a_o3','a_o4')



function omega = create_omega()
horizontal = ones(1,3000)*1000;
slope = 1:.2:200;
negslop = 200:-.2:1;

wavy_horiz = sin(0:.0524:(50*pi))*15;

motor1 = [slope+1300,horizontal*1.5,(slope*1.5)+1500,horizontal*1.8,negslop+1600,wavy_horiz+1600];
motor2 = [(slope*.9)+1300,wavy_horiz+1480,slope+1480,horizontal*1.68,slope+1680,horizontal*1.88];
motor3 = [(slope*1.5)+1300,horizontal*1.6,negslop+1400,wavy_horiz+1400,slope+1400,horizontal*1.6];
motor4 = [(slope*.6)+1300,wavy_horiz+1420,slope+1420,horizontal*1.62,(negslop)+1420,horizontal*1.420];

omega = [motor1;motor2;motor3;motor4];

function cts = create_cts(omega)
cts = zeros(3,length(omega));

for j = 1:length(omega)
    d = .118;
    ct = CT_function(mean(omega(:,j)));
    cts(1,j) = ct;
    cts(2,j) = d * ct;
    cts(3,j) = -3.542252 *10^-8;
end

function ct = CT_function(omega)
x1 = 2.331532*10^-6;
x2 = 2.103702*10^5;
x3 = 9.739919*10^-3;

ct = x1/(1+x2*exp(-x3*omega));

function fts = model(cts,omega)
fts = zeros(4,length(omega));

for i = 1:length(omega)
    ct = cts(1,i);
    dct = cts(2,i);
    cq = cts(3,i);
    coef_mat = [ct,ct,ct,ct;dct,-dct,dct,-dct;-dct,dct,dct,-dct;-cq,cq,-cq,cq];
    fts(:,i) = coef_mat*omega(:,i).^2;
end

function out = noise(data,n)
[r,c] = size(data);
out = zeros(r,c);

for i = 1:r
    for j = 1:c
        num = randi([-1,1]);
        if num > 0
            out(i,j) = data(i,j) + (randi([-n,n])*rand);
        else
            out(i,j) = data(i,j);
        end
    end
end
        
function plot_fts(fts)
figure('Visible','on','Name','FTs plot')
l = 1:length(fts);
plot(l,fts(1,:),l,fts(2,:),l,fts(3,:),l,fts(4,:))

function plot_omegas(omega)
figure('Visible','on','Name','Omega Plot')
l = 1:length(omega);
plot(l,omega(1,:),l,omega(2,:),l,omega(3,:),l,omega(4,:))






