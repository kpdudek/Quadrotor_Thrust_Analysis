function Create_Test_Data
%Creating a set of omegas, and the resulting FT's, then adding noise to the
%dataset and seeing how my model deals with it

omega = create_omega();
omega_noise = noise(omega,15);
cts = create_cts(omega_noise);
fts = model(cts,omega_noise);


a_fz = fts(1,:);


save([mfilename '_data_2018_06_18_Sample_Data'],'a_fz','a_tx','a_ty','a_tz','a_o1','a_o2','a_o3','a_o4')



function omega = create_omega()
horizontal = ones(1,3000)*1000;
slope = 1:.2:200;

motor1 = [slope+1300,horizontal*1.5,slope+1500,horizontal*1.7,slope+1700,horizontal*1.9];
motor2 = [(slope*.9)+1300,horizontal*1.48,slope+1480,horizontal*1.68,slope+1680,horizontal*1.88];
motor3 = [(slope*1.1)+1300,horizontal*1.52,slope+1520,horizontal*1.72,slope+1720,horizontal*1.920];
motor4 = [(slope*.8)+1300,horizontal*1.46,slope+1460,horizontal*1.66,slope+1660,horizontal*1.860];

omega = [motor1;motor2;motor3;motor4];

function cts = create_cts(omega)
cts = zeros(4,length(omega));
for i = 1:4
    for j = 1:length(omega)
        cts(i,j) = CT_function(omega(i,j));
    end
end

function ct = CT_function(omega)
x1 = 2.331532*10^-6;
x2 = 2.103702*10^5;
x3 = 9.739919*10^-3;

ct = x1/(1+x2*exp(-x3*omega));

function fts = model(cts,omega)
d = .118;
fts = zeros(3,length(omega));

for i = 1:length(omega)
    ct1 = cts(1,i);
    ct2 = cts(2,i);
    ct3 = cts(3,i);
    ct4 = cts(4,i);
    
    coef_mat = [ct1,ct2,ct3,ct4;d*ct1,-d*ct2,d*ct3,-d*ct4;-d*ct1,d*ct2,d*ct3,-d*ct4];
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
        
        
        
     