function Image_Overlay_Test()

load('frame_idle.mat')
%frame1 = frame;
load('frame_max.mat')

% Display the two images
figure('Name','Idle');
image(frame_idle.cdata);%,frame1.colormap)
colormap(gray(2));

figure('Name','Max Throttle');
image(frame_max.cdata);%,figure6.colormap)
colormap(gray(2));


% % Get the size of the image and loop through
% [r,c] = size(frame1.cdata);
% overlay = frame1;
% % Check if the max throttle frame has any deviations from idle and then
% % overwrite the image
% for i = 1:r
%     for j = 1:c
%         if (overlay.cdata(i,j) == 1) && (frame6.cdata(i,j) == 0)
%             overlay.cdata(i,j) = 0;
%         end
%     end
% end

figure('Name','Overlay');
img = cat(3,frame_idle.cdata,frame_max.cdata,uint8(zeros(size(frame_idle.cdata))))*255;
imshow(img*255)

end

