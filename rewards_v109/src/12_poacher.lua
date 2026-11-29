-- 40 sprites from tile 128.
function poacher_pose(o,still)
	local dx,dy=o.vx,o.vy
	local phase=tick\3%4
	if still or tut and
		(t_stage<6 or t_stage==7 and magnet==0)
	then
		phase=4
	elseif not tut and o==thrower then
		dx,dy=hvx,hvy
		phase=7
	elseif magnet>0
		and o.pull then
		dx,dy=mx-o.x,my-o.y
		phase=6
	elseif not tut and o==hunter
	then
		dx=target.x-o.x
		dy=target.y-o.y
		phase=aim_wait>
			90-4*level_id and 5 or 6
	elseif o.path and o.ox and
		(o.x!=o.ox or o.y!=o.oy)
	then
		dx,dy=o.x-o.ox,o.y-o.oy
	end
	local a=atan2(dx,dy)
	local row,flip=poacher_heading(a)
	return row,phase,flip
end

function poacher_heading(a)
	local face=(a*8+.5)\1%8
	local row=ord("\0\1\2\1\0\3\4\3",face+1)
	return row,face>=3 and face<=5
end

function magnet_vector(o)
	local dx,dy=mx-o.x,my-o.y
	if abs(dx)>34 or abs(dy)>34 then return end
	local a=atan2(dx,dy)
	local row,flip=poacher_heading(a)
	local gx,gy=poacher_grip(row,6,flip,o.x,o.y)
	-- retain v107 magnet reach
	local reach=o==thrower and .6 or 1
	return mx-gx-cos(a)*5*reach,
		my-gy-sin(a)*4*reach
end

function poacher_grip(row,phase,flip,x,y)
	local i=64+row*8+phase
	local gx=sget(i,80)
	return x+(flip and 7-gx or gx)-4,
		y+sget(i,81)-4
end

function draw_poacher(o,x,y,still)
	local row,phase,flip=
		poacher_pose(o,still)
	spr(128+row*8+phase,x-4,y-4,
		1,1,flip)
end

function draw_harpoon_line()
	if not thrower then return end
	local row,flip=
		poacher_heading(atan2(hvx,hvy))
	local px,py=flr(thrower.x+.5),
		flr(thrower.y+.5)
	local gx,gy=poacher_grip(
		row,7,flip,px,py)
	local dx,dy=gx-px+hvx*.25,
		gy-py+hvy*.25
	-- only the up-right reference uses a launch transition
	if row==1 and not flip then
		local launch=max(0,flight-30)*.25
		dx=-hvx*.5+(dx+hvx*.5)*launch
		dy=-hvy*.5-2+(dy+hvy*.5+2)*launch
	end
	local x,y=hx+dx,hy+dy
	if snared then
		line(gx,gy,snared.x,snared.y,9)
		if tether_left<=rescue_time-13 then return end
		y+=(rescue_time-tether_left)*.4
	else
		line(gx,gy,x,y,9)
	end
	local down=row==4
	spr(40+(down and 2 or row),
		x-(flip and 4 or 3),
		y-(down and 4 or 3),
		1,1,flip,down)
end
