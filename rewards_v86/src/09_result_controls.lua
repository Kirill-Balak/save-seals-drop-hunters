--result controls

function reward_icon(k,x,y)
	if k==1 then
		spr(36,x-4,y-4)
	elseif k==4 then
		draw_saw(x,y,0,1,9)
	else
		if k==3 then
			spr(132,x-10,y-5)
			spr(132,x+2,y-5,1,1,true)
		end
		spr(164,x-4,y-3)
	end
end

function action_icon(n,col)
	rect(0,0,32,11,col)
	print("\^:"..({
		"1c22f9712101221c",
		"0011337733110000",
		"007f557f557f0000"})[n],
		13,2,col)
end

function ui_button(fn,id,x,y,
	w,h,chosen)
	w-=1
	camera(-x,-y)
	fn(id,7)
	if chosen then
		rectfill(1,1,w,1,7)
		if menu_hold>0 then
			local top=h-1-
				(h-2)*menu_hold\17
			rectfill(1,top,w,h-1,7)
			clip(x+1,y+top,w,h-top)
			fn(id,0)
			clip()
		end
	end
end

function draw_result_buttons()
	local m=#menu_actions
	for n=1,m do
		local x=n*42+27-m*21+
			(victory and m==2 and 21 or 0)
		local chosen=n==menu_choice
		ui_button(action_icon,
			menu_actions[n],x,
			m==1 and state!="levelselect"
				and 100 or 116,32,11,
			chosen)
		if m>1 and chosen then
			line(13,-1,17,-1,7)
			pset(15,-2,7)
		end
	end
	camera()
end

function confirm(changed,ready)
	if not held or changed then
		menu_hold=0
	elseif ready and menu_hold>=0
	then
		menu_hold+=1
		return menu_hold>=hold_frames
	end
end
