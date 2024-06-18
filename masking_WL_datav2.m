%Code for masking the WL challenge data from manchester; we need to split
%the uterine wall from the placental mask.

%I would prefer this code or the accompanying functions are not shared
%without permission, which I will reasonably give.


%This code is thrown together from a few projects that already exist; so
%I'm sorry if it's a bit of a mess but I tried to be quick.


%====Requirements=====
%Matlab 2016b or later (may work on earlier)
%Image processing toolbox

%THis code allows you to split the uterine wall mask from the placental
%mask on the WL hackathon diffusion data. Below there are a few directories
%you need to set up; I have left the default structure of the hackathon
%data so just point to the 'train' folder and also pick a directory to save
%masks to. This will also be where the code looks for masks you have
%already done to load them

%Soon I will add mask generation and splitting into maternal/fetal sides
%but that should be easier than this bit!!


clc
clear all
clf
close all

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% set up %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Directory of code and functions
addpath('C:\placental\Wl\Code')
%Directory of all the daphne files, I've left this in the format it comes
%off globus in
daphne_dir = 'C:\placental\Wl\MRI Data (Manchester Team)\train';
%Id number of participant you wish to mask
daphne_mask_id = 16;
%Directory to save/load data to
save_dir = '../split_masks';
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
mkdir(save_dir)
daphne_folder = dir(daphne_dir);
cd(daphne_dir);

c = 1;

%A bit of an ugly loop to get filenames to get all the IDs... Probably a
%better way to do this
for n = 1:size(daphne_folder,1);
    try
        fname_tmp = strcmp(daphne_folder(n).name(1:6),'DAPHNE');
        if fname_tmp == 1;
            daphne_fnames{c} = daphne_folder(n).name;
            daphne_id(c) = str2num(daphne_folder(n).name(8:9));
            c = c+1;
        end
    end
end
daphne_id = unique(daphne_id);

%% Set up GUI for masking

figure
%Make UI control options
id_n = uicontrol(figure(1),'Style','Text','units','normalized','Position',[0.0521 0.0463 0.0703 0.0278],'String','X');

%Slider for maps
map_display = uicontrol(figure(1),'Style','Text','units','normalized','Position',[0.321 0.0463 0.0703 0.0278],'String','X');
map_slider = uicontrol(figure(1),'Style','Slider','units','normalized','min',1,'max',4,'Value',1,'Position', [0.3121 0.0185 0.0625 0.0278],'SliderStep',[1/3 1/3]);
%Buttons for functionality
toggle_placenta_side = uicontrol('Style','togglebutton','min',0,'max',1,'Value',0,'units','normalized','Position',[0.48 0.019 0.07 0.03],'String','Toggle pla');
draw_button = uicontrol('Style','togglebutton','min',0,'max',1,'Value',0,'units','normalized','Position',[0.48 0.0463 0.07 0.03],'String','Add obj');
close_and_gen = uicontrol('Style','togglebutton','min',0,'max',1,'Value',0,'units','normalized','Position',[0.55 0.0185 0.14 0.06],'String','Close and generate masks');

%Things we need to check during the code
daphne_id_prev = 0;
slice_prev = 100;
map_prev = 100;
show_masks = 1;
uter_id_current = 1;
redraw_roi = 0;

%daphne ID and set string to write name on GUI
daphne_id_current = find(daphne_id==daphne_mask_id);
set(id_n,'String',['DAPHNE-',num2str(daphne_mask_id)]);

