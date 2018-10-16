function Plots_For_Paper
%This function just plots specific plots for the paper I am writing. This
%was needed because the matlab tabs messed up the way I wanted the plots to
%look, so I isolated the plots here
load('POC_tracks_alignment_data_2018_07_13_4Corners_2Indicators_Acro.mat')
load('POCidentification_all_coefs_data_2018_07_13_4Corners_2Indicators_Acro.mat')
load('POCidentification_test_span_data_2018_07_13_4Corners_2Indicators_Acro.mat')

file = 'R2_2018_07_13_4Corners_2Indicators_Acro';

% [o1,o2,o3,o4,tp] = PX4_CSV_Plotter_V2(file);
% [ffz,ftx,fty,ftz,t_sl] = ATI_AXIA80_LOG_Processor_V2(file);
% 
% save('o2_ty','o2','fty')

load('o2_ty')

o2f = figure('Visible','on');
o2a = axes(o2f);
t = 1:length(a_o1);
o2 = plot(o2a,t,a_o1,t,a_o2,t,a_o3,t,a_o4);
xlabel('Time')
ylabel('Actuator Outputs')
legend('Motor 1','Motor 2','Motor 3','Motor 4','Location','northwest')

tyf = figure('Visible','on');
tya = axes(tyf);
ty = plot(tya,fty);
xticks([0 20000 40000])
tya.XAxis.Exponent = 0;
%set(tya,'Position',[0.1300 0.1100 0.7750 0.8150])
xlabel('Time')
ylabel('Torque (N*m)')

FT_true = [a_fz;a_tx;a_ty;a_tz];
% 
% for i = 1:7
%     name = sprintf('combined_coef_%d',i);
%     name1 = sprintf('indep_coef_%d',i);
%     
%     load(name)
%     figure('Visible','on','Name',name)
%     plot(time,FT_true,time,T_plot,':')
%     legend({'T_z','\tau_x','\tau_y','\tau_z'},'Location','northwest','NumColumns',2)
%     
%     load(name1)
%     figure('Visible','on','Name',name1)
%     plot(time,FT_true,time,T_plot,':')
%     legend({'T_z','\tau_x','\tau_y','\tau_z'},'Location','northwest','NumColumns',2)
% end
% 
load('indep_coef_whole')
figure('Visible','on','Name','indep_coef_whole')
plot(time,FT_true,time,T_plot,':')
legend({'T_z','\tau_x','\tau_y','\tau_z'},'Location','northwest','NumColumns',2)
% 
% load('combined_coef_whole')
% figure('Visible','on','Name','combined_coef_whole')
% plot(time,FT_true,time,T_plot,':')
% legend({'T_z','\tau_x','\tau_y','\tau_z'},'Location','northwest','NumColumns',2)
