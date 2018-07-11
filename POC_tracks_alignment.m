function POC_tracks_alignment
%Loads the file, then calls functions to process the raw data before signal
%analysis can occur
file = 'R2_2018_07_03_4Corners_2Indicators_Manual_2';
directory = string_form(file);
cd(directory)

[o1,o2,o3,o4,tp] = PX4_CSV_Plotter_V2(file);
[ffz,ftx,fty,ftz,t_sl] = ATI_AXIA80_LOG_Processor_V2(file);
[o2_init_1,ty_init_1,locs1,locs2] = find_peaks(o2,tp,fty,t_sl);

%Beginning of the signal analysis
s1=condition(o2_init_1);
s2=condition(ty_init_1);

%Setup of variables for use in looping for best resample and offset
lags=-350:350;
Nlags=length(lags);

%Empty matrix to contain correlation between data
scores=zeros(1,Nlags);

%Running data to find best correlation and the indexes for offset and lag
run_max = 0;
run_iLag = 0;

%Looping to find correlation at varying offsets and lags
FT_length = length(s2);
rotor_length = length(s1);
s1_resampled = resample(s1,FT_length,rotor_length);
for iLags=1:Nlags
    score = align_score(s1_resampled,s2,lags(iLags));
    scores(iLags)= score;
    if score > run_max
        run_max = score;
        run_iLag = iLags;
    end
end

%Processing the output of the looping
offset = surf_scores(scores,run_iLag,lags);
check_alignment(s1_resampled,s2,offset)
[a_fz,a_tx,a_ty,a_tz,a_o1,a_o2,a_o3,a_o4] = aligned_data(ffz,ftx,fty,ftz,o1,o2,o3,o4,offset,locs1,locs2);

%Conditions the aligned data and then plots both for a visual check
figure('Visible','on','Name','Aligned')
a_o2_p = condition(a_o2);
a_ty_p = condition(a_ty);
plot(a_o2_p)
hold on
plot(a_ty_p)
save([mfilename '_data_2018_07_03_4Corners_2Indicators_Manual_2'],'a_fz','a_tx','a_ty','a_tz','a_o1','a_o2','a_o3','a_o4')


