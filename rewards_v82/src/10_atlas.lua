-- Stars use packed rectangles so the map's shared sprite rows stay empty.
function victory_star(j,x,y,age,full)
 local frame=full and min(9,age+1) or 0
 local i=((j==2 and 10 or 0)+frame)*6+1
 local sx,sy,w,h,ox,oy=unpack(star_atlas,i,i+5)
 sspr(sx,sy,w,h,x+ox,y+oy)
end
