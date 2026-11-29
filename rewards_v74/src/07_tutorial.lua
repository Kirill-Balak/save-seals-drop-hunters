-->8
--tutorial
h_idle,h_move,h_hold,h_back,
	h_retry,h_pulse=
	unpack(split[[
 60,36,22,12,18,42]])

function lesson_setup(s)
	setup_scene(split(levels[6]))
	tut=true
	learn_key=(s+4)%6
	t_stage,t_idle,t_used=s,0
	angle=(split[[
  .25,.5,0,0,0,0]])[s]
	offset=(split[[
  0,0,0,-38,40,-20]])[s]
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
	if t_stage==6 then
		trained=1
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
		d*normal(c,r.x,r.y)<0
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
	if t_stage>=4 then
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
	local dd,span=shortest_shift(
		g_sd,g_td,g_ta)
	local rot=abs(da)>.001
	local slide=abs(dd)>.1
	local dir=sgn(dd)
	local n=h_move
	local first=rot and n or 0
	local duration=first+
		(slide and n or 0)
	local back=slide and n or
		h_back
	local total=duration+
		h_hold+back
	local t=g_age%total
	local ra=rot and ease(t/n)
		or 1
	local rd=slide and
		ease((t-first)/n) or 1
	local b=ease((t-duration-
		h_hold)/back)
	if slide then
		rd+=(dir*span-dd)/dd*b
	else
		ra-=b
		rd-=b
	end
	g_button=5
	if b>0 then
		if slide then
			g_button=shift_key(dir,g_ta)
		elseif rot then
			g_button=da>0 and 1 or 0
		end
	elseif t<duration then
		g_button=t<first and
			(da>0 and 0 or 1) or
			shift_key(dd,g_ta)
	end
	g_a=g_sa+da*ra
	g_d=g_sd+dd*rd
	if slide and
		t>=first then
		g_d=wrap_shift(g_d,g_ta)
	end
	if slide and rot and
		t==total-1 then
		g_visible=false
	end
	g_age+=1
end

function tutorial_draw()
	draw_scene()
	if phase=="lesson_result"
		and not t_passed then
		local t=h_retry-
			t_wait
		if t<5 then
			rect(4,12,99,123,8)
			local w=actors[1]
			circ(w.x,w.y,6+t,8)
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
			draw_saw(x,y,g_a,
				g_age\5%2,7)
		end
	end
	local key=g_kind=="cut" and 5
		or g_button
	rectfill(45,114,59,123,0)
	print(key_glyph(key),
		49,117-tick\12%2,
		key==learn_key and 8 or 7)
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

