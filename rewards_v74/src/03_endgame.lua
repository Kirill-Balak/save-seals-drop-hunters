--endgame
gamestate.endgame={
	init=function()
		ending=0
		victory=outcome=="win"
		result_delay=
			victory and 16 or 24
		menu_hold=-1
		menu_actions=split(
			((level_id>1 or unlocked>=3)
				and "3," or "")..
			(victory and "1,2" or "1"))
		menu_choice=#menu_actions
	end,
	update=function()
		if end_reason=="harpoon" and ending<result_delay then haul_away() end
		local last=result_delay+
			(victory and 78
				or 0)
		local ready=ending>=last
		ending=min(ending+1,last)
		if fresh and not ready and
			ending>=result_delay then
			ending=last
			menu_hold=-1
			return
		end
		local old=menu_choice
		menu_choice=mid(1,
			menu_choice+(btnp(1) and 1
				or btnp(0) and -1 or 0),
			#menu_actions)
		if confirm(menu_choice!=old,
			ready)
		then
			local action=({retry_level,
				continue_level,open_levels})[
				menu_actions[menu_choice]]
			action()
		end
	end,
	draw=function()
		if end_screen() then
			if victory then
				draw_results()
			else draw_loss() end
		else
			draw_scene()
			if outcome=="lose" then
				draw_failure()
			end
		end
	end
}

function end_screen()
	return outcome and ending>=result_delay
end

function retry_level()
	start_level(level_id)
end

function continue_level()
	if level_id<5 then
		start_level(level_id+1)
	else open_levels() end
end
-->8
