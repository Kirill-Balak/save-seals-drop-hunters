--splash / campaign
--campaign data
levels=split([[
 4,1,1450,1740,3,4,1,0,48,
 4,43,4,1,0,39,69,.54,-.28,
 75,40,.72,.23,77,94,-.36,.68|
 5,1,1570,1890,5,2,1,0,16,
 8,39,20,4,43,16,4,39,2,1,
 0,51,67,.55,-.18,26,47,
 -.64,.35,76,38,.55,.53,
 79,62,.67,-.35,51,105,.3,
 -.69|
 5,2,1660,1910,5,2,1,0,14,
 10,43,24,2,45,14,6,39,2,1,
 0,38,52,.64,-.28,52,76,
 -.36,.48,77,31,.74,.35,
 30,104,-.64,.56,72,76,.63,
 -.51,70,100,-.55,-.6|
 5,2,1720,2040,8,14,0,47,
 3,4,47,3,7,47,4,10,47,
 5,11,47,4,9,47,4,6,47,
 19,0,47,38,44,
 .64,-.28,58,78,-.45,.48,
 25,32,.79,.35,78,32,-.68,
 .64,40,66,.71,-.58,27,104,
 -.82,-.32,77,106,.68,.44|
 6,3,2010,2350,11,12,0,47,
 3,0,44,3,0,42,3,0,40,
 3,0,42,4,0,45,5,3,47,
 4,6,47,4,7,47,4,5,47,
 11,0,47,32,32,
 .28,.64,66,62,.48,-.45,
 42,106,-.32,.58,76,24,.79,
 .35,20,30,-.68,.64,82,62,
 .71,-.58,29,78,-.82,-.32,
 73,103,.68,.44,26,106,
 -.64,.52|
 6,1,4500,7000,3,6,1,0,44,
 4,43,6,1,0,32,68,0.64,
 -0.28,76,68,-0.82,-0.32]],"|")

-- clockwise shoreline vertices
floes=split([[
 15,27,41,17,73,16,93,27,
 97,53,96,84,87,107,64,118,
 31,116,12,97,7,63|
 24,20,61,17,89,28,97,53,
 90,87,72,112,44,118,21,106,
 10,74,12,45|
 27,22,62,17,91,26,97,54,
 89,91,78,115,52,119,27,113,
 14,97,10,64,17,41|
 15,23,52,16,84,19,95,29,
 97,51,91,91,86,113,61,120,
 28,118,12,106,8,75|
 16,17,59,15,90,22,96,42,
 98,78,95,101,78,117,46,121,
 18,115,7,99,6,70,9,36]],"|")

function load_progress()
	cartdata("save_bouba_drop_kiki")
	if dget(0)==0 then dset(0,3) end
	trained=dget(27)
	unlocked=mid(1,
		flr(dget(25)),5)
	selected=mid(1,
		flr(dget(26)),unlocked)
	save_progress()
end

function save_progress()
	dset(27,trained)
	dset(25,unlocked)
	dset(26,selected)
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
	local art=ice_art[state=="tutorial" and 6 or level_id]
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
			n=(n+3)%5+1
		elseif btnp(1) then
			n=n%5+1
		end
		if confirm(n!=selected,
			n<=unlocked) then
			start_level(n)
		end
		if selected!=n then
			selected=n
			dset(26,n)
		end
	end,
	draw=function()
		local total=0
		for n=1,5 do
			total+=dget(32+n)
		end
		print(total.."/15",51,5,7)
		small_star(74,7,7,true)
		for id=1,5 do
			local x=1+(id-1)%5*25
			local y=48
			ui_button(level_icon,id,x,y,
				24,32,id==selected)
		end
		camera()
		local stars,best=
			dget(32+selected),
			dget(27+selected)
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
				col,j<=dget(32+id))
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
