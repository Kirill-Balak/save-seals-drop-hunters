--objects
function spawn(x,y,vx,vy,w)
	add(actors,record(
		[[x
y
vx
vy
white
hit
slide]],
		x,y,vx,vy,w,false,0))
end

function speed_limit(o)
	if magnet>0 and o.pull then return end
	local s=length(o.vx,o.vy)
	if s<.01 then
		o.vx=.55
		o.vy=0
	else
		local lo=o.white and .55
			or .75
		local target=mid(lo,
			s*.999,2)/s
		o.vx*=target
		o.vy*=target
	end
end

function physics()
	local frozen=tut and
		t_stage<6
	local anchored=tut and t_stage==7 and actors[1]
	for o in all(actors) do
		if not frozen and o!=hunter and o!=anchored then
			speed_limit(o)
		end
	end
	for substep=1,4 do
		local slicing=
			phase=="slicing"
		local oldfront,newfront
		if slicing then
			oldfront=cut.front
			local f=cut.frame+
				substep/4
			newfront=cut.lo+
				(cut.hi-cut.lo)*f/12
		end
		for o in all(actors) do
			o.ox,o.oy=o.x,o.y
			if not frozen and o!=hunter and o!=anchored then
				move_actor(o)
				if o.white then
					o.slide=(o==snared and 0 or
						o.slide+length(o.x-o.ox,o.y-o.oy))%16
				end
			end
		end
		if not frozen then
			for j=1,#actors-1 do
				for k=j+1,#actors do
					collide(actors[j],
						actors[k])
				end
			end
		end
		if slicing then
			cut.front=newfront
			for o in all(actors) do
				if blade_hit(o,oldfront,
					newfront) then
					if o.white then
						burst(o.x,o.y,8,10)
						finish(false,
							"circle_hit",o)
						return
					elseif not o.hit then
						blade_push(o)
					end
				end
			end
		end
	end
end

function move_actor(o)
	if o.path then
		recover_step(o)
		return
	end
	if not fits(ice,o.x,o.y)
		and not nudge(o) then
		recover_actor(o)
		return
	end
	local dt=.25
	for impact=1,4 do
		local dx,dy=o.vx*dt,o.vy*dt
		local lo,hi=sweep(o,dx,dy)
		if lo==1 then
			o.x+=dx
			o.y+=dy
			return
		end
		local nx,ny=contact_normal(
			o.x+dx*hi,o.y+dy*hi,
			o.vx,o.vy)
		o.x+=dx*lo
		o.y+=dy*lo
		local v=o.vx*nx+o.vy*ny
		if v<0 then
			o.vx-=1.96*v*nx
			o.vy-=1.96*v*ny
		end
		shift(o,nx*.008,ny*.008)
		dt*=1-lo
		if dt<.001 then return end
	end
end

function contact_normal(x,y,
	vx,vy)
	local ds,nx,ny=clearance(
		ice,x,y)
	if ds>0 and ds<16.01 then
		local d=sqrt(ds)
		nx/=d
		ny/=d
	elseif ds>=0 then
		local d=length(vx,vy)
		nx,ny=-vx/d,-vy/d
	end
	return nx,ny
end

function collide(a,b)
	local dx,dy=b.x-a.x,
		b.y-a.y
	if abs(dx)>=8 or
		abs(dy)>=8 then return end
	local ds=dx*dx+dy*dy
	if ds>=64 then return end
	local d=sqrt(ds)
	if d<.001 then
		dx,dy,d=1,0,1
	end
	local nx,ny=dx/d,dy/d
	local v=(b.vx-a.vx)*nx+
		(b.vy-a.vy)*ny
	if v<0 then
		local impulse=-v*.97
		a.vx-=impulse*nx
		a.vy-=impulse*ny
		b.vx+=impulse*nx
		b.vy+=impulse*ny
		if v<-.8 then
			burst((a.x+b.x)/2,
				(a.y+b.y)/2,7,2)
		end
	end
	local push=(8-d)/2+.001
	local fa=shift(a,
		-nx*push,-ny*push)
	local fb=shift(b,
		nx*push,ny*push)
	if fa<1 then
		shift(b,nx*push*(1-fa),
			ny*push*(1-fa))
	end
	if fb<1 then
		shift(a,-nx*push*(1-fb),
			-ny*push*(1-fb))
	end
end

