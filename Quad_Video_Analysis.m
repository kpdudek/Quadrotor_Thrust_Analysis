function deflections = Quad_Video_Analysis
% File name prefix
name = 'R2_Untethered_20190212_Throttle';

% Number of videos in the directory
% --> This value is appended to the file name
num_vids = 7;

% Diameter of the motor measured for the set of videos
motor_pixel = 169-39; % For R2_Untethered_20190212

% Rough RPM values based on tachometer data from past testing
rpm = linspace(8000,16000,num_vids);


% Struct initialization to store the video data
data = struct('raw',[],'filt',[]);
coord = struct('x',data,'y',data);
deflections = struct('Test','','RPMs',[],'Prop_Tip',coord,'Prop_Adap',[]);

% Loop through all videos in the directory
for i = 1:num_vids
    file = sprintf('%s%d.mov',name,i);
    fprintf('\nLoading video %d...\n',i)
    % Load the video
    frames = Quad_Video_Reader(file,'No Display');
    fprintf('Video %d loaded...\n',i)
    
    close all
    
    [prop_tip_x,prop_tip_y,prop_adap_x,prop_adap_y] = get_coordinates(frames,motor_pixel);
    
    % Store data into struct
    deflections(i).Test = sprintf('Throttle%d',i);
    deflections(i).RPMs = rpm(i);
    deflections(i).Prop_Tip.x.raw = prop_tip_x;
    deflections(i).Prop_Tip.y.raw = prop_tip_y;
    deflections(i).Prop_Adap.x.raw = prop_adap_x;
    deflections(i).Prop_Adap.y.raw = prop_adap_y;
    
    deflections(i).Prop_Tip.x.filt = filter_data(prop_tip_x);
    deflections(i).Prop_Tip.y.filt = filter_data(prop_tip_y);
    deflections(i).Prop_Adap.x.filt = filter_data(prop_adap_x);
    deflections(i).Prop_Adap.y.filt = filter_data(prop_adap_y);
    
    % Done
    fprintf('Done...\n')
    
end


figure('Name','Deflections Plot')
colmap = jet(7);
for iseq=1:7
    plot(deflections(iseq).Prop_Tip.x.raw,deflections(iseq).Prop_Tip.y.raw,'x','color',colmap(iseq,:));
    hold on; 
end; hold off
xlabel('X-Position (pix)') % From right edge of screen
ylabel('Y-Position (pix)') % From left edge of screen
title('Position of Prop Tip')

lgnd = {};
for i = 1:length(deflections)
    lgnd{end+1} = sprintf('RPM: %.1f',deflections(i).RPMs);
end
legend(lgnd)

% TODO: add in the actuator output plot converted to RPM, and plot against
% displacemement
end


% Function that takes in a video structure from Quad_Video_Reader() and
% finds the coordinates of the prop adapter and propeller tip
function [prop_tip_x,prop_tip_y,prop_adap_x,prop_adap_y] = get_coordinates(frames,motor_pixel)

% Get the size of the image to be used in the for loop
[vidHeight,vidWidth] = size(frames(1).cdata);

%%% Prop Adapter
% Loop over the image, starting from the top, in order to find the tip of
% the prop adapter
prop_adap_x = [];
prop_adap_y = [];

for f = 1:length(frames)
    frame = frames(f).cdata;
    flag = 0; % Flag to break out of the nested loop
    for y = 25:80
        for x = 45:140
            if frame(y,x) == 0 % Threshold to indicate top of black prop adapter vs the white background
                prop_adap_x(end+1) = x;
                prop_adap_y(end+1) = y;
                %fprintf('Found peak %d | Breaking...\n',f)
                flag = 1;
                break
            end
        end
        if flag == 1
            break
        end
    end
end
% invert the data so delta_y is positive and convert pixels to inches
%prop_adap_y = get_length(abs(prop_adap_y-max(prop_adap_y)),motor_pixel);
%prop_adap_x = get_length(abs(prop_adap_x-max(prop_adap_x)),motor_pixel);



%%% Prop tip
% Loop over the image, starting from the right, in order to find the tip of
% the propeller
prop_tip_x = [];
prop_tip_y = [];

for f = 1:length(frames)
    frame = frames(f).cdata;
    flag = 0; % Flag to break out of the nested loop
    for x = vidWidth:-1:100 %500
        for y = 100:185
            if frame(y,x) == 0 % Threshold to indicate top of black prop adapter vs the white background
                prop_tip_x(end+1) = x;
                prop_tip_y(end+1) = y;
                %fprintf('Found peak %d | Breaking...\n',f)
                flag = 1;
                break
            end
        end
        if flag == 1
            break
        end
    end
end
% invert the data so delta_y is positive and convert pixels to inches
%prop_tip_y = get_length(abs(prop_tip_y-max(prop_tip_y)),motor_pixel);
%prop_tip_x = get_length(abs(prop_tip_x-max(prop_tip_x)),motor_pixel);

end

% Function that applies a sliding window filter to the dataset passed to it
function out = filter_data(data)
l = length(data);
w = 6;
half = w/2;

filt = [];
for i = half+1:(l-w/2)
    ave = mean(data(i-half):data(i+half));
    filt(end+1) = ave;
end
out = filt;
end

% Function to convert distance in pixels to distance in inches
% The relationship between the motors measured diameter and equivilent
% value in pixels is used for the conversion factor
function inches = get_length(distance, motor_pix)
motor_in = 1.01; % This never changes
motor_pixel = motor_pix; % Meaure for the set of videos you're working with

px_in = motor_pixel/motor_in;
inches = distance/px_in;
end




