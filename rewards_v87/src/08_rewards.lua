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
		local i=27+level_id
		new_record=score>dget(i)
		best_score=max(dget(i),score)
		dset(i,best_score)
		dset(i+5,max(dget(i+5),
			result.stars))
		unlocked=max(unlocked,
			min(5,level_id+1))
		dset(24,charge)
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

function draw_results()
	local t=ending-result_delay
	local v,total=result_values(t)
	for j=1,3 do
		local age=t-(48+j*6)
		local full=j<=result.stars
			and age>=0
		victory_star(j,j*36-8,11,age,full)
	end
	draw_star_meter(total)
	local s=tostr(total)
	print("\^w\^t"..s,
		64-#s*4,42,7)
	local best=tostr(best_score)
	local bx=68-#best*2
	local bc=new_record and 9 or 12
	print("\^:496b7f3e3e000000",
		bx-10,54,bc)
	print(best,bx,55,bc)
	line(10,63,117,63,12)
	for j=1,4 do
		local y=58+j*12
		reward_icon(j,22,y)
		if j%2==0 then
			print("\^:0005020500000000\-e"..
				(j==2 and solo_kills
					or shots),
				41,y-2,12)
		end
		local s="+"..v[j]
		print(s,117-#s*4,y-2,
			j==3 and 9 or 7)
		if j<4 then
			line(10,y+6,117,y+6,12)
		end
	end
	if t>=78 then
		draw_result_buttons()
	end
end

function star_position(s)
	local t2=mid(1,star_two,30000)
	local t3=max(t2+1,star_three)
	return 28+36*mid(0,s/t2,1)+
		36*mid(0,(s-t2)/(t3-t2),1)
end

function draw_star_meter(total)
	rect(28,28,100,31,12)
	local fill=star_position(total)
	if total>0 then
		rectfill(28,29,fill,30,12)
	end
	for j=2,3 do
		local target=j==2 and
			star_two or star_three
		local x=j*36-8
		local c=total>=target
			and 9 or 7
		local s=tostr(target)
		line(x,26,x,32,c)
		print(s,x-#s*2,34,c)
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
	if end_reason=="out_of_cuts" then
		draw_saw(57,40,0,1,7)
		print("\^w\^t0",72,35,8)
	elseif end_reason=="harpoon" then
		line(46,40,80,40,9)
		spr(28,42,36)
		spr(132,76,36)
		line(84,40,96,40,8)
		line(93,37,96,40,8)
		line(93,43,96,40,8)
	else
		local split=end_reason==
			"circle_split"
		for j=1,split and 2 or 1 do
			local x=split and 12+j*32 or 60
			spr(28,x,36)
		end
		if split then
			line(64,22,64,58,8)
		else
			line(48,55,80,25,8)
		end
	end
	draw_result_buttons()
end
-->8