function sweep(o,dx,dy)
	if fits(ice,o.x+dx,
		o.y+dy) then
		return 1,1
	end
	local lo,hi=0,1
	for j=1,6 do
		local t=(lo+hi)/2
		if fits(ice,o.x+dx*t,
			o.y+dy*t) then
			lo=t
		else
			hi=t
		end
	end
	return lo,hi
end

function shift(o,dx,dy)
	if not tut and o==hunter then return 0 end
	local lo=sweep(o,dx,dy)
	o.x+=dx*lo
	o.y+=dy*lo
	return lo
end

function blade_push(o)
	local c=cut
	local d=normal(c,o.x,o.y)
	local v=o.vx*c.nx+
		o.vy*c.ny
	local side=sgn(d)
	if abs(d)<.0002 then
		side=sgn(v)
	end
	o.vx+=c.nx*side*1.15
	o.vy+=c.ny*side*1.15
	o.hit=true
	burst(o.x,o.y,8,3)
end

function nudge(o)
	local bx,by
	local best=2.5*2.5+.01
	for dx=-2.5,2.5,.5 do
		for dy=-2.5,2.5,.5 do
			local ds=dx*dx+dy*dy
			if ds<best and
				fits(ice,o.x+dx,
					o.y+dy) then
				best=ds
				bx,by=o.x+dx,o.y+dy
			end
		end
	end
	if not bx then
		return false
	end
	local dx,dy=bx-o.x,by-o.y
	o.x,o.y=bx,by
	if best>0 then
		local v=(o.vx*dx+
			o.vy*dy)/best
		if v<0 then
			o.vx-=1.96*v*dx
			o.vy-=1.96*v*dy
		end
	end
	return true
end

function actor_frame(o,still)
	local dx,dy=o.vx,o.vy
	still=still or (tut and
		t_stage<6) or o==snared
	if o.path and o.ox and
		(o.x!=o.ox or o.y!=o.oy)
	then
		dx,dy=o.x-o.ox,o.y-o.oy
	end
	local face=(atan2(dx,dy)*8+.5)\1%8
	local step=still and 0 or
		max(0,o.slide\2-4)
	return 4+face*4+step
end

function draw_actor(o,x,y,still)
	if o.white then
		spr(actor_frame(o,still),
			x-4,y-4)
	else
		draw_poacher(o,x,y,still)
	end
end

function burst(x,y,c,n)
	for j=1,n do
		if #fx+#debris>=32 and
			c==8 and #debris>0 then
			deli(debris)
		end
		if #fx+#debris<32 then
			local a=rnd(1)
			add(fx,record(
				[[x
y
vx
vy
life
c]],x,y,
				cos(a)*(.3+rnd(1)),
				sin(a)*(.3+rnd(1)),
				8+flr(rnd(8)),c))
		end
	end
end

function break_ice(lost,mask)
	debris={}
	local border={}
	local step=max(1,
		#lost\22)
	for j=1,#lost do
		local i=lost[j]
		local _,x,y=measure(mask,i)
		local side=sgn(
			normal(cut,x,y))
		local dx,dy=cut.nx*side,
			cut.ny*side
		for e in all(
			cell_edges(mask,i)) do
			add(e,dx)
			add(e,dy)
			add(border,e)
		end
		if (j-1)%step==0 and
			#debris<22 and
			#fx+#debris<32 then
			add(debris,record([[x
y
vx
vy
life]],x,y,dx*.65,dy*.65,16))
		end
		if j%240==0 then
			yield_work()
		end
	end
	ghosts=border
	ghostlife=16
end

function update_fx()
	ghostlife=max(0,ghostlife-1)
	for list in all({fx,debris})
	do
	for p in all(list) do
		p.life-=1
		p.x+=p.vx
		p.y+=p.vy
		if p.life<=0 then
			del(list,p)
		end
	end
	end

end

function recover_actor(o)
	local parents={}
	local _,goal=flood(ice,
		cell_at(o.x,o.y),parents,
		0,true)
	if goal then
		o.path={}
		while goal!=0 do
			add(o.path,goal)
			goal=parents[goal]
		end
	end
end

function recover_step(o)
	local i=o.path[#o.path]
	local _,x,y=measure(ice,i)
	local dx,dy=x-o.x,y-o.y
	local d=length(dx,dy)
	if d<=.5 then
		o.x,o.y=x,y
		deli(o.path)
	else
		o.x+=dx/d*.5
		o.y+=dy/d*.5
	end
	if #o.path==0 or
		fits(ice,o.x,o.y) then
		o.path=nil
		if d>.001 then
			o.vx=dx/d*.8
			o.vy=dy/d*.8
		end
	end
end
-->8

