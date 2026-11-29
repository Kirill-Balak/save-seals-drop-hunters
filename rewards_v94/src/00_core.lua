--seal drift
--kirill balak
--core
gamestate={}

function set_state(name)
	sfx(-1,0)
	state=name
	gamestate[name]:init()
end

function _init()
	load_progress()
	-- Screen inks: navy, ice,
	-- white, red and orange.
	poke(0x5f10,
		1,1,8,12,9,1,12,7,
		8,9,9,12,12,1,8,7)
	menuitem(0x302,"⬅️➡️",function()
		set_state("tutorial")
	end)
	set_state(trained==1 and
		"levelselect" or "tutorial")
end

function level_menu()
	menuitem(0x301,"★",
		open_levels)
end

function _update()
	fresh=btn(5) and not held
	held=btn(5)
	if (state=="gameplay" or
		state=="tutorial" and t_stage==7) and
		magnet_input() then return end
	if state!="levelselect" then
		tick=(tick+1)%30000
		update_fx()
		update_scorefx()
	end
	gamestate[state]:update()
end

function _draw()
	cls()
	gamestate[
		state
	]:draw()
	if state!=
		"levelselect" and
		not end_screen() then
		draw_controls()
		if outcome!="lose" then
			draw_scorefx()
		end
	end
end

function record(names,...)
	local r={}
	for j,k in ipairs(
		split(names,"\n")) do
		r[k]=select(j,...)
	end
	return r
end
-->8

