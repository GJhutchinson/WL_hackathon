function [pos_store] = snap_pla_to_uterWL(pos_store,slice_n)

%Approximate the Uterus mask to a line ROI;
%Two hacks here; First you cannot edit the type of ROI
%something is, these values are set to read only by MATLAB. For the Uterus mask I 
%just want the exterior voxels. To get around this, load up a polyline ROI 
%(i.e. the first placental boundary) then change the position to be the 
%coordniates of the uterus mask. 
%2nd Hack, as this is a polyline it will leave it open (i.e. not connect 
%the first and last points) so start and end with the same set of points, 
%so it will connect everything together. 
uter_tmp = drawpolyline('position',[pos_store.slice(slice_n).object(1).pos(:,2),pos_store.slice(slice_n).object(1).pos(:,1)]);
uter_approx = createMask(uter_tmp);
%Then create a mask, this is a 1-voxel wide mask around the edge of the
%uterus. By doing so we can take the x+y coordinated of the exterior of the
%uterus, and find the closest point to the end of the placental mask, and
%snap the placental mask to this point. They don't perfectly line up, but
%it is within 1 voxel, and when converted to a mask will not be noticeable.
%In theory it would be best to find the nearest point on the line between
%the points n and n+1 but I imagine that would be very computationally
%expensive.
[ind] = find(uter_approx>0);
[y,x] = ind2sub(size(uter_approx),ind);
delete(uter_tmp)
for pos_n = [1 ,size(pos_store.slice(slice_n).object(2).roi.Position,1)]
    pos_tmp = pos_store.slice(slice_n).object(2).roi.Position(pos_n,:);
    pos_diff = sqrt(sum(([x,y] - pos_tmp).^2,2));
    [~,snap_pos] = min(pos_diff);
    pos_store.slice(slice_n).object(2).roi.Position(pos_n,:) = [x(snap_pos),y(snap_pos)];
    pos_store.slice(slice_n).object(2).pos(pos_n,:)= [x(snap_pos),y(snap_pos)];
end


end