while close_and_gen.Value == 0

    %If its a new participant; load the data + masks+ set up sliders; this
    %is lifted from another GUI so it doesn't need to be inside the loop...
    %just quicker to do it this way
    if daphne_id_current ~= daphne_id_prev;
        visit_n = dir([daphne_dir,'\DAPHNE-',num2str(daphne_mask_id),'*']);
        visit_popupmenu  = uicontrol(figure(1),'Style','popupmenu','units','normalized','Position', [0.1302 0.0185 0.0625 0.0278]);
        visit_popup_string = {};
        for visit_c = 1:length(visit_n)
            visit_popup_string{visit_c} = visit_n(visit_c).name;
        end

        visit_popupmenu.String = visit_popup_string;
        scan_n_previous = 0;
        daphne_id_prev = daphne_id_current;
    end

    scan_n_current = ceil(visit_popupmenu.Value);


    %If you change the scan using the drop down menu
    if scan_n_current ~= scan_n_previous
        %Try to save pos_store and pla_roi for making masks
        %Will only ever equal zero on the first iteration of this loop,
        %which is the only time we will want to skip this
        if scan_n_previous~=0 
            save([save_dir,'/',visit_n(scan_n_previous).name,'_mask_file.mat'],'pla_roi','pos_store');
        end

        %Try and load previous mask (if it exists)
        try
            load([save_dir,'/',visit_n(scan_n_current).name,'_mask_file.mat']);
        catch
            warning('No previous mask found')
            pos_store = [];
            pla_roi = [];
        end


        %Load all of the scans
        daphne_string = visit_n(scan_n_current).name;
        %Load all ball_ball data
        aniso_fnames = dir([visit_n(1).folder,'\',daphne_string,'\tensor_maps\*.nii.gz']);
        mask = double(niftiread([visit_n(1).folder,'\',daphne_string,'/tensor_maps/',aniso_fnames(1).name]));
        aD = double(niftiread([visit_n(1).folder,'\',daphne_string,'/tensor_maps/',aniso_fnames(2).name]));
        aDc = double(niftiread([visit_n(1).folder,'\',daphne_string,'/tensor_maps/',aniso_fnames(3).name]));
        fa = double(niftiread([visit_n(1).folder,'\',daphne_string,'/tensor_maps/',aniso_fnames(4).name]));
        rd = double(niftiread([visit_n(1).folder,'\',daphne_string,'/tensor_maps/',aniso_fnames(5).name]));

        %Generate mask outline from mask:
        %Mask outline is an image array
        %mask_outline_points are the points
        mask_outline = zeros(size(mask));
        mask_outline_points = {};
        %Save mask size for the output file
        pla_roi.masksize = size(mask);


        %For every slice
        for slice_iter = 1:size(mask,3)
            %Find the boundary of the original mask
            mask_outline_points{slice_iter} = bwboundaries(mask(:,:,slice_iter));

            %If there is mask in the slice
            if length(mask_outline_points{slice_iter})>0
                %Find the indicies of the outline
                outline_ind = sub2ind(size(mask_outline(:,:,slice_iter)),mask_outline_points{slice_iter}{1}(:,2),mask_outline_points{slice_iter}{1}(:,1));
                %Make a temporary array to store the outline image
                mask_outline_slice = zeros(size(mask_outline,[1,2]));
                %Make the outline = 1
                mask_outline_slice(outline_ind) = 1;
                %Put into full array
                mask_outline(:,:,slice_iter) = mask_outline_slice;

                %Sorry this code is a bit of a Frankensteins monster...
                %just pulling some old code apart so these double
                %variables/ some other things might seem odd
                pos_store(1).slice(slice_iter).object(1).pos = mask_outline_points{slice_iter}{1};
            end
        end
        %Update the previous scan number so we don't load this loop again
        %until we have to
        scan_n_previous = scan_n_current;

        %Now make a slice slider, also resets to the first slice
        slice_display = uicontrol(figure(1),'Style','Text','units','normalized','Position',[0.2121 0.0463 0.0703 0.0278],'String','1');
        slice_slider = uicontrol(figure(1),'Style','Slider','units','normalized','min',1,'max',size(aD,3),'Value',1,'Position', [0.2121 0.0185 0.0625 0.0278],'SliderStep',[1/size(aD,3) 1/size(aD,3)]);
        map_prev = 100;

    end
    %Get current slice and maps from the sliders
    slice_n = ceil(slice_slider.Value);
    map_current = ceil(map_slider.Value);

    %If we change the map or slice we need to save the ROI + redraw on new
    %slice so check for this
    if slice_prev ~= slice_n || map_current ~= map_prev
        redraw_roi = 1;
        try
            pos_store.slice(slice_prev).object(2).pos = pos_store.slice(slice_prev).object(2).roi.Position;
        end
    end

    %If the slice has changed set the string on the slider; update
    %slice_previous and reset the map
    if slice_prev ~= slice_n
        set(slice_display,'String',num2str(slice_n))
        slice_prev = slice_n;
        map_prev = 100;
    end

    %Display the image depending on the map you select
    if map_current ~= map_prev
        switch map_current
            case 1
                imagesc(aD(:,:,slice_n).*mask(:,:,slice_n))
                set(map_display,'String','D')
            case 2
                imagesc(aDc(:,:,slice_n).*mask(:,:,slice_n))
                set(map_display,'String','ADC')
                caxis([0 10*1e-3])
            case 3
                imagesc(fa(:,:,slice_n).*mask(:,:,slice_n))
                set(map_display,'String','FA')
                caxis([0 1])
            case 4
                imagesc(rd(:,:,slice_n).*mask(:,:,slice_n))
                set(map_display,'String','rd')
        end
        hold on

        %Plot the outline of the original mask
        if size(mask_outline_points{slice_n},1) ~= 0
            plot(mask_outline_points{slice_n}{1}(:,2),mask_outline_points{slice_n}{1}(:,1),'k','linewidth',1)
        end

        map_prev = map_current;
    end

    %Move the green line (which IDs the maternal side of the placenta) over
    %to the other side
    if toggle_placenta_side.Value == 1
        switch uter_id_current
            %Update the ID so it remembers the side you previously chose
            case 1
                uter_id_current = 2;
            case 2
                uter_id_current = 1;
        end
        %Delete previous green line
        delete(h(1));
        %Update this in pla_roi
        pos_store = snap_pla_to_uterWL(pos_store,slice_n);
        [pla_roi] = partition_placentavWL(pos_store,slice_n,uter_id_current,pla_roi);
        %reset the button
        toggle_placenta_side.Value = 0;
    end
    

    if draw_button.Value == 1 %If draw button is pressed then add an object to the current ROI
        try
            delete(pos_store(1).slice(slice_n).object(2).roi)
        end
        pos_store(1).slice(slice_n).object(2).roi = drawpolyline();
        pos_store(1).slice(slice_n).object(2).pos = pos_store(1).slice(slice_n).object(2).roi.Position; %Update ROI with new ROI

        pos_store = snap_pla_to_uterWL(pos_store,slice_n);

        pla_roi.slice(slice_n).uter_ID = uter_id_current;
        [pla_roi] = partition_placentavWL(pos_store,slice_n,uter_id_current,pla_roi);
        
        draw_button.Value = 0;
    end

    if redraw_roi == 1
        redraw_roi = 0;
        try
            pos_store.slice(slice_n).object(2).roi = drawpolyline('Position',pos_store.slice(slice_n).object(2).pos);
        end
    end

    %Highlight uterine edge in green
    try
        hold on
        if exist('h')
            delete(h)
        end
        h =  plot(pla_roi.slice(slice_n).uter(:,2),pla_roi.slice(slice_n).uter(:,1),'g','linewidth',4);
    catch
        %If this loop runs it is because there is no placenta here yet
    end


    hold off
    drawnow
    pause(0.1)
end


%Save the last mask that was being worked on, if it had something in it
if size(pos_store,1)>0
    save([save_dir,'/',visit_n(scan_n_previous).name,'_mask_file.mat'],'pla_roi','pos_store');
end


close all

%Now generate/regenerate the masks

%Look for mask files from this participant
mask_files = dir([save_dir,'\*',num2str(daphne_mask_id),'*_mask_file.mat']);

for mask_n = 1:length(mask_files)
    load([mask_files(mask_n).folder,'\',mask_files(mask_n).name])

    wall_mask = zeros(pla_roi.masksize);
    pla_mask = zeros(pla_roi.masksize);


    for slice_n = 1:pla_roi.masksize(3)
        try
            if size(pla_roi.slice(slice_n).uter_poly,1)>0
                wall_mask(:,:,slice_n) = poly2mask(pla_roi.slice(slice_n).uter_poly(:,2),pla_roi.slice(slice_n).uter_poly(:,1),pla_roi.masksize(1),pla_roi.masksize(2));
                pla_mask(:,:,slice_n) = poly2mask(pla_roi.slice(slice_n).pla_poly(:,2),pla_roi.slice(slice_n).pla_poly(:,1),pla_roi.masksize(1),pla_roi.masksize(2));
            end
        catch
        end
    end

    niftiwrite(pla_mask,[mask_files(mask_n).folder,'\',mask_files(mask_n).name(1:end-14),'_pla_mask'])
    niftiwrite(wall_mask,[mask_files(mask_n).folder,'\',mask_files(mask_n).name(1:end-14),'_wall_mask']);

end













