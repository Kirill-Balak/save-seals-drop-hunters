--gameplay
gamestate.gameplay={
	init=function()
		level_menu()
		tut=nil
		setup_scene(split(levels[level_id]))
		rescue_start()
	end,
	update=function()
		notice=max(0,notice-1)
		if phase=="resolve" then
			if resolver then
				resume_resolve()
				return
			end
			wait-=1
			if wait<=0 then
				phase="aim"
			end
			return
		end
		if phase=="aim" then
			if btn(0) then
				angle+=.0095
			end
			if btn(1) then
				angle-=.0095
			end
			angle=angle%1
			local shift=0
			if btn(2) then shift-=1 end
			if btn(3) then shift+=1 end
			if shift!=0 then
				shift*=
					shift_polarity(angle)
				offset=wrap_shift(
					offset+shift*1.25,angle)
			end
			aim_line()
			if fresh then
				start_cut()
			end
		end
		if not tut then magnet_tick() end
		physics()
		if outcome then
			return
		end
		if not tut then hunt_tick() end
		if outcome then return end
		if phase=="slicing" then
			cut.frame+=1
			if cut.frame>=12 then
				sfx(-1,0)
				phase="resolve"
				resolver=
					cocreate(resolve_cut)
				resume_resolve()
			end
		end
	end,
	draw=function()
		draw_scene()
	end
}

function aim_line()
	aim=line_for(angle,offset)
end

function shift_polarity(a)
	local ny=cos(a)
	return sgn(ny==0 and
		-sin(a) or ny)
end

function shift_key(dd,a)
	return dd*shift_polarity(a)>0
		and 3 or 2
end

function shortest_shift(d,t,a)
	local lo,hi=shift_range(a)
	local span=hi-lo
	return (t-d+span/2)%span-
		span/2,span
end

function shift_range(a)
	local nx,ny=-sin(a),cos(a)
	local l,r=-48*nx,47*nx
	local t,b=-56*ny,55*ny
	return min(l,r)+min(t,b)-2,
		max(l,r)+max(t,b)+2
end

function wrap_shift(d,a)
	local lo,hi=shift_range(a)
	return lo+(d-lo)%(hi-lo)
end

function line_for(a,d)
	local tx,ty=cos(a),sin(a)
	local nx,ny=-ty,tx
	local px=52+nx*d
	local py=68+ny*d
	local lo,hi=-90,90
	lo,hi=clip_axis(lo,hi,
		px,tx,4,99)
	if hi>=lo then
		lo,hi=clip_axis(lo,hi,
			py,ty,12,123)
	end
	return record([[tx
ty
nx
ny
px
py
lo
hi]],tx,ty,nx,ny,px,py,lo,hi)
end

function clip_axis(lo,hi,p,t,
	low,high)
	local start=p+t*lo
	local span=t*(hi-lo)
	local x,y=0,1
	x,y=time_clip(x,y,
		start-low,span)
	x,y=time_clip(x,y,
		high-start,-span)
	return lo+(hi-lo)*x,
		lo+(hi-lo)*y
end

function start_cut()
	if aim.hi<=aim.lo then
		notice=9
		if tut then
			tutorial_result(false)
		end
		return
	end
	cut={}
	for k,v in pairs(aim) do
		cut[k]=v
	end
	cut.frame=0
	cut.front=cut.lo
	for o in all(actors) do
		o.hit=false
	end
	phase="slicing"
	sfx(0,0)
end

function finish(won,why,o)
	sfx(-1,0)
	if tut then
		tutorial_result(won)
		return
	end
	if result then return end
	sfx(won and 8 or 9,3)
	end_reason=why
	end_event={}
	for j=1,whitecount do
		local w=actors[j]
		if w==o or
			why=="circle_split" then
			add(end_event,
				w)
		end
	end
	seal_result(won)
	outcome=won and "win" or
		"lose"
	set_state("endgame")
end

function resolve_cut()
	if cut.rewarded then
		return
	end
	local c=cut
	local w=actors[1]
	local side=sgn(normal(c,
		w.x,w.y))
	c.nx*=side
	c.ny*=side
	local nextmask,removed={},{}
	local other
	for i=1,2688 do
		if ice[i] then
			local p=cell_poly(ice,i)
			local a,b=split_cell(p,c)
			nextmask[i]=a==p and ice[i] or a
			removed[i]=b==p and ice[i] or b
			other=other or b
		end
		if i%240==0 then
			yield_work()
		end
	end
	if not other then
		if tut then
			tutorial_result(false)
		else
			phase="aim"
			notice=9
		end
		return
	end
	if not tut then shots-=1 end
	add(planes,c)
	local labels=components(
		nextmask)
	local keep=labels[cell_at(
		w.x,w.y)]
	for j=1,whitecount do
		local o=actors[j]
		if abs(normal(c,o.x,o.y))<=4
		then
			deli(planes)
			finish(false,
				"circle_hit",o)
			return
		end
		if labels[cell_at(o.x,o.y)]
			!=keep then
			deli(planes)
			finish(false,
				"circle_split",o)
			return
		end
		assert(fits(nextmask,
			o.x,o.y))
	end
	local newice,lost={},{}
	for i=1,2688 do
		if labels[i]==keep then
			newice[i]=nextmask[i]
		elseif ice[i] then
			removed[i]=ice[i]
		end
		if removed[i] then
			add(lost,i)
		end
	end
	ice=newice
	sfx(1,2)
	yield_work()
	cache_ice()
	break_ice(lost,removed)
	combo=0
	drifting={}
	local cx,cy=0,0
	for j=#actors,whitecount+1,-1
	do
		local o=actors[j]
		if labels[cell_at(o.x,o.y)]
			!=keep or
			normal(c,o.x,o.y)<0 then
			cx+=o.x
			cy+=o.y
			if o==hunter then hunter,target=nil end
			if o==thrower then release_line() end
			add(drifting,o)
			deli(actors,j)
			combo+=1
		elseif not fits(ice,
			o.x,o.y) then
			if not nudge(o) then
				recover_actor(o)
			end
		end
	end
	enemies=#actors-whitecount
	if not tut and combo>0 then
		reward_charge(combo,
			cx/combo,cy/combo)
	end
	if not tut or enemies==0 then
		award_area(lost,removed)
		award_enemies(combo,
			cx/max(1,combo),
			cy/max(1,combo))
	end
	cut.rewarded=true
	if tut then
		lesson_validate()
	elseif enemies==0 then
		finish(true)
	elseif shots==0 then
		finish(false,"out_of_cuts")
	else
		phase="resolve"
		wait=3
	end
end

function yield_work()
	if resolver then
		yield()
	end
end

function resume_resolve()
	local ok,err=
		coresume(resolver)
	assert(ok,err)
	if costatus(resolver)=="dead"
	then resolver=nil end
end
function normal(c,x,y)
	return (x-c.px)*c.nx+
		(y-c.py)*c.ny
end

function setup_scene(c)
		shots,whitecount,star_two,
			star_three=unpack(c)
		reset_fields([[tick
angle
score
score_shown
score_bank
notice
ghostlife
area_points
kill_points
combo_points
solo_kills
remaining_cut_points]],0)
		reset_fields([[score_flights
fx
debris
ghosts
actors
planes]])
		phase="aim"
		offset=-20
		result,cut,outcome,resolver,
			end_reason,end_event=nil
		held=btn(5)
		make_ice(c)
		for j=6+c[5]*3,#c,4 do
			spawn(c[j],c[j+1],
				c[j+2],c[j+3],
				#actors<whitecount)
		end
		enemies=#actors-whitecount
		aim_line()
end
-->8
