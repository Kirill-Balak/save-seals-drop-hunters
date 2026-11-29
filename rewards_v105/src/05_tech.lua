--tech
function length(x,y)
	return sqrt(x*x+y*y)
end

function cell_xy(i)
	local z=i-1
	return 4+(z%48)*2,
		12+z\48*2
end

function cell_at(x,y)
	local u=(x-4)\2
	local v=(y-12)\2
	if u<0 or u>=48 or
		v<0 or v>=56 then
		return 0
	end
	return 1+u+v*48
end

function fits(m,x,y,r)
	r=r or 4
	return x+r<100 and y+r<124
		and not not m[cell_at(x,y)]
		and clearance(m,x,y,r)>=r*r
end

function clearance(m,x,y,r)
	local span=r or 6
	local best,nx,ny=17,0,0
	for j=(y-span-12)\2,
		(y+span-12)\2 do
		for i=(x-span-4)\2,
			(x+span-4)\2 do
			local full=i>=0 and i<48
				and j>=0 and j<56 and
				m[1+i+j*48]
			if not full then
				local cx,cy=4+i*2,12+j*2
				local dx=x-mid(cx,x,cx+2)
				local dy=y-mid(cy,y,cy+2)
				local ds=dx*dx+dy*dy
				if r and ds<r*r then
					return -1
				end
				if ds>0 and ds<best then
					best,nx,ny=ds,dx,dy
				end
			end
		end
	end
	for c in all(planes) do
		local d=normal(c,x,y)
		if d<(r or 0) then
			return -1,c.nx,c.ny
		end
		if d*d<best then
			best,nx,ny=d*d,
				c.nx*d,c.ny*d
		end
	end
	return best,nx,ny
end

function make_ice(c)
	ice={}
	local v=0
	for k=6,5+c[5]*3,3 do
		local height=c[k]
		if height==0 then
			v=c[k+1]
		else
			for j=1,height do
				for u=c[k+1],c[k+2] do
					ice[1+u+v*48]=true
				end
				v+=1
			end
		end
	end
	if state=="gameplay" then
		shape_ice()
	end
	cache_ice()
end

