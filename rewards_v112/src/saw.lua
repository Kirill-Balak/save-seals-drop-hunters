function action_saw(x,y)
 draw_saw(x,y,angle)
end

function draw_saw(x,y,a,col)
 local face=(a*8+.5)\1%8
 local i=face%4*6+1
 local sx,sy,w,h,ox,oy=
  unpack(saw_atlas,i,i+5)
 local flip=face>=4
 if col==8 then pal(9,8) end
 x=flr(x+.5)-8
 y=flr(y+.5)-8
 sspr(sx,sy,w,h,
  x+(flip and 16-w-ox or ox),
  y+(flip and 16-h-oy or oy),
  w,h,flip,flip)
 pal(9,9)
end
