clc
clear
addpath('C:\Placental\Functions')

cd 'C:\placental\Wl\MRI Data (Manchester Team)\train'

tmp = dir;

subj_id = 'DAPHNE-36';


ball_ball_fnames = dir(['C:\placental\Wl\MRI Data (Manchester Team)\train\',subj_id,'\ballball_maps\*.gz']);
ball_ball.mask = niftiread([ball_ball_fnames(1).folder,'\',ball_ball_fnames(1).name]);

tensor_fnames = dir(['C:\placental\Wl\MRI Data (Manchester Team)\train\',subj_id,'\tensor_maps\*.gz']); 
tensor.ADC = niftiread([tensor_fnames(3).folder,'\',tensor_fnames(3).name]);


for slice_n = 1:size(ball_ball.mask,3)
    subplot(3,3,slice_n)

    corners = detectHarrisFeatures(ball_ball.mask(:,:,slice_n));
    corners = corners.selectStrongest(2).Location;

    imagesc(ball_ball.mask(:,:,slice_n))
    set(gca,'Ydir','normal')
    hold on
    plot(corners(:,1),corners(:,2),'rx')

end















