function Quad_Video_Analysis
fprintf('Loading video...\n')
frames = Quad_Video_Reader('Dont display video');
fprintf('Video loaded...\n\n')

% Get the size of the image to be used in the for loop
[vidHeight,vidWidth,depth] = size(frames(1).cdata);

% Loop over the image, starting from the top, in order to find the tip of
% the prop adapter
prop_x = [];
prop_y = [];

for f = 1:length(frames)
    % Take the first image from frames of interest, and convert to grayscale,
    % then binary
%     image_gry = rgb2gray(frames(f).cdata);
%     image_bin = image_gry > 125;
    image = frames(f).cdata;
    flag = 0; % Flag to break out of the nested loop
    for y = 1:vidHeight
        for x = 1:vidWidth
            if image(y,x) == 0 % Threshold to indicate top of black prop adapter vs the white background
                prop_x(end+1) = x;
                prop_y(end+1) = y;
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
fprintf('Done...\n')



function inches = get_length(motor_pixel,motor_inch,distance,name)
px_in = motor_pixel/motor_inch;

inches = distance/px_in;

fprintf('%s in inches: %.2f\n',name,inches)





