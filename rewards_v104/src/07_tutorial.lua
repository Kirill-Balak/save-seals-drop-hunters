-->8
--tutorial
h_idle,h_move,h_hold,h_back,
	h_retry,h_pulse=
	unpack(split[[
 60,36,22,12,18,42]])
lesson_mx,lesson_my=74,77
-- Keep the magnet on after the first 30 updates of pull.
lesson_pull_end=80

function tutorial_update()
	if phase=="lesson_result"
	then
		if score_shown==score then
			t_wait-=1
		end
		if t_wait<=0 then
			if t_passed then
				lesson_next()
			else
				lesson_setup(
					t_stage)
				t_idle=-12
				g_visible=false
			end
		end
		return
	end
	if t_stage==7 and phase!="resolve" then
		if magnet==0 then return end
		magnet_tick()
		if magnet>lesson_pull_end then
			physics()
			return
		end
	end
	local a,d=angle,offset
	gamestate.gameplay:update()
	if phase=="lesson_result"
	then
		return
	end
	local acted=angle!=a or
		offset!=d or fresh
	if acted then
		t_used=true
		t_idle=0
		g_visible=false
		g_age=0
	else
		t_idle+=1
	end
	if phase=="aim" then
		tutorial_hint()
		ghost_update(acted)
	else
		g_visible=false
	end
end

function tutorial_result(ok)
	if phase!="lesson_result"
	then
	phase="lesson_result"
	t_passed=ok
	t_wait=ok and
		1 or
		h_retry
	g_visible=false
	if not ok then
		burst(actors[1].x,
			actors[1].y,8,8)
	end
	end
end

function lesson_validate()
	local w=actors[1]
	tutorial_result(enemies==0
		and fits(ice,w.x,w.y))
end

function lesson_next()
	if t_stage==7 then
		trained=1
		dset(3,0)
		save_progress()
		start_level(1)
	else
		lesson_setup(
			t_stage+1)
	end
end

function tutorial_ready(c)
	local w,r=actors[1],actors[2]
	if not r then
		return false
	end
	local d=normal(c,w.x,w.y)
	return c.hi>c.lo and
		abs(d)>4 and
		d*normal(c,r.x,r.y)<0 and
		(t_stage!=7 or d*normal(c,actors[3].x,actors[3].y)<0)
end

function lesson_setup(s)
	setup_scene(split(lesson_level))
	tut=true
	magnet,placing=0,nil
	learn_key=(s+4)%6
	t_stage,t_idle,t_used=s,0
	angle=(split[[
  .25,.5,0,0,0,0,0]])[s]
	offset=(split[[
  0,0,0,-38,40,-20,0]])[s]
	if s==7 then
		release_line()
		charge,charge_shown=3,3
		hunter,target,blocked=nil
		o_down=btn(4)
		actors[1].x,actors[1].y=36,42
		actors[2].x,actors[2].y=66,58
		spawn(82,92,-.8,0,false)
		enemies=2
	end
	if s==4 or s==5 then
		actors[1].x=52
		actors[1].y=44
		actors[2].x=52
		actors[2].y=96
	end
	aim_line()
	g_age,g_visible,g_kind,
		g_button,g_sa,g_sd,g_ta,
		g_td,
		g_a,g_d=0,false
	tutorial_hint()
end

function tutorial_hint()
	if t_stage==6 then
		g_kind="remind"
		return
	end
	if tutorial_ready(aim) then
		g_kind="cut"
		g_a=angle
		g_d=offset
		return
	end
	local a,d=.75,offset
	if t_stage==7 then
		a,d=0,(actors[1].y+min(actors[2].y,actors[3].y))/2-68
	elseif t_stage>=4 then
		a=angle
		local c=line_for(a,0)
		local w,r=actors[1],actors[2]
		local u=normal(c,w.x,w.y)
		local v=normal(c,r.x,r.y)
		d=t_stage==4 and
			v+sgn(u-v)*4 or
			u+sgn(v-u)*6
		if not tutorial_ready(
			line_for(a,d)) then
			d=(u+v)/2
		end
	end
	if not tutorial_ready(
		line_for(a,d)) then
		a,d=.75,0
		if t_stage>=4 then
			a,d=0,t_stage==4 and
				24 or -18
		end
	end
	if g_ta!=a or
		g_td!=d then
		g_age=0
	end
	g_ta,g_td=a,d
	g_kind="motion"
