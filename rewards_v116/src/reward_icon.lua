function reward_icon(k,x,y)
	if k==1 then
		spr(36,x-4,y-4)
	elseif k==4 then
		draw_saw(x,y,0,9)
	elseif k==3 then
		spr(132,x-10,y-5)
		spr(132,x+2,y-5,1,1,true)
		print("\^:00000054387c3854",
			x-4,y-5,7)
	else
		spr(164,x-4,y-3)
	end
end
