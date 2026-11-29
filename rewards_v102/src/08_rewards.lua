-->8
--rewards
reward_cell,reward_kill,
	reward_cut,hold_frames=
	unpack(split[[
 1,100,150,18]])

function reset_fields(names,v)
	for k in all(split(names,"\n")) do
		_ENV[k]=v or {}
	end
end

function award_enemies(n,x,y)
	if not cut.enemy_paid then
	cut.enemy_paid=true
	if n>0 then
	local points=reward_kill*n+50*(n-1)
	score+=points
	local k=3
	if n==1 then
		solo_kills+=1
		kill_points+=points
		k=2
	else
		combo_points+=points
		burst(x,y,7,6)
	end
	score_flight(points,k,x,y)
	end
	end
end

function seal_result(won)
	if not result then
	if won then
		remaining_cut_points=
			shots*reward_cut
		score+=remaining_cut_points
	end
	result=record([[total
area
kills
combo
cuts
stars]],score,
		area_points,kill_points,
		combo_points,
		remaining_cut_points,
		won and
			(score>=star_three and 3 or
				score>=star_two and 2
				or 1)
			or 0)
	if won then
		local i=score_slot(level_id)
		new_record=score>dget(i)
		best_score=max(dget(i),score)
		dset(i,best_score)
		dset(i+10,max(dget(i+10),
			result.stars))
		unlocked=max(unlocked,
			min(level_count,level_id+1))
		dset(3,charge)
		save_progress()
	end
	end
end

function result_values(t)
	local v,total={result.area,
		result.kills,result.combo,
		result.cuts},0
	for j=1,4 do
		v[j]=flr(v[j]*
			ease((t+8)/12-j))
		total+=v[j]
	end
	return v,total
end

function blue_result_buttons()
	pal(7,1)
	pal(0,12)
	draw_result_buttons()
	pal(0,0)
	pal(7,7)
end

function draw_results()
	cls(12)
	local t=ending-result_delay
	local v,total=result_values(t)
	pal(12,1)
	for j=1,3 do
		local age=t-(48+j*6)
		local full=j<=result.stars
			and age>=0
		local x=j*36-8
		if full then
			pal(9,1)
			for i=0,3 do
				victory_star(j,x+cos(i/4),
					11+sin(i/4),age,true)
			end
			pal(9,9)
		end
		victory_star(j,x,11,age,full)
	end
	pal(12,12)
	draw_star_meter(total)
	local s=tostr(total)
	print("\^w\^t"..s,
		64-#s*4,42,1)
	local best=tostr(best_score)
	local bx=68-#best*2
	local bc=new_record and 9 or 1
	print("\^:496b7f3e3e000000",
		bx-10,54,bc)
	print(best,bx,55,1)
	line(10,63,117,63,1)
	for j=1,4 do
		local y=58+j*12
		if j==1 then pal(12,1) end
		reward_icon(j,22,y)
		if j==1 then pal(12,12) end
		if j%2==0 then
			print("\^:0005020500000000\-e"..
				(j==2 and solo_kills
					or shots),
				41,y-2,1)
		end
		local s="+"..v[j]
		print(s,117-#s*4,y-2,1)
		if j<4 then
			line(10,y+6,117,y+6,1)
		end
	end
	if t>=78 then
		blue_result_buttons()
	end
end

function star_position(s)
	local t2=mid(1,star_two,30000)
	local t3=max(t2+1,star_three)
	return 28+36*mid(0,s/t2,1)+
		36*mid(0,(s-t2)/(t3-t2),1)
end

function draw_star_meter(total)
	rect(28,28,100,31,1)
	local fill=star_position(total)
	fill=min(99,flr(fill))
	if fill>=29 then
		rectfill(29,29,fill,30,9)
	end
	for j=2,3 do
		local target=j==2 and
			star_two or star_three
		local x=j*36-8
		local s=tostr(target)
		line(x,26,x,32,1)
		print(s,x-#s*2,34,1)
	end
end

function draw_failure()
	local col=ending%6<3 and 8
		or 7
	if end_reason=="out_of_cuts" or end_reason=="harpoon"
	then return end
	if end_reason=="circle_split"
	then
		blade_line(cut,cut.lo,
			cut.hi,col)
	end
	for p in all(end_event) do
		circfill(p.x,p.y,4,col)
		circ(p.x,p.y,
			5+ending%12,col)
	end
end

function draw_loss()
	cls(12)
	if end_reason=="out_of_cuts" then
		draw_saw(57,40,0,1,7)
		print("\^w\^t0",72,35,1)
	elseif end_reason=="harpoon" then
		line(46,40,80,40,1)
		spr(28,42,36)
		spr(132,76,36)
		line(84,40,96,40,1)
		line(93,37,96,40,1)
		line(93,43,96,40,1)
	else
		local split=end_reason==
			"circle_split"
		for j=1,split and 2 or 1 do
			local x=split and 12+j*32 or 60
			spr(28,x,36)
		end
		if split then
			line(64,22,64,58,1)
		else
			line(48,55,80,25,1)
		end
	end
	blue_result_buttons()
end
-->8
