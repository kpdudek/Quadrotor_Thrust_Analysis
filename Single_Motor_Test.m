function Single_Motor_Test
file = 'Single_Motor_Test_WithFT_20180711';

[o1,o2,o3,o4,tp] = PX4_CSV_Plotter_V2(file);
[ffz,ftx,fty,ftz,t_sl] = ATI_AXIA80_LOG_Processor_V2(file);



