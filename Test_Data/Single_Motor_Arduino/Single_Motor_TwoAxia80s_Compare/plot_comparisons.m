function plot_comparisons

invert = load('Inverted.mat');
invert2 = load('Second_Inverted.mat');
insul = load('Upright_Insulation.mat');
insul2 = load('Second_Upright_Insulated.mat');
bare = load('Upright_Noninsulated.mat');
bare2 = load('Second_Upright_Noninsulated.mat');

figure('Visible','on','Name','Comparison Plots');

noinsul = uitab('Title','No-Insulation');
noinsul_ax = axes(noinsul);
plot(noinsul_ax,1:length(bare.sl_pfz)-10000,bare.sl_pfz(1:end-10000),1:length(bare2.sl_pfz),bare2.sl_pfz);

insulated = uitab('Title','Insulation');
insul_ax = axes(insulated);
plot(insul_ax,1:length(insul.sl_pfz),insul.sl_pfz,1:length(insul2.sl_pfz),insul2.sl_pfz);

inverted = uitab('Title','Inverted with Insulation');
invert_ax = axes(inverted);
plot(invert_ax,1:length(invert.sl_pfz),invert.sl_pfz,1:length(invert2.sl_pfz),invert2.sl_pfz);



