function Image_Overlay_Test()

load('Single_Frame1.mat')
frame1 = frame;
load('Single_Frame6.mat')

% Display the two images
figure('Name','Idle');
image(frame1.cdata);%,frame1.colormap)
colormap(gray(2));

figure('Name','Max Throttle');
image(frame6.cdata);%,figure6.colormap)
colormap(gray(2));


% Get the size of the image and loop through
[r,c] = size(frame1.cdata);
overlay = frame1;
% Check if the max throttle frame has any deviations from idle and then
% overwrite the image
for i = 1:r
    for j = 1:c
        if (overlay.cdata(i,j) == 0) && (frame6.cdata(i,j) == 1)
            overlay.cdata(i,j) = 0;
        end
    end
end

figure('Name','Overlay');
image(overlay.cdata);%,figure6.colormap)
colormap(gray(2));

end