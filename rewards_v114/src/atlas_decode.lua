local q=tail
for i=dict+16,j-1 do
 local b=peek(i)
 poke(q,peek(dict+b%16),
  peek(dict+b\16))
 q+=2
end
