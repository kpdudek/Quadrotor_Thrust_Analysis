function Quad_Video_SingleFrameAnalysis
load('Single_Frame1.mat')

% Get the size of the image to be used in the for loop
[vidHeight,vidWidth,] = size(frame.cdata);

% Take the first image from frames of interest, and convert to grayscale,
% then binary
% image_gry = rgb2gray(frames_of_interest(1).cdata);
% image_bin = image_gry > 125;

% Loop over the image, starting from the top, in order to find the tip of
% the prop adapter
prop_x = [];
prop_y = [];
image = frame.cdata;
color_map = frame.colormap;

flag = 0; % Flag to break out of the nested loop
for y = 1:vidHeight
    for x = 1:vidWidth
        if image(y,x) == 0 % Threshold to indicate top of black prop adapter vs the white background
            prop_x = x;
            prop_y = y;
            flag = 1;
            break
        end
    end
    if flag == 1
        break
    end
end

%%% Set up a figure window and display the selected frame with 
figure

image(1:prop_y,prop_x-2:prop_x+2) = 0; % Draw a line from top of image to the top of the prop adapter
image(325-2:325+2,20:176) = 1; % Draw the dimension of the motor

% Display the grayscale image with the overlays 
imshow(image,color_map,'Border','Tight','InitialMagnification','fit'); hold on;


%%% Convert distances in pixels to inches
if fopen('Motor_Pixel.mat') == -1
    motor_pix = (176-20); % This needs to be measured for every test
    save('Motor_Pixel.mat','motor_pix')
else
    load('Motor_Pixel.mat')
end
motor_in = 1.01; % This never changes

get_length(motor_pix,motor_in,prop_y,'Distance to prop adapter, state 1,');



function inches = get_length(motor_pixel,motor_inch,distance,name)
px_in = motor_pixel/motor_inch;

inches = distance/px_in;

fprintf('%s in inches: %.2f\n',name,inches)