local down=btn(4)
local request=o_pending or down and not o_down
o_down=down
local place_now=placing and fresh
if not placing then
	o_pending=request and charge==3
		and magnet==0 and not snared
	if not (o_pending and phase=="aim" and charge_shown==3) then return end
	o_pending=nil
