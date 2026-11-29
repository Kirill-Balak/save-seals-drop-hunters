local function read_bytes(a,n)
 local data=''
 for x=0,n-1,256 do
  data..=chr(peek(a+x,
   min(n-x,256)))
 end
 return data
end

-- unpack sprite rows
local shapes=@shapes
local ram=@ram
local tail=ram
for i=1,#shapes,3 do
 local a,w,h=unpack(shapes,
  i,i+2)
 for y=0,h-1 do
  memcpy(tail,a+y*64,w)
  tail+=w
 end
end
local dict=ram+@sfx
local j=dict+@dict
for i=1,#shapes,3 do
 local a,w,h=unpack(shapes,
  i,i+2)
 for y=0,h-1 do
  for x=0,w-1,4 do
   memcpy(a+y*64+x,
    dict+4*peek(j),4)
   j+=1
  end
 end
end