function shape_ice()
	local rim=split(floes[level_id])
	local x,y=rim[#rim-1],rim[#rim]
	for j=1,#rim,2 do
		local a,b=rim[j],rim[j+1]
		local nx,ny=y-b,a-x
		local d=length(nx,ny)
		add(planes,{px=x,py=y,
			nx=nx/d,ny=ny/d})
		x,y=a,b
	end
	for i in pairs(ice) do
		local base=cell_poly(ice,i)
		local p=base
		for c in all(planes) do
			p=split_cell(p,c)
			if not p then break end
		end
		ice[i]=p==base or p
	end
end

function components(m)
	local labels,tag={},0
	for i=1,2688 do
		if m[i] and not labels[i]
		then
			tag+=1
			flood(m,i,labels,tag)
		end
	end
	return labels
end

function flood(m,start,marks,
	tag,find)
	local queue={start}
	local head=1
	marks[start]=tag
	while head<=#queue do
		local i=queue[head]
		if find and m[i] then
			local _,x,y=measure(m,i)
			if fits(m,x,y) then
				return #queue,i
			end
		end
		local u=(i-1)%48
		for k in all({i-48,i+48,u>0 and i-1,u<47 and i+1}) do
			if m[k] and not marks[k] then
				local linked=m[i]==true or
					m[k]==true
				if not linked then
					local x,y=cell_xy(max(i,k))
					local dx=abs(i-k)==48
						and 2 or 0
					local dy=2-dx
					local lo,hi=0,1
					for c in all(planes) do
						lo,hi=time_clip(lo,hi,
							normal(c,x,y),
							dx*c.nx+dy*c.ny)
					end
					linked=hi>lo
				end
				if linked then
					marks[k]=find and i or tag
					add(queue,k)
				end
			end
		end
		if head%(find and 100 or
			320)==0 then
			yield_work()
		end
		head+=1
	end
	return #queue
end

function cache_ice()
	local surface,rows=ice_surface()
	for v=0,111 do
		local y=v+12
		local left,col
		local row=v\2*48
		for u=0,96 do
			local cell=ice[row+u\2+1]
			local c=u<96 and
				(cell==true or cell and fits(ice,u+4.5,y+.5,0))
				and (surface[y*128+u+4] or 12)
			if c!=col then
				if col then add(rows,{left,y,u+3,y,col}) end
				left,col=u+4,c
			end
		end
		if v%12==11 then yield_work() end
	end
	texture=rows
end

function split_cell(p,c)
	local lo,hi=32767,-32767
	for j=1,#p,2 do
		local d=normal(c,p[j],p[j+1])
		lo=min(lo,d)
		hi=max(hi,d)
	end
	if lo>=0 then return p end
	if hi<=0 then return nil,p end
	local a,b={},{}
	local x,y=p[#p-1],p[#p]
	local d=normal(c,x,y)
	for j=1,#p,2 do
		local nx,ny=p[j],p[j+1]
		local nd=normal(c,nx,ny)
		if (d>=0)!=(nd>=0) then
			local t=d/(d-nd)
			local cx,cy=x+(nx-x)*t,
				y+(ny-y)*t
			for q in all({a,b}) do
				add(q,cx)
				add(q,cy)
			end
		end
		if nd>=0 then
			add(a,nx)
			add(a,ny)
		end
		if nd<=0 then
			add(b,nx)
			add(b,ny)
		end
		x,y,d=nx,ny,nd
	end
	return a,b
end

function cell_poly(m,i)
	if m[i]!=true then
		return m[i]
	end
	local x,y=cell_xy(i)
	return {x,y,x+2,y,x+2,y+2,
		x,y+2}
end

function measure(m,i)
	local x,y=cell_xy(i)
	if m[i]==true then
		return 1,x+1,y+1
	end
	local p=m[i]
	local a,cx,cy=0,0,0
	for j=1,#p,2 do
		local k=(j+1)%#p+1
		a+=(p[j]-x)*(p[k+1]-y)-
			(p[k]-x)*(p[j+1]-y)
		cx+=p[j]*2/#p
		cy+=p[j+1]*2/#p
	end
	return max(0,a/8),cx,cy
end

function cell_edges(m,i)
	local p=cell_poly(m,i)
	local e={}
	for j=1,#p,2 do
		local k=(j+1)%#p+1
		local ax,ay=p[j],p[j+1]
		local bx,by=p[k],p[k+1]
		local dx,dy=bx-ax,by-ay
		local n=0
		if ax==bx and ax%2==0 or
			ay==by and ay%2==0 then
			n=cell_at((ax+bx)/2+
				sgn(dy)*.5,(ay+by)/2-
				sgn(dx)*.5)
		end
		if not m[n] then
			local d=length(dx,dy)
			if d>0 then
				local ox,oy=-dy/d*.5,
					dx/d*.5
				add(e,{flr(ax+ox),
					flr(ay+oy),flr(bx+ox),
					flr(by+oy)})
			end
		end
	end
	return e
end

function time_clip(lo,hi,a,b)
	if min(a,a+b)>=0 then
		return lo,hi
	end
	if max(a,a+b)<0 then
		return 1,0
	end
	if b>0 then
		lo=max(lo,-a/b)
	else
		hi=min(hi,-a/b)
	end
	return lo,hi
end

function near_path(x,y,dx,dy)
	x,y,dx,dy=x/4,y/4,dx/4,dy/4
	local ds=dx*dx+dy*dy
	local t=0
	if ds>.0001 then
		t=mid(0,-(x*dx+y*dy)/ds,1)
	end
	x+=dx*t
	y+=dy*t
	return x*x+y*y<=1
end

function blade_hit(o,f0,f1)
	local c=cut
	local x,y=o.ox-c.px,
		o.oy-c.py
	local dx,dy=o.x-o.ox,
		o.y-o.oy
	local s=x*c.tx+y*c.ty
	local n=x*c.nx+y*c.ny
	local ds=dx*c.tx+dy*c.ty
	local dn=dx*c.nx+dy*c.ny
	if near_path(s-f0,n,
		ds-(f1-f0),dn) or
		near_path(s-c.lo,n,ds,dn)
	then return true end
	local lo,hi=0,1
	lo,hi=time_clip(lo,hi,
		s-c.lo,ds)
	lo,hi=time_clip(lo,hi,
		f0-s,f1-f0-ds)
	lo,hi=time_clip(lo,hi,
		4-n,-dn)
	lo,hi=time_clip(lo,hi,
		4+n,dn)
	return lo<=hi
end
-->8

