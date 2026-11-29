--splash / campaign
--campaign data

function load_progress()
	cartdata("seal_drift_campaign")
	trained=dget(0)
	unlocked=mid(1,flr(dget(1)),level_count)
	selected=mid(1,flr(dget(2)),unlocked)
	save_progress()
end

function score_slot(id)
	return 3+id
end

function save_progress()
	dset(0,trained)
	dset(1,unlocked)
	dset(2,selected)
end

function start_level(id)
	level_id=id
	selected=id
	save_progress()
	set_state("gameplay")
end

function open_levels()
	if state!=
		"levelselect" then
	set_state("levelselect")
	end
end

function crack_pixel(p,older,c,x,y,d,a)
	local u=flr(x+c.nx*d+c.tx*a)
	local v=flr(y+c.ny*d+c.ty*a)
	if u>=4 and u<100 and v>=12 and v<124 then
		local key=v*128+u
		if older[key]==13 then return fits(ice,u+.5,v+.5,0) end
		p[key]=13
	end
end

function cut_cracks(c,older)
	local p={}
	local next_root=c.lo
	-- Stable mix along each cut,
	-- independent of game rng.
	local style=(c.px+c.py)\1%5
	for s=c.lo+1,c.hi-1,2 do
		if s>=next_root then
			local x=c.px+c.tx*s
			local y=c.py+c.ty*s
			if fits(ice,x+c.nx,y+c.ny,0)
				and fits(ice,x+4*c.nx,y+4*c.ny,0) then
				next_root=s+25
				local sign=style%2*2-1
				local elbow=2+style%3
				local lean=style*.25-.4
				local joint,fork_joint
				for j=0,10+style*4 do
					local d=j*.5
					local side=min(d,elbow)*lean-max(0,d-elbow)*.85+
						max(0,d-elbow-2)*style*.45
					if joint then side+=(d-joint)*.55 end
					if crack_pixel(p,older,c,x,y,d,side*sign) then
						joint=joint or d
					end
					if style>=3 and d>=elbow and d<7 then
						local branch=elbow*lean+(d-elbow)*1.25
						if joint and joint<elbow then
							branch+=(elbow-joint)*.55
						end
						if fork_joint then branch-=(d-fork_joint)*.45 end
						if crack_pixel(p,older,c,x,y,d,branch*sign) then
							fork_joint=fork_joint or d
						end
					end
				end
				style=(style+3)%5
			end
		end
	end
	return p
end

function ice_surface()
	local surface,rows={},{}
	local art=ice_art[state=="tutorial" and 6 or level_art[level_id]]
	for shape in all(split(art,"!",false)) do
		local p={}
		for batch in all(split(shape,"\n",false)) do
			for i=1,#batch do
				local byte=ord(batch,i)
				if byte>=40 then add(p,byte-40) end
			end
		end
		if p[1]==7 then
			for i=2,#p,3 do
				local x,y,last=p[i],p[i+1],p[i+2]
				for u=x,last do surface[y*128+u]=7 end
			end
		else
			for i=2,#p,2 do
				local x,y=p[i],p[i+1]
				add(rows,{x,y,x,y,12})
			end
		end
	end
	for c in all(planes) do
		if c.tx then
			c.scars=c.scars or cut_cracks(c,surface)
			for k in pairs(c.scars) do surface[k]=13 end
		end
	end
	return surface,rows
end

gamestate.levelselect={
	init=function()
		level_menu()
		menu_hold=-1
		held=btn(5)
	end,
	update=function()
		local n=selected
		if btnp(0) then
			n=(n+level_count-2)%level_count+1
		elseif btnp(1) then
			n=n%level_count+1
		elseif btnp(2) or btnp(3) then
			n=(n+4)%level_count+1
		end
		if confirm(n!=selected,
			n<=unlocked) then
			start_level(n)
		end
		if selected!=n then
			selected=n
			dset(2,n)
		end
	end,
	draw=function()
		local total=0
		for n=1,level_count do
			total+=dget(score_slot(n)+10)
		end
		print(total.."/"..level_count*3,51,5,7)
		small_star(74,7,7,true)
		for id=1,level_count do
			local x=1+(id-1)%5*25
			local y=24+(id-1)\5*37
			ui_button(level_icon,id,x,y,
				24,32,id==selected)
		end
		camera()
		local slot=score_slot(selected)
		local stars,best=dget(slot+10),dget(slot)
		if stars>0 then
			print("\^:496b7f3e3e000000"..
				best,5,98,7)
			if stars<3 then
				local need=max(0,
					split(levels[selected])[stars+2]-
				best)
				local x=107-#tostr(need)*4
				print(need,x,98,7)
				goal_arrow(109,98)
				small_star(120,100,7)
			end
		end
		print("❎",60,118,7)
	end
}

function level_icon(id,col)
	print(id,12-#tostr(id)*2,
		5,col)
	if id>unlocked then
		fillp(0xa5a5)
	end
	rect(0,0,24,32,col)
	fillp()
	if id<=unlocked then
		for j=1,3 do
			small_star(j*7-2,22+j%2*2,
				col,j<=dget(score_slot(id)+10))
		end
	else
		rect(8,12,16,18,7)
		rectfill(6,16,18,24,7)
		pset(12,19,0)
		line(12,20,12,22,0)
	end
end

function small_star(x,y,c,full)
	print(full and "★" or
		"\^:0814633622000000",
		x-3,y-2,full and 9 or c)
end

function goal_arrow(x,y)
	line(x,y+2,x+6,y+2,7)
	line(x+6,y+2,x+4,y,7)
	line(x+6,y+2,x+4,y+4,7)
end

-->8
