--ui
function draw_scene()
	clip(4,12,96,112)
	local phase_step=time()*6\1
	for i=0,63 do
		local f=(phase_step+i)%4
		sspr(8+f%2*8,f\2*4,8,4,
			4+(i*i+i)%89,12+i*19%108)
	end
	for p in all(texture) do
		line(unpack(p))
	end
	if ghostlife>0 then
		local d=(16-ghostlife)*.9
		for e in all(ghosts) do
			local dx,dy=e[5]*d,e[6]*d
			line(e[1]+dx,e[2]+dy,
				e[3]+dx,e[4]+dy,12)
		end
		for o in all(drifting) do
			local sign=sgn(normal(cut,o.x,o.y))
			draw_actor(o,
				o.x+cut.nx*sign*d,
				o.y+cut.ny*sign*d,true)
		end
	end
	for p in all(debris) do
		if ghostlife==0 then
			local s=p.life>11 and 2
				or 1
			rect(p.x,p.y,
				p.x+s,p.y+s,7)
		end
	end
	if tut and g_kind!="cut"
	then ghost_draw() end
	if not outcome and (tut or not placing) then
		if phase=="aim" then
			draw_aim()
		elseif phase=="slicing" then
			local f=cut.front
			blade_line(cut,cut.lo,f,0)
			draw_saw(
				cut.px+cut.tx*f,
				cut.py+cut.ty*f,
				angle,
				cut.frame\3%2,7)
		elseif phase=="resolve" then
			blade_line(cut,cut.lo,cut.hi,0)
		end
	end
	if tut and g_kind=="cut"
	then ghost_draw() end
	if not tut then draw_harpoon_line() end
	for o in all(actors) do
		draw_actor(o,flr(o.x+.5),
			flr(o.y+.5))
	end
	for p in all(fx) do
		pset(p.x,p.y,p.c)
	end
	if not tut and not outcome then draw_rescue() end
	clip()
	draw_hud()
end

function draw_aim()
	local col=notice>0 and 8 or 0
	if tut then
		blade_line(aim,aim.lo,aim.hi,col)
	else
	for s=aim.lo,aim.hi,6 do
		blade_line(aim,s,
			min(s+2,aim.hi),col)
	end
	end
end

function blade_line(c,a,b,col)
	line(c.px+c.tx*a,
		c.py+c.ty*a,c.px+c.tx*b,
		c.py+c.ty*b,col)
end

function draw_hud()
	print(score_shown,2,3,7)
	if tut then
		for j=1,6 do
			(j==t_stage and circfill
				or circ)(23+j*8,5,2,7)
		end
		return
	end
	local flash=end_reason=="out_of_cuts" and
		ending%6<3
	draw_saw(33,5,0,1,
		(notice>0 or flash) and 8 or 9)
	print(shots,45,3,7)
	magnet_hud()
	print(level_id.."/5",105,3,7)
	if snared and not outcome then rescue_hud() end
end

function key_glyph(k)
	k+=1
	return sub("⬅️➡️⬆️⬇️🅾️❎",
		k,k)
end

function draw_controls()
	line(102,12,102,123,7)
	for k=0,5 do
		if not tut or
			tut and (k==5 or k<4 and t_stage>=k+2) then
			local y=24+(tut and
				(k==5 and 4 or k)*20 or k*16)
			local pulse=btn(k)
			local col=tut and
				k==learn_key and 8 or 7
			if k==4 and charge_shown==3
				and tick%24<12 then col=9 end
			if tut and t_stage==6
				and t_idle>=h_idle
				and g_button==k then
				pulse=tick%24<12
			end
			print(key_glyph(k),105,y,col)
			if pulse then
				line(105,y+8,111,y+8,col)
			end
			control_icon(120,y+3,k,col)
		end
	end
end

function control_icon(x,y,k,col)
	local a=(tick%60)/60
	if k==4 or k==5 and placing
		and not tut then
		magnet_icon(x,y,
			charge_shown==3 and 9 or 12)
		if k==4 and placing and hold_o>0 then
			line(x-5,y+6,x-5+hold_o/2,y+6,8)
		end
	elseif placing and not tut then
		circ(x,y,3,9)
	elseif k==5 then
		draw_saw(x,y,0,
			tick\8%2,col)
	elseif k<2 then
		a*=k==0 and 1 or -1
		local dx,dy=cos(a)*5,sin(a)*5
		line(flr(x+.5-dx),flr(y+.5-dy),
			flr(x+.5+dx),flr(y+.5+dy),col)
	else
		local dy=flr((k==2 and -1
			or 1)*(a*14-7)+.5)
		clip(x-5,y-5,11,11,true)
		line(x-4,y+dy,x+4,y+dy,col)
		clip()
	end
end

function draw_saw(x,y,a,open,col)
	local face=flr(a*8+.5)%8
	local frame=({0,4,2,4})[face%4+1]+open
	local i=frame*6+1
	local sx,sy,w,h,ox,oy=unpack(saw_atlas,i,i+5)
	local fx,fy=face>=3 and face<=5,face>0 and face<4
	if col==8 then pal(9,8) end
	sspr(sx,sy,w,h,
		flr(x+.5)-8+(fx and 16-w-ox or ox),
		flr(y+.5)-8+(fy and 16-h-oy or oy),w,h,fx,fy)
	pal(9,9)
end

function award_area(lost,mask)
	if not cut.area_paid then
	cut.area_paid=true
	if #lost>0 then
	local a,x,y=measure(mask,
		lost[1])
	for j=2,#lost do
		local i=lost[j]
		local w,cx,cy=measure(
			mask,i)
		if w>0 then
			local t=w/(a+w)
			x+=(cx-x)*t
			y+=(cy-y)*t
			a+=w
		end
	end
	local n=max(1,
		flr(a*reward_cell+.5))
	area_points+=n
	score+=n
	score_flight(n,1,x,y)
	end
	end
end

function score_flight(n,k,x,y)
	local t=0
	if k!=4 then
		for p in all(score_flights) do
			if p.k!=4 then t-=24 end
		end
	end
	add(score_flights,record(
		[[n
k
t
sx
sy]],n,k,t,x,y))
end

function update_scorefx()
	for p in all(score_flights)
	do
		p.t+=1
		if p.k==4 then
			if p.t>=15 then
				bank_charge(p.n)
				del(score_flights,p)
			end
		elseif p.t>=24 then
			score_bank+=p.n
			del(score_flights,p)
		end
	end
	score_shown+=ceil(
		(score_bank-score_shown)/3)
end

function draw_scorefx()
	for p in all(score_flights)
	do
		if p.k==4 then
			draw_charge_flight(p)
		elseif p.t>=0 then
			local t=ease((p.t-6)/18)
			local text="+"..p.n
			local cx=mid(#text*2+26,
				p.sx,98-#text*2)
			local ix=flr(cx-15+
				(31-cx)*t)
			local iy=mid(15,p.sy+3,122)
			iy=flr(iy+(15-iy)*t)
			local x=flr(cx+(16-cx)*t-
				#text*2)
			local y=flr(p.sy+
				(2-p.sy)*t)
			local col=p.k==1 and 7
				or p.k==2 and 8 or 9
			clip(0,10,101,118)
			if t<=.95 then
				reward_icon(p.k,ix,iy)
			end
			if t>.7 then
				clip(0,0,33,128)
			end
			print("\^o05a"..text,
				x,y,col)
			clip()
		end
	end
end
