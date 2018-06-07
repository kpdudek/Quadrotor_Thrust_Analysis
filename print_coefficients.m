function print_coefficients(all_or_combined,vals)
combined = {'Ct','dCt','Cq'};
no_d = {'Ct','Cq'};
all = {'Ct1','Ct2','Ct3','Ct4','Cq1','Cq2','Cq3','Cq4'};

if strcmp(all_or_combined,'combined')
    for i = 1:3
        fprintf('%s = %e\n',combined{i},vals(i))
    end
elseif strcmp(all_or_combined,'no_d')
    for k = 1:2
        fprintf('%s = %e\n',no_d{k},vals(k))
    end
else
    for j = 1:8
        fprintf('%s = %e\n',all{j},vals(j))
    end
end
end