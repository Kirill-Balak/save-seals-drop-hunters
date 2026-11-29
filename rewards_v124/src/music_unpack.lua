for i=0,@last do
 local a=13480+i*68
 local b=16132+i\4*68+i%4*16
 memset(a+12,0,52)
 memcpy(a,b,12)
 memcpy(a+64,b+12,4)
end
