function [pla_roi] = partition_placentavWL(pos_store,slice_n,uter_ID,pla_roi)


n_pla = 0;
%Need to 'complete' the placental mask since it is only a line
n_pla = n_pla+1;
c = 1;
for pos_n = [1 ,size(pos_store.slice(slice_n).object(2).roi.Position,1)]
    pos_tmp = pos_store.slice(slice_n).object(2).roi.Position(pos_n,:);
  
    uterus_pos_tmp = [pos_store.slice(slice_n).object(1).pos(:,1), pos_store.slice(slice_n).object(1).pos(:,2)];
    uterus_pos_tmp = unique(uterus_pos_tmp,'rows','stable');
    for uterus_roi_n = 1:size(uterus_pos_tmp,1)-1
        %So there's a problem that needs solving here; We have
        %the Uterus outline and the line that describes the
        %placenta and divides this mask in two... Where in the
        %list of uterus points does the placental mask lie? I
        %couldn't think of an easy/obvious method for this.
        %Since we know that the first and last placental ROI
        %points lie along the uterus mask, we need to find
        %where to insert them. To do this search every uterus
        %mask point to see if either the first or last
        %placental mask locations is imbetween it and its
        %neighbour. Do this by drawing a polygon around the
        %points and using inpolygon to see if the point lies
        %within.


        min_x = floor(min([uterus_pos_tmp(uterus_roi_n,1) uterus_pos_tmp(uterus_roi_n+1,1)]));
        max_x = ceil(max([uterus_pos_tmp(uterus_roi_n,1) uterus_pos_tmp(uterus_roi_n+1,1)]));
        min_y = floor(min([uterus_pos_tmp(uterus_roi_n,2) uterus_pos_tmp(uterus_roi_n+1,2)]));
        max_y = ceil(max([uterus_pos_tmp(uterus_roi_n,2) uterus_pos_tmp(uterus_roi_n+1,2)]));


        x_coords =[min_x min_x max_x max_x];
        y_coords = [min_y max_y max_y min_y];

        %Is the placental point between neighbouring points
        bool_check = inpolygon(pos_tmp(2),pos_tmp(1),x_coords,y_coords);
        if bool_check == 1
            pla_intersect(c) = uterus_roi_n+1;
            uterus_pos_tmp = [uterus_pos_tmp(1:pla_intersect(c),:);flip(pos_tmp);uterus_pos_tmp(pla_intersect(c)+1:end,:)];
            c = c+1;
            break
        end
    end
end


%Now I just need to determine which is the uterine wall and which is the
%placenta.... need to split the mask along the inserted points
pla_flip = 0;
%Put things in order
if pla_intersect(2)<pla_intersect(1)
    pla_intersect = fliplr(pla_intersect);
    pla_flip = 1;
end


no_wrap_tmp = uterus_pos_tmp(pla_intersect(1):pla_intersect(2)+1,:);
wrap_tmp = [flip(uterus_pos_tmp(1:pla_intersect(1),:));flip(uterus_pos_tmp(pla_intersect(2)+1:end,:))];

%Uter ID determines whether the longest line is uterus or placenta
%1 the longest line is the top of the placenta
%2 means the longest line is the uterus
no_wrap_l = sum(sqrt(sum((no_wrap_tmp(2:end)-no_wrap_tmp(1:end-1)).^2)));
wrap_l = sum(sqrt(sum((wrap_tmp(2:end)-wrap_tmp(1:end-1)).^2)));

pla_roi.slice(slice_n).pla = pos_store.slice(slice_n).object(2).roi.Position;
if uter_ID == 1
    if no_wrap_l>wrap_l
        pla_roi.slice(slice_n).pla_chor = no_wrap_tmp;
        pla_roi.slice(slice_n).uter = wrap_tmp;
    else
        pla_roi.slice(slice_n).pla_chor = wrap_tmp;
        pla_roi.slice(slice_n).uter = no_wrap_tmp;
    end
elseif uter_ID == 2
    if no_wrap_l<wrap_l
        pla_roi.slice(slice_n).pla_chor = no_wrap_tmp;
        pla_roi.slice(slice_n).uter = wrap_tmp;
    else
        pla_roi.slice(slice_n).pla_chor = wrap_tmp;
        pla_roi.slice(slice_n).uter = no_wrap_tmp;
    end
end


if pla_flip == 1
    pla_roi.slice(slice_n).pla_poly = [fliplr(pla_roi.slice(slice_n).pla);pla_roi.slice(slice_n).pla_chor]
    pla_roi.slice(slice_n).uter_poly = [fliplr(pla_roi.slice(slice_n).pla);pla_roi.slice(slice_n).uter]
else
    pla_roi.slice(slice_n).pla_poly = [flip(fliplr(pla_roi.slice(slice_n).pla));pla_roi.slice(slice_n).pla_chor]
    pla_roi.slice(slice_n).uter_poly = [flip(fliplr(pla_roi.slice(slice_n).pla));pla_roi.slice(slice_n).uter]
end










