function Image_Overlay_Test()
% Load the struct with freeze frames from each rpm during the test
load('frames.mat')

% Get the size of the image to be used in the for loop
[vidHeight,vidWidth] = size(frames(1).cdata);


%%% Display the two images
% Idle
figure('Name','Idle');
imshow(frames(1).cdata,frames(1).colormap)

% Max throttle
figure('Name','Max Throttle');
imshow(frames(end).cdata,frames(1).colormap)

% Overlay the two images
figure('Name','Overlay');
img = cat(3,frames(1).cdata,frames(end).cdata,uint8(zeros(size(frames(1).cdata))))*255;
imshow(img*255)


%%%  ---  Plot tip delfection with increasing RPM  ---  %%%
rpm = linspace(8000,16000,length(frames));

%%% Prop Adapter
% Loop over the image, starting from the top, in order to find the tip of
% the prop adapter
prop_adap_x = [];
prop_adap_y = [];

for f = 1:length(frames)
    frame = frames(f).cdata;
    flag = 0; % Flag to break out of the nested loop
    for y = 1:vidHeight
        for x = 1:vidWidth
            if frame(y,x) == 0 % Threshold to indicate top of black prop adapter vs the white background
                prop_adap_x(end+1) = x;
                prop_adap_y(end+1) = y;
                fprintf('Found peak %d | Breaking...\n',f)
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
prop_adap = get_length(abs(prop_adap_y-max(prop_adap_y)));
figure('Name','Prop Adapter Displacement')
plot(rpm,prop_adap,'o-')
title('Prop Adapter Position')
xlabel('Rough RPM')
ylabel('Prop Adapter Position (in.)')



%%% Prop tip
% Loop over the image, starting from the right, in order to find the tip of
% the propeller
prop_tip_x = [];
prop_tip_y = [];

for f = 1:length(frames)
    frame = frames(f).cdata;
    flag = 0; % Flag to break out of the nested loop
    for x = vidWidth:-1:1
        for y = 1:vidHeight-5
            if frame(y,x) == 0 % Threshold to indicate top of black prop adapter vs the white background
                prop_tip_x(end+1) = x;
                prop_tip_y(end+1) = y;
                fprintf('Found peak %d | Breaking...\n',f)
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
prop_tip = get_length(abs(prop_tip_y-max(prop_tip_y)));
figure('Name','Prop Tip Displacement')
plot(rpm,prop_tip,'*-')
title('Prop Tip Position')
xlabel('Rough RPM')
ylabel('Prop Tip Position (in.)')

end


function inches = get_length(distance)
motor_in = 1.01; % This never changes
motor_pixel = 169-39;

px_in = motor_pixel/motor_in;
inches = distance/px_in;
end
















