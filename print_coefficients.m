function print_coefficients(all_or_combined,vals)
combined = {'Ct','dCt','Cq'};
all = {'Ct1','Ct2','Ct3','Ct4','dCt1','dCt2','dCt3','dCt4','Cq1','Cq2','Cq3','Cq4'};

if strcmp(all_or_combined,'combined')
    for i = 1:3
        fprintf('%s = %e\n',combined{i},vals(i))
    end
else
    for j = 1:12
        fprintf('%s = %e\n',all{j},vals(j))
    end
end
end