function Plots_For_Paper

load('POC_tracks_alignment_data_2018_07_13_4Corners_2Indicators_Acro.mat')
load('POCidentification_all_coefs_data_2018_07_13_4Corners_2Indicators_Acro.mat')
load('POCidentification_test_span_data_2018_07_13_4Corners_2Indicators_Acro.mat')

file = 'R2_2018_07_13_4Corners_2Indicators_Acro';

directory = string_form(file);
cd(directory)

[o1,o2,o3,o4,tp] = PX4_CSV_Plotter_V2(file);
[ffz,ftx,fty,ftz,t_sl] = ATI_AXIA80_LOG_Processor_V2(file);

figure('Visible','on')
plot(o2)

figure('Visible','on')
plot(fty)

figure('Visible','on')

figure('Visible','on')

figure('Visible','on')

figure('Visible','on')

figure('Visible','on')

figure('Visible','on')

figure('Visible','on')

figure('Visible','on')

figure('Visible','on')

figure('Visible','on')

figure('Visible','on')

figure('Visible','on')