function directory = string_form(file)
directory = sprintf('/home/kurt/ATI_Log_Processor/Test_Data/%s',file);
fprintf('\nloading: %s\n\n',directory')

%Both data sets are the same length. This crops the lagging data set to align the
%data, and then crops the end of the other to maintain # of points
function [a_fz,a_tx,a_ty,a_tz,out_o1,out_o2,out_o3,out_o4] = aligned_data(ffz,ftx,fty,ftz,o1,o2,o3,o4,offset,locs1,locs2)
FT_length = length(ffz);
rotor_length = length(o1);
so1 = resample(o1,FT_length,rotor_length);
so2 = resample(o2,FT_length,rotor_length);
so3 = resample(o3,FT_length,rotor_length);
so4 = resample(o4,FT_length,rotor_length);

if offset > 0
    a_fz = ffz((offset+1)+(locs2(3)+300):end);
    a_tx = ftx(offset+1+(locs2(3)+300):end);
    a_ty = fty(offset+1+(locs2(3)+300):end);
    a_tz = ftz(offset+1+(locs2(3)+300):end);
    a_o1 = so1(1+(locs2(3)+300):end);
    a_o2 = so2(1+(locs2(3)+300):end);
    a_o3 = so3(1+(locs2(3)+300):end);
    a_o4 = so4(1+(locs2(3)+300):end);
elseif offset < 0
    a_fz = ffz(1+(locs2(3)+300):end);
    a_tx = ftx(1+(locs2(3)+300):end);
    a_ty = fty(1+(locs2(3)+300):end);
    a_tz = ftz(1+(locs2(3)+300):end);
    a_o1 = so1((-offset+1)+(locs2(3)+300):end);
    a_o2 = so2((-offset+1)+(locs2(3)+300):end);
    a_o3 = so3((-offset+1)+(locs2(3)+300):end);
    a_o4 = so4((-offset+1)+(locs2(3)+300):end);
else
    a_fz = ffz((locs2(3)+300):end);
    a_tx = ftx((locs2(3)+300):end);
    a_ty = fty((locs2(3)+300):end);
    a_tz = ftz((locs2(3)+300):end);
    a_o1 = so1((locs2(3)+300):end);
    a_o2 = so2((locs2(3)+300):end);
    a_o3 = so3((locs2(3)+300):end);
    a_o4 = so4((locs2(3)+300):end);
end

[locs1,locs2] = end_peaks(a_o2,a_ty);

a_o1 = a_o1(1:locs1(end)+50);
a_o2 = a_o2(1:locs1(end)+50);
a_o3 = a_o3(1:locs1(end)+50);
a_o4 = a_o4(1:locs1(end)+50);
a_fz = a_fz(1:locs2(end)+50);
a_tx = a_tx(1:locs2(end)+50);
a_ty = a_ty(1:locs2(end)+50);
a_tz = a_tz(1:locs2(end)+50);

FT_length = length(a_fz);
rotor_length = length(a_o1);
out_o1 = resample(a_o1,FT_length,rotor_length);
out_o2 = resample(a_o2,FT_length,rotor_length);
out_o3 = resample(a_o3,FT_length,rotor_length);
out_o4 = resample(a_o4,FT_length,rotor_length);


        
%Pulls out the best offset and resample rate from the looping
function offset = surf_scores(scores,run_iLag,lags)
POC_plot = figure('Visible','on','Name','FT & PX4 Offset');
plot(scores)
offset = lags(run_iLag);
offset_ind = run_iLag;
fprintf('Offset(index): %f - Offset: %f\n',offset_ind,offset)

%Plots aligned data to visually check alignment
function check_alignment(s1,s2,offset)
figure('Visible','on','Name','Alignment')
[s1_max, s2_max] = lag_signals(s1,s2,offset);
plot(s1_max)
hold on
plot(s2_max)
hold off

%Isolates the manual bumps for use in alignment
function [o2_init,ty_init,locs1,locs2] = find_peaks(s1,t1,s2,t2)
figure('Visible','on','Name','Peaks')

tab_s1 = uitab('Title','Actuator Output 1');
ax_s1 = axes(tab_s1);
plot(ax_s1,t1,s1)
hold on
[pks1,locs1] = findpeaks(s1,'MinPeakHeight',1350,'MinPeakDistance',8);
plot(ax_s1,t1(locs1),pks1,'ko')

tab_s2 = uitab('Title','Filtered Force Y');
ax_s2 = axes(tab_s2);
plot(ax_s2,t2,s2)
hold on
[pks2,locs2] = findpeaks(s2,'MinPeakHeight',.06,'MinPeakDistance',90);
plot(ax_s2,t2(locs2),pks2,'ko')

o2_init = s1(1:(locs1(3)+20));
ty_init = s2(1:(locs2(3)+200));

function [locs1,locs2] = end_peaks(s1,s2)
figure('Visible','on','Name','End Peaks')

tab_s1 = uitab('Title','Actuator Output 2');
ax_s1 = axes(tab_s1);
t1 = 1:length(s1);
plot(ax_s1,t1,s1)
hold on
[pks1,locs1] = findpeaks(s1,'MinPeakHeight',1600,'MinPeakDistance',8);
plot(ax_s1,t1(locs1),pks1,'ko')

tab_s2 = uitab('Title','Filtered Force Y');
ax_s2 = axes(tab_s2);
t2 = 1:length(s2);
plot(ax_s2,t2,s2)
hold on
[pks2,locs2] = findpeaks(s2,'MinPeakHeight',.35,'MinPeakDistance',90);
plot(ax_s2,t2(locs2),pks2,'ko')


%Calls align score and condition
function score=align_score(s1_resampled,s2,lag)
[s1_lag,s2_lag] = lag_signals(s1_resampled,s2,lag);

score=correlation(s1_lag,s2_lag);

%Conditions the data to a 0 though 1 scale
function s_conditioned=condition(s)
s=shiftdim(s);
sMax=max(s);
sMin=min(s);
s_conditioned=(s-sMin)/(sMax-sMin);

%Crops the data set to the specified lag
function [s1_lag,s2_lag]=lag_signals(s1,s2,lag)
if lag>0
    s1_lag=s1;
    s2_lag=s2(lag+1:end);
elseif lag<0
    s1_lag=s1(-lag+1:end);
    s2_lag=s2;
else
    s1_lag=s1;
    s2_lag=s2;
end

%Finds the correlation between the data sets
function c=correlation(s1,s2)
N=min(length(s1),length(s2));
c=sum(s1(1:N).*s2(1:N));

