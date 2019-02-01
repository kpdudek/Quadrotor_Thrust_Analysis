function frames = Quad_Video_Reader(filename,varargin)
% This function reads the video file passed and outputs a struct of binary
% images where the prop/motor are black and the surroundings are white
if nargin == 1
    play_video = 1;
else
    play_video = 0;
end

% error check to see if the video file is in the current directory
file_dir = dir(filename);
return_size = size(file_dir);
if return_size(1) == 0
    error('Navigate to the files directory first')
end


% Set up the video reader object and pass the video file to it
% The height and width of the video is read from the object and used to
%   initialize a struct to store the frames
vidObj = VideoReader(filename);
vidHeight = vidObj.Height;
vidWidth = vidObj.Width;
frames = struct('cdata',zeros(vidHeight,vidWidth,3,'uint8'),...
    'colormap',colormap(gray(2)));
%bw = colormap(gray(2));

% Loop through the frames and store into the struct
k = 1;
i = 1;
while hasFrame(vidObj)
    if i>0
        % Convert to a grayscale image, and then threshold to create a
        % binary image. Must be converted to type uint8
        frames(i).cdata = uint8(rgb2gray(readFrame(vidObj)) > 32);
        frames(i).colormap = colormap(gray(2));
        i = i+1;
    end
    k = k+1;
end

% Specify whether or not certain frames should be saved into a new struct.
% This serves to reduce the size of the .mat file 
save_frames = 0;
if save_frames
    times_of_interest = [.5,16];
    saveframes(times_of_interest)
end


% Unless a second argument was passed to the function, open a figure window
%   and play the video
if play_video
    imshow(frames(550).cdata,frames(550).colormap)%,'Border','Tight','InitialMagnification','fit'); hold on;
    
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