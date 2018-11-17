function frames = Quad_Video_Reader(varargin)
if nargin == 0
    play_video = 1;
else
    play_video = 0;
end

filename = 'QuadVideo_Cannon_0-50Throttle.MOV';

vidObj = VideoReader(filename);
vidHeight = vidObj.Height;
vidWidth = vidObj.Width;

frames = struct('cdata',zeros(vidHeight,vidWidth,3,'uint8'),...
    'colormap',colormap(gray(2)));
%bw = colormap(gray(2));

k = 1;
i = 1;
while hasFrame(vidObj)
    if i>0%~mod(k,4)
        frames(i).cdata = uint8(rgb2gray(readFrame(vidObj)) > 150);
        frames(i).colormap = colormap(gray(2));
        i = i+1;
    end
    k = k+1;
end

save_frames = 0;
if save_frames
    times_of_interest = [.5,16];
    saveframes(times_of_interest)
end


if play_video
    imshow(frames(550).cdata)%,frames(550).colormap,'Border','Tight','InitialMagnification','fit'); hold on;
    
    %%% PLAY VIDEO BACK
    set(gcf,'position',[150 150 vidObj.Width vidObj.Height]);
    set(gca,'units','pixels');
    set(gca,'position',[0 0 vidObj.Width vidObj.Height]);
    movie(frames,1,vidObj.FrameRate);
end

function saveframes(times_of_interest)
%%% SAVE FRAMES AT SPECIFIC TIMES
fps = 30; %TODO: this value can be dynamic from the video reader
time_per_frame = 1/fps;

frame_at_time = zeros(1,length(times_of_interest));
for i = 1:length(times_of_interest)
    frame_at_time(i) = ceil(times_of_interest(i)/time_per_frame);
end


frames_of_interest = struct('cdata',zeros(vidHeight,vidWidth,3,'uint8'),...
    'colormap',[]);

for j = 1:length(times_of_interest)
    frames_of_interest(j) = frames(frame_at_time(j));
end

save('Frames_of_Interest.mat','frames_of_interest')