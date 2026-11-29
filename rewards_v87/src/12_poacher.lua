-- 40 sprites from tile 128.
function poacher_pose(o,still)
	local dx,dy=o.vx,o.vy
	local phase=tick\3%4
	if still or tut and t_stage<6
	then
		phase=4
	elseif not tut and magnet>0
		and o.pull then
		dx,dy=mx-o.x,my-o.y
		phase=6
	elseif not tut and o==hunter
	then
		dx=target.x-o.x
		dy=target.y-o.y
		phase=aim_wait>
			90-4*level_id and 5 or 6
	elseif not tut and o==thrower
		and flight==34 then
		dx,dy=hvx,hvy
		phase=7
	elseif o.path and o.ox and
		(o.x!=o.ox or o.y!=o.oy)
	then
		dx,dy=o.x-o.ox,o.y-o.oy
	end
	local a=atan2(dx,dy)
	local row,flip=poacher_heading(a)
	return row,phase,flip,a
end

function poacher_heading(a)
	local face=(a*8+.5)\1%8
	local row=ord("\0\1\2\1\0\3\4\3",face+1)
	return row,face>=3 and face<=5
end

function weapon_reach(a,loaded,low)
	local reach=loaded and 1 or .6
	local dx,dy=cos(a),sin(a)+low
	return dx*5*reach,dy*4*reach,
		dx,dy
end

function magnet_vector(o)
	local dx,dy=mx-o.x,my-o.y
	if abs(dx)>34 or abs(dy)>34 then return end
	local a=atan2(dx,dy)
	local row,flip=poacher_heading(a)
	local gx,gy=poacher_grip(row,6,flip,o.x,o.y)
	local ax,ay=weapon_reach(a,o!=thrower,0)
	return mx-gx-ax,my-gy-ay
end

function poacher_grip(row,phase,flip,x,y)
	local i=64+row*8+phase
	local gx=sget(i,80)
	return x+(flip and 7-gx or gx)-4,
		y+sget(i,81)-4
end

function draw_poacher(o,x,y,still)
	local row,phase,flip,a=
		poacher_pose(o,still)
	local gx,gy=poacher_grip(
		row,phase,flip,x,y)
	spr(128+row*8+phase,x-4,y-4,
		1,1,flip)
	local loaded=tut or o!=thrower
	local pulled=not still and not tut and magnet>0 and o.pull
	if loaded or pulled then
		local low=phase<6 and .65 or 0
		local ax,ay,dx,dy=weapon_reach(a,loaded,low)
		local tx,ty=gx+ax,gy+ay
		line(gx-dx*2,gy-dy*2,
			tx,ty,1)
		line(gx,gy,
			tx-dx,ty-dy,7)
		if loaded then
			line(tx-dx*2+dy,
				ty-dy*2-dx,
				tx,ty,7)
		end
		pset(tx,ty,pulled and 9 or 7)
		pset(gx,gy,7)
	end
end

function draw_harpoon_line()
	if not thrower then return end
	local row,phase,flip=
		poacher_pose(thrower)
	local gx,gy=poacher_grip(
		row,phase,flip,
		flr(thrower.x+.5),
		flr(thrower.y+.5))
	line(gx,gy,
		snared and snared.x or hx,
		snared and snared.y or hy-2,9)
end