end

function ease(t)
	t=mid(0,t,1)
	return t*t*(3-2*t)
end

function ghost_update(acted)
	if g_kind=="remind" then
		g_visible=false
		g_button=flr(t_idle/
			h_idle)%4
		return
	end
	if g_kind=="cut" then
		g_visible=t_idle>=0
		g_age+=1
		return
	end
	if acted or t_idle<0 or
		t_used and t_idle<h_idle then
		g_visible=false
		g_sa,g_sd=angle,offset
		return
	end
	if not g_visible then
		g_sa,g_sd=angle,offset
		g_age=0
	end
	g_visible=true
	local da=(g_ta-g_sa+.5)%1-.5
	if t_stage==2 then
		da%=1
	elseif t_stage==3 then
		da=-(-da%1)
	end
	local dd=shortest_shift(
		g_sd,g_td,g_ta)
	local slide=abs(dd)>.1
	local n=h_move
	local first=abs(da)>.001 and n or 0
	local duration=first+
		(slide and n or 0)
	local t=g_age%(duration+h_hold+h_back)
	g_age+=1
	g_button=nil
	-- Leave the restart of the demo unlabelled.
	if t>=duration+h_hold or duration==0 then return end
	if t<first or not slide then
		g_button=da>0 and 0 or 1
	else
		g_button=shift_key(dd,g_ta)
	end
	g_a=g_sa+da*ease(t/n)
	g_d=g_sd+dd*ease((t-first)/n)
	if slide and t>=first then
		g_d=wrap_shift(g_d,g_ta)
	end
end

function tutorial_draw()
	draw_scene()
	if t_stage==7 and magnet==0 then
		magnet_lesson_draw()
	end
	if phase=="lesson_result"
		and not t_passed then
		local t=h_retry-
			t_wait
		if t<5 then
			local c=t_stage==1 and 7 or 8
			rect(4,12,99,123,c)
			local w=actors[1]
			circ(w.x,w.y,6+t,c)
		end
	end
end

gamestate.tutorial={
	init=function()
		menuitem(1)
		lesson_setup(1)
	end,
	update=tutorial_update,
	draw=tutorial_draw
}

function hint_clear(x,y,r)
	for o in all(actors) do
		if abs(x-o.x)<r and
			abs(y-o.y)<r then
			return false
		end
	end
	return true
end

function ghost_draw()
	if not g_visible or
		phase!="aim" then return end
	local key=g_kind=="cut" and 5 or g_button
	if not key then return end
	local c=line_for(g_a,g_d)
	if g_kind!="cut" then
		local on=min(3,flr(
			(1+cos(g_age%h_pulse/
				h_pulse))*2+.001))
		dashed_line(c,8,on)
	else
		local s=c.lo+(c.hi-c.lo)*
			((g_age%48)/48)
		local x,y=c.px+c.tx*s,
			c.py+c.ty*s
		if hint_clear(x,y,8) then
			action_saw(x,y)
		end
	end
	draw_hint_key(key,(key!=5 or t_stage==1) and 8 or 7)
end

function draw_hint_key(key,col,press)
	rectfill(45,114,59,123,0)
	local y=117-tick\12%2
	if press then
		y=117-(time()*3%1<.5 and 1 or 0)
	end
	print(key_glyph(key),
		49,y,col)
end

function magnet_lesson_key()
	if not placing then return 4 end
	if magnet_valid() then return 5 end
	local dx,dy=lesson_mx-mx,lesson_my-my
	if abs(dx)>abs(dy) then return dx>0 and 1 or 0 end
	return dy>0 and 3 or 2
end

function magnet_lesson_draw()
	local key=magnet_lesson_key()
	if key!=5 then
		local wave=time()*1.5%1
		circ(lesson_mx,lesson_my,3+wave*4,7)
		pset(lesson_mx,lesson_my,9)
		if placing then
			for i=0,3 do
				local t=(i+wave)/4
				pset(mx+(lesson_mx-mx)*t,my+(lesson_my-my)*t,7)
			end
		end
	end
	draw_hint_key(key,8,true)
end

function dashed_line(c,gap,on)
	for s=c.lo,c.hi do
		if (s-c.lo)%gap<on then
			local x=flr(c.px+c.tx*s+.5)
			local y=flr(c.py+c.ty*s+.5)
			if hint_clear(x,y,8) then
				pset(x,y,7)
			end
		end
	end
end

