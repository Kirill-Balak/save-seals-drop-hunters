-->8
--rescue
hunt_radius=24
rescue_time=150
tether_span=26

function release_line()
	thrower,snared,flight=nil,nil,0
end

function rescue_start()
	release_line()
	victim,magnet=1,0
	charge=mid(0,flr(dget(24)),3)
	charge_shown=charge
	hunter,target,placing,blocked=nil
	o_down=btn(4)
	hunt_delay,hunt_windup=unpack(hunt_timing,2*level_id-1,2*level_id)
	hunt_wait=hunt_delay
end

function reward_charge(n,x,y)
	hunt_wait=hunt_delay
	local gain=min(3-charge,min(2,n))
	if gain>0 then
		charge+=gain
		score_flight(gain,4,x,y)
	end
end

function bank_charge(n)
	charge_shown+=n
	if charge_shown==3 then
		sfx(5,3)
	end
end

function magnet_in_range(o)
	local dx,dy=magnet_vector(o)
	return dx and dx*dx+dy*dy<=hunt_radius^2,dx,dy
end

function magnet_valid()
	return fits(ice,mx,my,0) and (not tut or
		magnet_in_range(actors[2]) and magnet_in_range(actors[3]))
end

function magnet_input()
	local down=btn(4)
	local pressed=down and not o_down
	o_down=down
	local place_now=placing and fresh
	if not placing then
		if not (pressed and phase=="aim" and charge_shown==3 and magnet==0 and not snared) then return end
		placing,hold_o=true,-1
		mx,my=actors[1].x,actors[1].y
	end
	mx=mid(4,mx+1.5*((btn(1) and 1 or 0)-(btn(0) and 1 or 0)),99)
	my=mid(12,my+1.5*((btn(3) and 1 or 0)-(btn(2) and 1 or 0)),123)
	if not place_now then
		if hold_o<0 then
			if not down then hold_o=0 end
		elseif down then
			hold_o+=1
			if hold_o>=18 then placing=nil end
		elseif hold_o>0 then
			hold_o,place_now=0,true
		end
	end
	if place_now and magnet_valid() then
		placing,charge,charge_shown,magnet=nil,0,0,110
		sfx(6,3)
	end
	return true
end

function magnet_tick()
	if magnet==0 then return end
	if not tut or magnet>lesson_pull_end then magnet-=1 end
	if magnet==0 or not fits(ice,mx,my,0) then
		magnet,blocked=0,nil
		return
	end
	if magnet%24==0 then sfx(7,3) end
	for j=whitecount+1,#actors do
		local o=actors[j]
		local dx,dy
		o.pull,dx,dy=magnet_in_range(o)
		if o.pull then
			if o==hunter then
				hunter,target,blocked=nil,nil,true
				hunt_wait=hunt_delay
			end
			o.vx,o.vy=mid(-1.3,dx*.12,1.3),mid(-1.3,dy*.12,1.3)
		end
	end
end

function tether_move()
	local dx=thrower.x-snared.x
	local dy=thrower.y-snared.y
	local d=max(1,length(dx,dy))
	local tug=mid(-.85,(d-tether_span)*.08,.24)/d
	snared.vx=snared.vx*.8+dx*tug
	snared.vy=snared.vy*.8+dy*tug
	if d<tether_span and not (magnet>0 and thrower.pull) then
		local rate=(thrower.vx*dx+thrower.vy*dy)/d
		local back=max(0,(tether_span-d)*.075-rate)/d
		thrower.vx+=dx*back
		thrower.vy+=dy*back
	end
end

function hunt_tick()
	if snared then
		if tether_left==1 and phase=="slicing" and cut.frame==11 then return end
		tether_left-=1
		if tether_left==0 then
			thrower.vx,thrower.vy=thrower.x<52 and -3 or 3,0
			snared.vx,snared.vy=thrower.vx,0
			finish(false,"harpoon",snared)
		else
			tether_move()
		end
	elseif flight>0 then
		for j=1,whitecount do
			local o=actors[j]
			if near_path(hx-o.x,hy-o.y,hvx,hvy) then
				flight,snared,tether_left=0,o,rescue_time
				sfx(4,2)
				return
			end
		end
		hx,hy,flight=hx+hvx,hy+hvy,flight-1
		if flight==0 then release_line() end
	elseif hunter then
		aim_wait-=1
		if aim_wait==0 then
			hx,hy=hunter.x,hunter.y
			local dx,dy=target.x-hx,target.y-hy
			local lead=length(dx,dy)/4
			dx+=target.vx*lead
			dy+=target.vy*lead
			local a=atan2(dx,dy)
			hvx,hvy=cos(a)*4,sin(a)*4
			thrower=hunter
			hunter,target,flight=nil,nil,34
			hunt_wait=hunt_delay
			sfx(3,2)
		end
	elseif not blocked then
		hunt_wait-=1
		if hunt_wait<=0 and enemies>0 then
			hunter=actors[whitecount+1]
			target=actors[victim]
			victim=victim%whitecount+1
			aim_wait=hunt_windup
			sfx(2,2)
		end
	end
end

function magnet_icon(x,y,c)
	pal(9,c)
	pal(8,c==7 and 9 or c==8 and 7 or c==12 and 12 or 8)
	spr(3,x-4,y-4)
	pal(8,8)
	pal(9,9)
end

function haul_away()
	local dx=thrower.vx
	thrower.x+=dx
	snared.x+=dx
end

function magnet_hud(x)
	local wave=flr(time()*1.25%1*3)
	local full=charge_shown==3
	local c=full and (wave==0 and 7 or 9) or 9
	magnet_icon(x,5,full and c or 12)
	for i=1,3 do
		rectfill(x+2+i*5,3,x+4+i*5,7,
			i<=charge_shown and c or 12)
	end
	if full then
		rect(x+6-wave,2,x+20+wave,8,c)
	end
end

function draw_charge_flight(p)
	local t=ease(p.t/15)
	magnet_icon(p.sx+(62-p.sx)*t,
		p.sy+(5-p.sy)*t,9)
end

function rescue_hud()
	local c=tether_left<45 and 8 or 9
	rectfill(4,10,99,11,12)
	rectfill(4,10,3+ceil(96*tether_left/rescue_time),11,c)
end

function draw_rescue()
	if hunter then
		local x,y=hunter.x,hunter.y
		if tick%12<8 then
			circ(x,y-1,8,8)
			circ(target.x,target.y,6,8)
		end
	end
	if flight>0 then
		line(hx-hvx,hy-hvy-2,
			hx,hy-2,7)
		pset(hx,hy-2,7)
	elseif snared then
		if tether_left>rescue_time-13 then
			local drop=(rescue_time-tether_left)*.4-2
			line(hx-hvx,hy-hvy+drop,hx,hy+drop,7)
		end
		circ(thrower.x,thrower.y,5,9)
		pset(snared.x-1,snared.y+2,9)
	end
	if placing or magnet>0 then
		local c=placing and not magnet_valid() and 8 or 9
		-- Match the half-pixel center of the 8x8 icon.
		local x,y=flr(mx+.5),flr(my+.5)
		local r=hunt_radius
		oval(x-r,y-r,x+r-1,y+r-1,c)
		magnet_icon(x,y,magnet>0 and tick%12<4 and 7 or c)
		if placing then oval(x-6,y-6,x+5,y+5,c) end
	end
end
