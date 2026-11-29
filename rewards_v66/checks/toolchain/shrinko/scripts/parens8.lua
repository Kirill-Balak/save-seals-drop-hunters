-- (see README for usage info)
--$lint: python, shrinko, string, rommemcpy

-- reasonably compact, extremely flexible
function serialize(value)
	local refs, refid = {}, 1

	local function ctl(idx, v, full)
		local inline = v & 63
		if (inline ~= v) inline = 63
		return chr(inline << 2 | idx) .. (inline == 63 and full or "")
	end

	local function short(v) return chr(v, v >>> 8) end
	local function word(v) return chr(v << 16, v << 8) .. short(v) end

	local function dive(v)
		local function addref()
			refs[v] = '\19' .. short(refid)
			refid += 1
		end

		return v == nil and '\15' or refs[v] or (({
			boolean = function() return v and '\7' or '\11' end,
			number = function() return ctl(0, v+31, word(v)) end,
			string = function()
				addref()
				local slices = split(v, 0x4000, false)
				local len = slices[1]
					and (#deli(slices) >>> 16) + (#slices >>> 2) or 0
				return ctl(1, len <<> 16, word(len)) .. v
			end,
			table = function()
				addref()
				local arr, res = #v > 0 and #v
				if arr then
					res = ctl(2, arr, short(arr))
					for i=1,arr do
						res ..= dive(v[i])
					end
					for k, e in next, v do
						if mid(k, arr, 1) ~= k then
							res ..= dive(k) .. dive(e)
						end
					end
				else
					res = '\23'
					for k, e in next, v do
						res ..= dive(k) .. dive(e)
					end
				end
				return res .. '\15'
			end,
		})[type(v)] or const'\15')()
	end
	return dive(value)
end

-- 104 tokens
local deserializer_flat = [[
function `funcname`(data)
	local pos = 0
	local function byte()
		pos += 1
		return ord(data, pos)
	end
	local function word()
		return byte() >>> 16 | byte() >>> 8 | byte() | byte() << 8
	end
	return function()
		local ctl, v = byte()
		v, ctl = ctl&252 ~= 252 and ctl>>>2&63, ctl%4
		if (ctl == 0) return v and v-31 or word()
		if (ctl == 3) return ({true, false})[v]
		local len = v or word()<<16
		pos += len
		return sub(data, pos-len+1, pos)
	end
end

]]

-- 168 tokens
local deserializer_flat_bs = [[
function `funcname`(data)
	data = all(split(data, 0x4000, false))
	local pos, chunk = 0x4000

	local function advance()
		if (pos == 0x4000) chunk, pos = data(), 0
	end
	local function byte()
		advance()
		pos += 1
		return ord(chunk, pos)
	end

	local function word()
		return byte() >>> 16 | byte() >>> 8 | byte() | byte() << 8
	end
	return function()
		local ctl, v = byte()
		v, ctl = ctl&252 ~= 252 and ctl>>>2&63, ctl%4
		if (ctl == 0) return v and v-31 or word()
		if (ctl == 3) return ({true, false})[v]
		local len, res = v and v>>>16 or word(), ""
		repeat
			advance()
			local consumed = min(len, 0x4000-pos>>>16)<<16
			res ..= sub(chunk, pos+1, pos+consumed)
			pos += consumed
			len -= consumed>>16
		until len <= 0
		return res
	end
end

]]

-- 264 tokens
local deserializer_full = [[
function `funcname`(data)
	data = all(split(data, 0x4000, false))
	local pos, refs, chunk = 0x4000, {}

	local function advance()
		if (pos == 0x4000) chunk, pos = data(), 0
	end
	local function byte()
		advance()
		pos += 1
		return ord(chunk, pos)
	end
	local function short() return byte() | byte() << 8 end
	local function word() return byte() >>> 16 | byte() >>> 8 | short() end
	
	local function dive()
		local function hash(res)
			res = res or add(refs, {})
			for k,v in function()
				local key = dive()
				return key, key ~= nil and dive()
			end do res[k] = v end
			return res
		end

		local ctl = byte()
		local v = ctl&252 ~= 252 and ctl>>>2&63
		return select(ctl%4+1,
			function()
				return v and v-31 or word()
			end,
			function()
				local len, res = v and v>>>16 or word(), ""
				repeat
					advance()
					local consumed = min(len, 0x4000-pos>>>16)<<16
					res ..= sub(chunk, pos+1, pos+consumed)
					pos += consumed
					len -= consumed>>16
				until len <= 0
				return add(refs, res)
			end,
			function()
				local res = add(refs, {})
				for i=1,v or short() do res[i] = dive() end
				return hash(res)
			end,
			function()
				return select(v,
					const(true), const(false), const(),
					function()
						local id = short()
						return refs[id]
					end,
					hash)()
			end)()
	end

	return dive
end

]]
--[[
copyright 2026 wellspring-labs

this program is free software: you can redistribute it and/or modify it under the terms of the AGPL, version 3 or later.
you should have received a copy of the AGPLv3 along with this program. if not, see <https://www.gnu.org/licenses/>. 
]]

function id(...) return ... end
function const(x) return function() return x end end
function compose(a, b) return function(...) return a(b(...)) end end
function bind(f, v) return function(...) return f(v, ...) end end
function call(f, ...) return f(...) end

function defer(fn, ...)
	fn()
	return ...
end

function fold(op, acc, head, ...)
	if head then return fold(op, op(acc, head), ...) end
	return acc
end

function foldr(op, a, b, ...)
	if b then return op(a, foldr(op, b, ...)) end
	return a
end

function fmap(fn, head, ...)
	if head ~= nil then return fn(head), fmap(fn, ...) end
end

function iota(a, b)
	if a < b then return a, iota(a + 1, b) end
	return a
end

function reverse(h, ...)
	local function impl(f, h, ...)
		if h then return impl(function() return h, f() end, ...) end
		return f()
	end
	return impl(function() return h end, ...)
end

function fallback(default)
	return function(o)
		return setmetatable(o, {__index = default})
	end
end

function format(str, args)
	str = split(str, "`")
	local out = str[1]
	for i=2,#str,2 do
		out ..= args[str[i]] .. (str[i+1] or "")
	end
	return out
end

function join(arr, sep)
	local it = all(arr)
	local res = it()
	for elem in it do res ..= sep .. elem end
	return res
end

splat = compose(unpack, split)

function backpatch(tab, values)
	for k,v in pairs(values) do tab[k] = v end
end

local fp_boilerplate, vm_template =
[[
function `funcname`(x) return function() return x end end

]], [=[
do
local ps8_ops, ps8_argc = {function()
	local a = ps8_val()
	return function() return ps8_inst[a] end
end}, split"`argcounts`"

function run_ps8(bytecode)
	ps8_inst, ps8_val, ps8_binder =
		{}, `deserializer`(bytecode),
		function() ps8_inst, ps8_val, ps8_binder = nil end
	return ps8_ops[ps8_val()]()(ps8_binder())()(_ENV)
end

local function ps8_runtime(a, b, c)
	local step = ps8_binder
	function ps8_binder()
		a, b, c = a(), b(), c()
		return step()
	end
	return `runtime_ops`
end

for i,n in inext, split"`compiled_args`" do
	local function arg(p)
		return p < n
			and ps8_ops[ps8_val()]()
			or `const`(p < ps8_argc[i] and ps8_val())
	end
	add(ps8_ops, function()
		return `const`(add(ps8_inst, (select(i,
			ps8_runtime(arg(0), arg(1), arg(2))))))
	end)
end
end
]=]

local opidx, opcodes, ops, is_op, vm_ops = 1, {jmp = 1}, {}, {}, {}

for line in all(split([[
jmp
frame`0`0`function(f)return f end
lit`0`1`function()return a end
null`0`0`function()end
vdc_direct`0`1`function(f)return unpack(f,a)end
vdc_sparse`0`1`function(f)return unpack(f,a,f.n)end
field`1`2`function(f)return a(f)[b]end
at`2`2`function(f)return a(f)[b(f)]end
set_field`2`3`function(f)a(f)[c]=b(f)end
set_at`3`3`function(f)a(f)[b(f)]=c(f)end
call`2`2`function(f)return a(f)(b(f))end
method`2`3`function(f)local o=a(f)return o[c](o, b(f))end
multival`2`2`function(f)return a(f),b(f)end
seq`2`2`function(f)a(f)return b(f)end
collapse`1`1`function(f)return(a(f))end
when`3`3`function(f)if a(f)then return b(f)end return c(f)end
add`2`2`function(...)return a(...)+b(...)end
sub`2`2`function(...)return a(...)-b(...)end
mul`2`2`function(...)return a(...)*b(...)end
div`2`2`function(...)return a(...)/b(...)end
idiv`2`2`function(...)return a(...)\b(...)end
mod`2`2`function(...)return a(...)%b(...)end
pow`2`2`function(...)return a(...)^b(...)end
cat`2`2`function(...)return a(...)..b(...)end
band`2`2`function(...)return a(...)&b(...)end
bor`2`2`function(...)return a(...)|b(...)end
bxor`2`2`function(...)return a(...)^^b(...)end
shl`2`2`function(...)return a(...)<<b(...)end
shr`2`2`function(...)return a(...)>>b(...)end
lshr`2`2`function(...)return a(...)>>>b(...)end
rotl`2`2`function(...)return a(...)<<>b(...)end
rotr`2`2`function(...)return a(...)>><b(...)end
inplace`3`3`function(f)local t,k=a(f),b(f)t[k]=c(f,t[k])end
inplace_pull`0`0`function(f,v)return v end
bnot`1`1`function(f)return ~a(f)end
unm`1`1`function(f)return -a(f)end
len`1`1`function(f)return #a(f)end
peek`1`1`function(f)return @a(f)end
peek2`1`1`function(f)return %a(f)end
peek4`1`1`function(f)return $a(f)end
union`2`2`function(f)return a(f)or b(f)end
inter`2`2`function(f)return a(f)and b(f)end
inv`1`1`function(f)return not a(f)end
eq`2`2`function(f)return a(f)==b(f)end
neq`2`2`function(f)return a(f)~=b(f)end
gt`2`2`function(f)return a(f)>b(f)end
lt`2`2`function(f)return a(f)<b(f)end
ge`2`2`function(f)return a(f)>=b(f)end
le`2`2`function(f)return a(f)<=b(f)end
read_direct`0`1`function(f)return f[a]end
read_indirect`0`2`function(f)return f[a][b]end
write_direct`1`2`function(f)f[b]=a(f)end
write_indirect`1`3`function(f)f[b][c]=a(f)end
fn`2`2`function(f)local u={__index=a({}, f)}return function(...)return b(setmetatable({...},u))end end
fn_sparse`2`2`function(f)local u={__index=a({}, f)}return function(...)return b(setmetatable(pack(...),u))end end
push_frame`2`3`function(f)f[c]={a(f)}return b(f)end
push_upval`1`3`function(t,f)t[b]=f[c]return a(t,f)end
arr`1`1`function(f)return{a(f)}end
tab_ctor`2`2`function(f)return a({b(f)},f)end
tab_entry`3`3`function(t,f)t[a(f)]=b(f)return c(t,f)end
for_setup`2`2`function(f)return a(f,b(f))end
num_for`2`3`function(f,l,h,s)for i=l,h,s do f[c]={i}local e=a(f)if(e)return e(f)end return b(f)end
gen_for`2`3`function(f,...)for i,j in...do f[c]={i,j}local e=a(f)if(e)return e(f)end return b(f)end
exit`1`1`function()return a end
]], "\n"))
do
	local name, compiled_args, total_args, impl = splat(line, "`")
	ops[name] = function(...)
		if not opcodes[name] then
			vm_ops[opidx] = {compiled_args, impl, name, total_args}
			opidx = opidx + 1
			opcodes[name] = opidx
		end
		return {opcodes[name], ...}
	end
	is_op[name] = function(inst)
		return opcodes[name] and inst[1] == opcodes[name]
	end
end

mklit = compose(const, ops.lit)

function translate_opcode(op)
	op = op[1]
	if op == 1 then return "jmp" end
	return vm_ops[op - 1][3]
end

local vm_defaults = fallback{
	filename = "ps8_vm.p8l",
	fp_boilerplate = fp_boilerplate,
	const_funcname = "ps8_const",
	deserializer = deserializer_flat,
	deserializer_funcname = "ps8_decoder",
	vm_operations = vm_ops,
	vm_template = vm_template,

	-- if you wish to remove the license notice from the resulting cart,
	-- you must make the parens-8 license (AGPLv3) available to users.
	-- you must also make the code you fed to the parens-8 compiler available,
	-- regardless of whether or not this license notice is removed/disabled.
	license = [=[
--[[
parens-8 v5 vm, copyright 2026 wellspring-labs

this program is free software: you can redistribute it and/or modify it under the terms of the AGPL, version 3 or later.
you should have received a copy of the AGPLv3 along with this program. if not, see <https://www.gnu.org/licenses/>. 
]]

]=]
}

function generate_ps8_vm(options)
	options = vm_defaults(options or {})
	local generated = options.license or ""
	if options.fp_boilerplate then
		generated ..= format(
			options.fp_boilerplate,
			{funcname = options.const_funcname})
	end
	if options.deserializer then
		generated ..= format(
			options.deserializer,
			{funcname = options.deserializer_funcname,
			 const = options.const_funcname})
	end

	local opfuncs, compiled_args, argcounts = {}, {}, {}

	for opcode, vm_op in ipairs(options.vm_operations) do
		compiled_args[opcode] = vm_op[1]
		opfuncs[opcode] = vm_op[2]
		argcounts[opcode] = vm_op[4]
	end

	generated ..= format(options.vm_template, {
		deserializer = options.deserializer_funcname,
		const = options.const_funcname,
		compiled_args = join(compiled_args, ","),
		argcounts = join(argcounts, ","),
		runtime_ops = join(opfuncs, ",\n")
	})

	printh(generated, options.filename, true)
end

local function instruction_cache()
	local paths, values = {}, {}

	local function find(lkp, head, ...)
		if head == nil then return values[lkp] end
		local nxt = lkp[head]
		if nxt then return find(nxt, ...) end
	end

	local function record(inst, lkp, head, ...)
		if head == nil then
			values[lkp] = inst
		else
			lkp[head] = record(inst, lkp[head] or {}, ...)
		end
		return lkp
	end

	return function(inst)
		local found = find(paths, unpack(inst))
		if found then return found end
		record(inst, paths, unpack(inst))
		return inst
	end
end

-- compiler emitted instructions may be referenced in multiple points
-- in fact, we *want* to use references wherever possible (less vm memory usage)
-- but the vm needs flat *positional* references, based on traversal order
-- also this takes care of deduplication and flattening
function post_process(fir, options)
	local vmops, res = options.vmops or vm_ops, ""
	local inst_pos, jmp, dedup, dedup_pass, cache, traversed, press
		= 0, {id}, {id}, {}, instruction_cache(), {}, {
			function(op, a) res ..= serialize(op) .. serialize(a) end}

	local function rewire(ops, n, a, ...)
		if n > 0 then return ops[a[1]](a), rewire(ops, n - 1, ...) end
		return a, ...
	end

	for _opcode, vm_op in ipairs(vmops) do
		add(dedup, function(inst)
			if traversed[inst] then return traversed[inst] end
			local res = {}
			traversed[inst] = res
			backpatch(res, {
				inst[1], rewire(dedup, vm_op[1], unpack(inst, 2))})
			add(dedup_pass, function()
				for i=2,vm_op[1]+1 do
					res[i] = cache(res[i])
				end
			end)
			return res
		end)
		add(jmp, function(inst)
			if traversed[inst] then return traversed[inst] end
			traversed[inst] = {}
			local res = {
				inst[1], rewire(jmp, vm_op[1], unpack(inst, 2))}
			inst_pos = inst_pos + 1
			backpatch(traversed[inst], ops.jmp(inst_pos))
			return res
		end)

		local function arg(p, val)
			if (p < vm_op[1]) return press[val[1]](unpack(val))
			if (p < vm_op[4]) res ..= serialize(val)
		end
		add(press, function(op, a, b, c)
			res ..= serialize(op)
			arg(0, a)
			arg(1, b)
			return arg(2, c)
		end)
	end

	if not options.disable_dedup then
		fir = rewire(dedup, 1, fir)
		foreach(dedup_pass, call)
		traversed, cache = {}
	end

	fir, traversed = rewire(jmp, 1, fir)
	press[fir[1]](unpack(fir))

	return res
end

-- full cleanup saves about 10KiB, but prevents further loading
vm_cleanup_full = split"run_ps8"
--[[
copyright 2026 wellspring-labs

this program is free software: you can redistribute it and/or modify it under the terms of the AGPL, version 3 or later.
you should have received a copy of the AGPLv3 along with this program. if not, see <https://www.gnu.org/licenses/>. 
]]

compile_bytecode = compose(post_process, function(ast, options)
	-- fallback{}(options)

	local null = const(ops.null())

	local builtin_exp, builtin_smt, deferred_pass = {}, {}, {}
	local function deferred(emit)
		local op = {}
		add(deferred_pass, function()
			backpatch(op, emit())
		end)
		return op
	end

	local function forbid(message)
		return function() assert(false, message) end
	end

	local function make_ctx(ctx)
		function ctx.var(name, write, emit)
			return ctx.mark(name, write) and deferred(function()
				return emit(ctx.resolve(name))
			end)
		end

		function ctx.derive(overrides)
			overrides.labels = fallback(ctx.labels){}
			return make_ctx(fallback(ctx)(overrides))
		end

		return ctx
	end

	local function compile_exp(ctx, exp)
		if type(exp) == "function" then return exp(ctx) end
		if type(exp) == "string" then
			return builtin_exp.fetch(ctx, exp)
		end
		return (function(op, ...)
			if builtin_exp[op] then
				return builtin_exp[op](ctx, ...)
			end
			return builtin_exp.call(ctx, op, ...)
		end)(unpack(exp))
	end

	local function compile_n(ctx, exp, ...)
		if exp then
			return compile_exp(ctx, exp), compile_n(ctx, ...)
		end
	end

	-- k is a static continuation
	local function compile_smt(ctx, k, smt)
		local function as_smt(exp)
			return k and ops.seq(exp, k(ctx)) or exp
		end

		if type(smt) == "function" then
			return as_smt(smt(ctx))
		end
		return (function(op, ...)
			if builtin_smt[op] then
				return builtin_smt[op](ctx, k, ...)
			end
			return as_smt(compile_exp(ctx, smt))
		end)(unpack(smt))
	end

	-- only *statements* can jump/return
	-- aka, cannot jump from within an *expression*
	-- expressions do not know about continuations

	-- when you compile a seq, you compile up to the first
	-- control statement. the rest can be compiled as usual.
	-- example control statements: return, if, or another seq.
	-- when reached, pass the rest of the statements as a static
	-- continuation (really, just the uncompiled AST).
	-- the control statement can then decide what to do with it.

	local function join(k, ctx)
		if not k then return end
		local target
		return function()
			if not target then target = k(ctx) end
			return target
		end
	end

	builtin_exp.frame = const(ops.frame()) -- useful for debugging

	builtin_exp["return"] = forbid "cannot return from within expression"
	builtin_smt["return"] = function(ctx, k, ...)
		return defer(
			bind(k or null, ctx),
			ctx.ret(builtin_exp.multival(ctx, ...) or null()))
	end

	builtin_exp["if"] = function(ctx, cond, succ, fail)
		cond, succ, fail = compile_n(ctx, cond, succ, fail)
		return ops.when(cond, succ or null(), fail or null())
	end
	builtin_smt["if"] = function(ctx, k, cond, succ, fail)
		local j = join(k, ctx) -- join point (k compiled only once)
		local function branch(which)
			return which
				and compile_smt(ctx.derive{}, j, which)
				or (j or null)()
		end
		return ops.when(compile_exp(ctx, cond), branch(succ), branch(fail))
	end

	builtin_exp.seq = forbid "cannot run statements from within expression"
	function builtin_smt.seq(ctx, k, ...)
		if not ... then return (k or null)(ctx) end
		local function dive(k, smt, ...)
			local function cont(ctx)
				return compile_smt(ctx, k, smt)
			end
			if ... then return dive(cont, ...) end
			return cont(ctx)
		end
		return dive(k, reverse(...))
	end

	builtin_exp["do"] = forbid "cannot run statements from within expression"
	builtin_smt["do"] = function(ctx, k, ...)
		return builtin_smt.seq(ctx, bind(k or null, ctx), ...)
	end

	local temp_reg = 0
	local function reg_allocator()
		local reg = 0
		return function()
			reg = reg - 1
			return reg
		end
	end

	function builtin_exp.fn(ctx, args, ...)
		local regs, captured, modified, captures, reg_map, alloc
			= {}, {}, {}, {}, {}, reg_allocator()
		for i,v in ipairs(args) do regs[v] = i end

		local new_ctx = make_ctx{
			alloc = alloc, labels = {}, ret = id,
			mark = function(name, write, capture)
				if regs[name] then
					if capture and not captured[name] then
						captured[name] = 1
					end
					modified[name] = modified[name] or write
					return regs[name]
				end
				local preg = ctx.mark(name, write, true)
				if captures[name] then return reg_map[preg] end
				if preg then
					local reg = reg_map[preg] or alloc()
					captures[name], reg_map[preg] = preg, reg
					return reg
				end
			end,
			resolve = function(name)
				local reg = regs[name]
				if reg then
					return reg, modified[name] and captured[name]
				end
				return reg_map[captures[name]], select(2, ctx.resolve(name))
			end}

		-- root continuation is a nullary value
		local body = builtin_smt.seq(new_ctx, null, ...)
		local closure = next(reg_map) and ops.frame() or null()

		for preg, reg in pairs(reg_map) do
			closure = ops.push_upval(closure, reg, preg)
		end

		for reg, name in ipairs(args) do
			if modified[name] and captured[name] then
				body = ops.push_frame(ops.read_direct(reg), body, reg)
			end
		end

		return options.sparse_vararg
			and ops.fn_sparse(closure, body)
			or ops.fn(closure, body)
	end

	function builtin_smt.let(ctx, k, dst, src)
		local value = src and compile_exp(ctx, src) or null()
		local effect = src and ops.seq(value, null()) or null()
		
		if not k then return effect end
		
		if count(dst) then
			if not src then
				return builtin_smt.seq(ctx, k, fmap(
					function(d) return {"let", d} end, unpack(dst)))
			end

			local i = 0
			local function cont(ctx)
				if i >= #dst then return k(ctx) end
				i = i + 1 -- I sure hope we're not accidentally calling ks twice
				return builtin_smt.let(ctx, cont, dst[i],
					const(ops.read_indirect(temp_reg, i)))
			end

			return ops.push_frame(value, cont(ctx), temp_reg)
		end

		local reg, captured, modified = ctx.alloc()
		local new_ctx = ctx.derive{
			mark = function(name, write, capture)
				if name ~= dst then
					return ctx.mark(name, write, capture)
				end
				if capture then captured = 1 end
				modified = modified or write
				return reg
			end,
			resolve = function(name)
				if name ~= dst then return ctx.resolve(name) end
				return reg, modified and captured
			end}

		local rest = k(new_ctx) -- this may update `capture`

		return modified and captured
			and ops.push_frame(value, rest, reg)
			or ops.seq(ops.write_direct(value, reg), rest)
	end

	local function dotted_fetch(ctx, fields)
		return builtin_exp.fetch(
			ctx, {fields[1], fmap(mklit, unpack(fields, 2))})
	end

	local function access(target, key, val)
		if is_op.lit(key) then
			return deferred(function()
				local direct_reg = is_op.read_direct(target) and target[2]
				if val then
					-- we're never rewriting into a direct write,
					-- so write-dependent indirection is unaffected
					return direct_reg
						and ops.write_indirect(val, direct_reg, key[2])
						or ops.set_field(target, val, key[2])
				else
					return direct_reg
						and ops.read_indirect(direct_reg, key[2])
						or ops.field(target, key[2])
				end
			end)
		else
			return val
				and ops.set_at(target, key, val)
				or ops.at(target, key)
		end
	end

	-- lit -> field
	-- exp -> at
	-- a[b()].c[d]
	-- (fetch (a (b) "c" d))
	function builtin_exp.fetch(ctx, src)
		if type(src) == "string" then
			local fields, variadic = split(src, "."), src == "..."
			if fields[2] and not variadic then
				return dotted_fetch(ctx, fields)
			end
			return ctx.var(src, nil, function(reg, idx)
				if variadic then
					assert(not idx, "capturing vararg is not allowed")
					return options.sparse_vararg
						and ops.vdc_sparse(reg)
						or ops.vdc_direct(reg)
				end
				assert(reg, "var lookup failed: " .. src)
				return idx
					and ops.read_indirect(reg, idx)
					or ops.read_direct(reg)
			end) or builtin_exp.fetch(ctx, {"_ENV", mklit(src)})
		end

		return fold(access, compile_n(ctx, unpack(src)))
	end

	-- lit -> field
	-- exp -> at
	-- a[b()].c[d], e = val
	-- (store val (a (b) "c" d) e)
	function builtin_exp.store(ctx, src, dst, ...)
		local value = compile_exp(ctx, src)

		if ... then
			local writes = {}
			for i,d in ipairs{dst, ...} do
				writes[i] = builtin_exp.store(
					ctx, const(ops.read_indirect(temp_reg, i)), d)
			end
			return ops.push_frame(
				value, foldr(ops.seq, unpack(writes)), temp_reg)
		end

		if count(dst) then
			local path = {compile_n(ctx, unpack(dst))}
			local last = deli(path)
			return access(fold(access, unpack(path)), last, value)
		end

		assert(dst ~= "...", "updating vararg is not allowed")
		local fields = split(dst, ".")
		if fields[2] then
			local last = deli(fields)
			return ops.set_field(dotted_fetch(ctx, fields), value, last)
		end
		return ctx.var(dst, true, function(reg, idx)
			return idx
				and ops.write_indirect(value, reg, idx)
				or ops.write_direct(value, reg)
		end) or builtin_exp.store(ctx, const(value), {"_ENV", mklit(dst)})
	end

	function builtin_exp.inplace(ctx, op, lhs, rhs)
		local opfun = builtin_exp[op]
		if type(lhs) == "string" then
			return builtin_exp.store(ctx, const(opfun(ctx, lhs, rhs)), lhs)
		end
		local path = {compile_n(ctx, unpack(lhs))}
		local last = deli(path)
		local target = fold(access, unpack(path))
		local op_lhs = ops.inplace_pull()
		local op_val = opfun(ctx, const(op_lhs), rhs)
		return deferred(function()
			local direct_reg = is_op.read_direct(target) and target[2]
			local field = is_op.lit(last) and last[2]
			if direct_reg and field then
				backpatch(op_lhs, ops.read_indirect(direct_reg, field))
				return ops.write_indirect(op_val, direct_reg, field)
			else
				return ops.inplace(target, last, op_val)
			end
		end)
	end

	-- note: deprecated 
	function builtin_exp.set(ctx, dst, src)
		if count(dst) then
			return builtin_exp.store(ctx, src, unpack(dst))
		end
		return builtin_exp.store(ctx, src, dst)
	end

	builtin_exp["label"] = forbid "cannot use `label` in expression"
	function builtin_smt.label(ctx, k, name)
		k = join(k, ctx) or null
		ctx.labels[name] = k
		return k()
	end

	builtin_exp["goto"] = forbid "cannot use `goto` in expression"
	builtin_smt["goto"] = function(ctx, k, name)
		(k or null)(ctx)
		return deferred(function()
			assert(ctx.labels[name], "label not found: " .. name)
			return ctx.labels[name]()
		end)
	end

	builtin_exp["break"] = forbid "cannot use `break` in expression"
	builtin_smt["break"] = function(ctx, k)
		(k or null)(ctx)
		assert(ctx.brk, "cannot use break outside of loops")
		return ctx.brk()
	end

	builtin_exp["while"] = forbid "cannot use `while` in expression"
	builtin_smt["while"] = function(ctx, k, cond, ...)
		local loop, cont = {}, join(k, ctx) or null
		backpatch(loop, ops.when(
			compile_exp(ctx, cond),
			builtin_smt.seq(ctx.derive{brk = cont}, const(loop), ...),
			cont()))
		return loop
	end

	builtin_exp["repeat"] = forbid "cannot use `repeat` in expression"
	builtin_smt["repeat"] = function(ctx, k, body, cond)
		local loop, cont = {}, join(k, ctx) or null
		backpatch(loop, builtin_smt.seq(ctx.derive{brk = cont}, function(ctx)
				return ops.when(compile_exp(ctx, cond), cont(), loop)
			end, body))
		return loop
	end

	local function wire_forloop(ctx, k, var, vars, body, cond, step, init)
		local eval, pump, cont = {}, {}, join(k, ctx) or null
		-- loop var needs to stay in the same register
		local _var, _reg, pinned_ctx = var
		backpatch(pump, builtin_smt.let(ctx.derive{brk = cont}, function(ctx)
			pinned_ctx = ctx.derive{mark = function(name, write, capture)
				if name == _var and write then
					_reg = ctx.alloc()
					_var = const(ops.read_direct(_reg))
				end
				return ctx.mark(name, write, capture)
			end}
			-- body can't be backpatched, let emits are capture dependent
			local _body = builtin_smt.seq(pinned_ctx, const(pump), unpack(body))
			-- condition eval depends on whether or not loop var was modified
			return ops.when(cond(pinned_ctx, _var), cont(), _body)
		end, vars, const(eval)))

		local function intercept(val)
			return _reg
				and ops.seq(ops.write_direct(val, _reg), _var())
				or val
		end

		backpatch(eval, intercept(step(pinned_ctx, _var)))
		init = intercept(init)

		local prime = {unpack(pump)}
		if is_op.push_frame(prime) then
			prime[2] = init -- (push_frame init ...)
		else
			-- (seq (write_direct init ...) ...)
			prime[2] = ops.write_direct(init, prime[2][3])
		end
		return prime
	end

	local with_exit = bind(compose, ops.exit)

	builtin_exp["for"] = forbid "cannot use `for` in expression"
	builtin_smt["for"] = function(ctx, k, args, ...)
		-- (for (var a b c) body...)
		local var, a, b, c = args[1], compile_n(ctx, unpack(args, 2))
		c = c or ops.lit(1)
		k = join(k, ctx) or null

		if options.specialized_for_ops then
			local reg = ctx.alloc()
			local body = builtin_smt.seq(ctx.derive{
				brk = with_exit(k), ret = with_exit(ctx.ret),
				mark = function(name, ...)
					if name == var then
						return reg
					end
					return ctx.mark(name, ...)
				end,
				resolve = function(name)
					if name == var then
						return reg, 1
					end
					return ctx.resolve(name)
				end}, null, ...)
			return ops.for_setup(
				ops.num_for(body, k(), reg), foldr(ops.multival, a, b, c))
		end

		local setup, body = {}, {...}
		local function param(op)
			if is_op.lit(op) then return op end
			local reg = ctx.alloc()
			add(setup, ops.write_direct(op, reg))
			return ops.read_direct(reg)
		end
		local _init, _sentinel, _step = a, param(b), param(c)

		local function loop_direction(check_op)
			return wire_forloop(ctx, k, var, var, body,
				function(ctx, var)
					return builtin_exp[check_op](ctx, var, const(_sentinel))
				end, function(ctx, var)
					return builtin_exp["+"](ctx, var, const(_step))
				end, _init)
		end

		add(setup, is_op.lit(_step)
			and loop_direction(_step[2] > 0 and ">" or "<")
			or ops.when(ops.gt(_step, ops.lit(0)),
				loop_direction">", loop_direction"<"))

		return foldr(ops.seq, unpack(setup))
	end

	builtin_exp.for_in = forbid "cannot use `for_in` in expression"
	function builtin_smt.for_in(ctx, k, vars, iter, ...)
		-- (for_in (vars...) iter body...)
		-- (for_in vars iter body...)
		local reg = ctx.alloc()
		local eval_iter = compile_exp(ctx, iter)

		if options.specialized_for_ops and (count(vars) or 1) < 3 then
			k = join(k, ctx) or null
			local var1, var2 = unpack(count(vars) and vars or {vars})
			local body = builtin_smt.seq(ctx.derive{
				brk = with_exit(k), ret = with_exit(ctx.ret),
				mark = function(name, ...)
					if name == var1 or name == var2 then return reg end
					return ctx.mark(name, ...)
				end,
				resolve = function(name)
					if name == var1 then return reg, 1 end
					if name == var2 then return reg, 2 end
					return ctx.resolve(name)
				end}, null, ...)

			return ops.for_setup(ops.gen_for(body, k(), reg), eval_iter)
		end

		local _next, _state, _ctl = fmap(function(idx)
				return const(ops.read_indirect(reg, idx))
			end, 1, 2, 3)

		local prime = wire_forloop(
			ctx, k, count(vars) and vars[1] or vars, vars, {...},
			function(ctx, var)
				return builtin_exp["=="](ctx, var, null)
			end, function(ctx, var)
				return builtin_exp.call(ctx, _next, _state, var)
			end, builtin_exp.call(ctx, _next, _state, _ctl))

		return ops.push_frame(eval_iter, prime, reg)
	end

	function builtin_exp.method(ctx, target, method, ...)
		local fun, args
			= compile_exp(ctx, target), builtin_exp.multival(ctx, ...)
		return ops.method(fun, args or null(), method)
	end

	-- todo: pedantic mode
	-- for the sake of performance, we're not preserving evaluation order
	-- the alternative is putting everything through a temporary frame
	function builtin_exp.construct(ctx, entries)
		local array, hash = {}, {}
		for entry in all(entries) do
			local lhs, rhs = compile_n(ctx, unpack(entry))
			if rhs then
				add(hash, function(rest)
					return ops.tab_entry(lhs, rhs, rest)
				end)
			else
				add(array, lhs)
			end
		end
		array = foldr(ops.multival, unpack(array)) or null()
		if #hash < 1 then return ops.arr(array) end
		hash = fold(compose, unpack(hash))
		return ops.tab_ctor(hash(ops.frame()), array)
	end

	local function match_arity(...)
		local op = {...}
		return function(...)
			return op[select("#", ...)](...)
		end
	end

	local collapse_ops = split"call,method,multival,vdc_direct"

	for opname, opfn in pairs{
		call = function(fun, ...)
			local args = foldr(ops.multival, ...)
			return ops.call(fun, args or null())
		end,

		collapse = function(val)
			for op in all(collapse_ops) do
				if is_op[op](val) then return ops.collapse(val) end
			end
			return val
		end,

		multival = bind(foldr, ops.multival),

		[".."] = ops.cat,
		["+"] = ops.add,
		["-"] = match_arity(ops.unm, ops.sub),
		["*"] = ops.mul,
		["/"] = ops.div,
		["\\"] = ops.idiv,
		["^"] = ops.pow,
		["@"] = ops.peek,
		["%"] = match_arity(ops.peek2, ops.mod),
		["$"] = ops.peek4,
		["=="] = ops.eq,
		["~="] = ops.neq,
		["!="] = ops.neq,
		["<"] = ops.lt,
		["<="] = ops.le,
		[">"] = ops.gt,
		[">="] = ops.ge,
		["and"] = ops.inter,
		["not"] = ops.inv,
		["or"] = ops.union,
		["<<"] = ops.shl,
		["<<>"] = ops.rotl,
		[">>"] = ops.shr,
		[">><"] = ops.rotr,
		[">>>"] = ops.lshr,
		["&"] = ops.band,
		["|"] = ops.bor,
		["^^"] = ops.bxor,
		["~"] = match_arity(ops.bnot, ops.bxor),
		["#"] = ops.len,
		["[]"] = match_arity(forbid "incorrect [] arity", ops.at, ops.set_at)
	} do
		builtin_exp[opname] = compose(opfn, compile_n)
	end

	local compiled = compile_exp(
		make_ctx{mark = const(), resolve = forbid"var resolution failed"},
		{"fn", {"_ENV"},
			options.vm_cleanup and {"seq", {"seq", fmap(function(var)
				return {"store", null, var}
			end, unpack(options.vm_cleanup))}, ast} or ast})

	foreach(deferred_pass, call)
	return compiled, options
end)
--[[
copyright 2026 wellspring-labs

this program is free software: you can redistribute it and/or modify it under the terms of the AGPL, version 3 or later.
you should have received a copy of the AGPLv3 along with this program. if not, see <https://www.gnu.org/licenses/>. 
]]

-- warning: 0-based indexing
local function bigstring(data)
	data = split(data, 0x4000, false)
	if (#data == 0) return const"", const"", 0
	setmetatable(data, {__index = const""})
	local len = #data[#data] >>> 16 | (#data - 1) >>> 2
	data[0] = deli(data, 1)
	local function substr(a, b) -- [a, b] range, 0-indexed, inclusive
		if (a > b) return ""
		local sa, ca = a \ 0x.4, (a<<16&0x3fff)+1
		if (sa == b \ 0x.4) return sub(data[sa], ca, (b<<16&0x3fff)+1)
		return sub(data[sa], ca, 0x4000) .. substr((a + 0x.4) & -0x.4, b)
	end
	return function(pos)
		return data[pos \ 0x.4][(pos<<16&0x3fff)+1]
	end, substr, len
end

function crescent_scan_tokens(
		str, options, escapes, alphanumeric, whitespace, punctuation,
		comment, quotes, digits10, digits16, digits2, base2, base16)

	local char, substr, len = bigstring(str)

	local function advance(p, n)
		if n then return p + n, substr(p, p + n - 0x.0001) end
		return p + 0x.0001, char(p)
	end

	local function skip(p, filter, inv)
		for a=p,len-0x.0001,0x.0001 do
			local c = char(a)
			if filter[c] == inv then return a end
		end
		return len
	end

	local function consume(p, ...)
		local a = skip(p, ...)
		return a, substr(p, a - 0x.0001)
	end

	local line_breaks = {}
	for p=0,len-0x.0001,0x.0001 do
		if char(p) == "\n" then add(line_breaks, p) end
	end

	local function line(p)
		local function search(lo, hi)
			if lo >= hi then return lo end
			local md = (lo + hi) \ 2
			return p <= line_breaks[md]
				and search(lo, md)
				or search(md + 1, hi)
		end
		return search(1, #line_breaks) + options.first_line_num - 1
	end

	local function fail(msg, p)
		stop("line " .. line(p) .. ":\n\t" .. msg)
	end

	local function parse_escaped_char(p)
		for i=3,1,-1 do
			local a, c = advance(p, i>>>16)
			if escapes[c] then return a, escapes[c] end
		end
		local a, c = advance(p)
		if c == 'z' then return skip(a, whitespace), "" end
		return fail("bad escape: \"" .. c .. "\"", p)
	end

	local function parse_quoted_str(p, quote)
		local res, c = ""
		while p < len do
			p, c = advance(p)
			if c == quote then return p, res end
			if c == '\n' then return fail("unterminated string", p) end
			if c == '\\' then p, c = parse_escaped_char(p) end
			res ..= c
		end
		return fail("unterminated string", p)
	end

	local function parse_raw_string(p)
		local a, terminator = consume(p, {["="] = true})
		local a, c = advance(a)
		if c ~= "[" then return end
		terminator = ']' .. terminator .. ']'
		local tlen = a-p
		local na, nl = advance(a)
		if nl == "\n" then a = na end
		for i=a,len-tlen-0x.0001,0x.0001 do
			local s = substr(i, i+tlen)
			if s == terminator then
				return i+tlen+0x.0001, substr(a, i-0x.0001)
			end
		end
		return fail("unterminated string", p)
	end

	local function parse_number(p)
		local function impl(pfix, p, parser)
			local a, s = consume(p, parser)
			return a, tonum(pfix .. s) -- /!\ defers validation
		end
		local a, s = advance(p, 0x.0002)
		if base16[s] then return impl(s, a, digits16) end
		if base2[s] then return impl(s, a, digits2) end
		return impl("", p, digits10)
	end

	local tidx = 0
	local tokens, srclines = {}, {}

	-- note: parser is best effort in some areas for now
	--       (for the sake of my own sanity)
	local function parse_tokens(p)
		local function push(tok)
			tidx += 0x.0001
			tokens[tidx] = tok
			srclines[tidx] = line(p)
		end

		if p >= len then return end
		local a, c = advance(p)
		if whitespace[c] then return parse_tokens(skip(a, whitespace)) end
		if digits10[c] then
			local a, num = parse_number(p)
			if num then push(num) return parse_tokens(a) end
		end
		if alphanumeric[c] then
			local a, symbol = consume(p, alphanumeric)
			push(symbol) return parse_tokens(a)
		end
		if quotes[c] then
			local e, str = parse_quoted_str(a, c)
			push{str} return parse_tokens(e)
		end
		if c == "[" then
			local e, str = parse_raw_string(a)
			if e then push {str} return parse_tokens(e) end
		end

		local a, s = advance(p, 0x.0002)
		if comment[s] then
			return parse_tokens(
				char(a) == "["
					and parse_raw_string(a + 0x.0001)
					or skip(a, {["\n"] = true}, true))
		end 

		for i=4,1,-1 do
			local a, c = advance(p, i>>>16)
			if punctuation[c] then push(c) return parse_tokens(a) end
		end
		fail("unrecognized token: " .. tostr(p))
	end

	parse_tokens(0)

	local tpos = 0

	local function advance(n)
		tpos += (n or 1) >> 16
		return tokens[tpos], srclines[tpos]
	end

	local function peek(n)
		n = ((n or 0) >> 16) + tpos + 0x.0001
		return tokens[n], srclines[n]
	end

	local function accept(target)
		return tokens[tpos + 0x.0001] == target and advance()
	end

	return tokens, srclines, tidx,
		function(upd)
			if (upd) tpos = upd
			return tpos
		end, advance, peek, accept 
end
--[[
copyright 2026 wellspring-labs

this program is free software: you can redistribute it and/or modify it under the terms of the AGPL, version 3 or later.
you should have received a copy of the AGPLv3 along with this program. if not, see <https://www.gnu.org/licenses/>. 
]]

compile_crescent = compose(compile_bytecode, function(options, codestr)
	local function as_lookup(t)
		local res = {}
		for i in all(t) do res[i] = true end
		return res
	end
	local kw_lookup = compose(as_lookup, split)

	local escapes = {}
	for i, v in ipairs(split("abfnrtv\\\"'\n*#-|+^", 1, false)) do
		escapes[v] = ("⁷⁸ᶜ\n\r\tᵇ\\\"'\n¹²³⁴⁵⁶")[i]
	end

	for i=0,255 do
		local c, dec, hex = chr(i), tostr(i), 'x' .. sub(tostr(i, 1), 5, 6)
		escapes[hex] = c
		for j = #dec,3 do
			escapes[dec] = c
			dec = "0" .. dec
		end
	end

	local alphanumeric, keywords, block_ends, assign_ops =
		as_lookup"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz1234567890_゛゜█▒🐱⬇️░✽●♥☉웃⌂⬅️😐♪🅾️◆…➡️★⧗⬆️ˇ∧❎▤▥あいうえおかきくけこさしすせそたちつてとなにぬねのはひふへほまみむめもやゆよらりるれろわをんっゃゅょアイウエオカキクケコサシスセソタチツテトナニヌネノハヒフヘホマミムメモヤユヨラリルレロワヲンッャュョ◜◝",
		kw_lookup"and,break,do,else,elseif,end,false,for,function,goto,if,in,local,nil,not,or,repeat,return,then,true,until,while",
		kw_lookup"end,else,elseif,until",
		kw_lookup"=,+=,-=,*=,/=,\\=,%=,&=,|=,^=,^^=,..=,<<=,>>=,>>>=,<<>=,>><="

	if not codestr then codestr, options = options, {} end
	fallback{
		first_line_num = 1
	}(options)

	local _tokens, tlines, tlen, tpos, advance, peek, accept = crescent_scan_tokens(
		codestr, options, escapes, alphanumeric,
		as_lookup" \t\f\v\r\n",
		kw_lookup("+ - * / \\ @ % $ # == ~= != > < >= <= .. ~ & | ^ ^^ << >> >>> <<> >>< = += -= *= /= \\= %= &= |= ^= ^^= ..= <<= >>= >>>= <<>= >><= ( ) { } [ ] ; , ? . : :: ...", " "),
		kw_lookup"--,//",
		as_lookup[["']],
		as_lookup".1234567890",
		as_lookup".1234567890aAbBcCdDeEfF",
		as_lookup".01",
		as_lookup{"0b","0B"},
		as_lookup{"0x","0X"})

	local parse_exp, parse_block

	local function fail(msg, l)
		stop("line " .. (l or tlines[tpos()]) .. ":\n\t" .. msg)
	end

	local function require(target)
		return accept(target)
			or fail("expected: " .. target .. " - got: " .. tostr(peek()))
	end

	local function try_identifier(token)
		token = token or advance()
		return type(token) == "string"
			and alphanumeric[token[1]]
			and not keywords[token]
			and token
	end

	local function identifier(token)
		token = token or advance()
		return try_identifier(token)
			or fail("invalid identifier: " .. tostr(token))
	end

	local endcb
	local function at_smt_end()
		return block_ends[peek()] or endcb and endcb()
	end

	local function parse_list(parser, ...)
		local res = {(parser(...))}
		while accept "," do
			add(res, (parser(...)))
		end
		return res
	end

	local compiler_builtins = kw_lookup"__ps8_frame"

	local function parse_call(target, method, arg)
		local args = {}
		if arg then
			add(args, arg)
		elseif not accept ")" then
			while true do
				add(args, (parse_exp()))
				if accept ")" then break end
				require ","
			end
		end

		return (method
			and {"method", target, method, unpack(args)}
			or (compiler_builtins[target]
				and {sub(target, 7), unpack(args)}
				or {"call", target, unpack(args)})), true
	end

	local function parse_table()
		local entries = {}

		while not accept "}" do
			if accept "[" then
				local key = parse_exp()
				require "]"
				require "="
				local value = parse_exp()
				add(entries, {key, value})
			elseif peek(1) == "=" then
				local key = mklit(identifier())
				require "="
				local value = parse_exp()
				add(entries, {key, value})
			else
				local value = parse_exp()
				add(entries, {value})
			end

			if accept "}" then break end
			if not accept ";" then require "," end
		end

		return {"construct", entries}
	end

	local function parse_function(method)
		local params = {method}
		require "("
		if peek() ~= ")" then
			foreach(parse_list(function()
				return accept("...") or identifier()
			end), bind(add, params))
		end
		require ")"
		local body = parse_block()
		require "end"
		return {"fn", params, body}
	end

	local unary_ops = kw_lookup"-,~,#,not,@,%,$"

	local function parse_core(prec)
		local token = advance()
		if token == "nil" then return mklit() end
		if token == "true" then return mklit(true) end
		if token == "false" then return mklit(false) end
		if type(token) == "number" then return mklit(token) end
		if count(token) then return mklit(token[1]) end
		if token == "{" then return parse_table() end
		if token == "(" then
			local val = parse_exp(prec)
			require ")"
			if not prec then return {"collapse", val}, true end
			return val, true
		end
		if unary_ops[token] then return {token, (parse_exp(11))} end
		if token == "function" then return parse_function() end
		if token == "..." then return token end
		if token == "?" then
			return {"call", "print", unpack(parse_list(parse_exp))}
		end
		if try_identifier(token) then return token, true, token end
		fail("unexpected token: " .. tostr(token))
	end
	
	local binops = {
		["^"] = {13, 12},
		["*"] = {11, 11},
		["/"] = {11, 11},
		["\\"] = {11, 11},
		["%"] = {11, 11},
		["+"] = {10, 10},
		["-"] = {10, 10},
		[".."] = {9, 8},
		["<<"] = {7, 7},
		[">>"] = {7, 7},
		[">>>"] = {7, 7},
		["<<>"] = {7, 7},
		[">><"] = {7, 7},
		["&"] = {6, 6},
		["^^"] = {5, 5},
		["~"] = {5, 5},
		["|"] = {4, 4},
		["<"] = {3, 3},
		[">"] = {3, 3},
		["<="] = {3, 3},
		[">="] = {3, 3},
		["=="] = {3, 3},
		["~="] = {3, 3},
		["!="] = {3, 3},
		["and"] = {2, 2},
		["or"] = {1, 1}
	}

	local function parse_binary_op(token, prec, left, right)
		local op = binops[token]
		if op and prec < op[1] then return {token, left, (right(op[2]))} end
	end

	local function parse_exp_more(prec, left, isprefix)
		local token = advance()
		if isprefix then
			if token == "." then
				local field = mklit(identifier())
				return {"fetch", {left, field}}, true, {left, field}
			end
			if token == "[" then
				local right = parse_exp(0)
				require "]"
				return {"fetch", {left, right}}, true, {left, right}
			end
			if token == "(" then
				return parse_call(left)
			end
			if token == "{" or type(token) == "table" then
				advance(-1)
				local arg = parse_core()
				return parse_call(left, nil, arg)
			end
			if token == ":" then
				local right, tok = identifier(), peek()
				if tok == "{" or type(tok) == "table" then
					local arg = parse_core()
					return parse_call(left, right, arg)
				end
				require "("
				return parse_call(left, right)
			end
		end

		local res = parse_binary_op(token, prec, left, parse_exp)
		if not res then advance(-1) end
		return res
	end

	parse_exp = function(prec)
		local val, prefix, assign = parse_core()
		for nv,np,na in function()
			return parse_exp_more(prec or 0, val, prefix)
		end do val, prefix, assign = nv, np, na end
		return val, assign
	end

	-- (store val (a (b) "c" d) e)
	-- ends up more like
	-- (store val ((fetch (fetch (a (call b))) "c") d) e)
	-- which is fine
	local function parse_assign_exp()
		local _, assign = parse_exp()
		if not assign then fail "cannot assign to value" end
		return assign
	end

	local function parse_assign()
		local dst = parse_list(parse_assign_exp)
		require "="
		local src = parse_list(parse_exp)
		return {"store", {"multival", unpack(src)}, unpack(dst)}
	end

	local function parse_assign_op(target)
		local op = sub(advance(), 1, -2)
		return {"inplace", op, target, parse_exp()}
	end

	local function parse_local()
		if accept "function" then
			local name = identifier()
			return {"seq", {"let", name}, {"store", parse_function(), name}}
		else
			local dst = parse_list(try_identifier)
			local src = accept "=" and parse_list(parse_exp) or {}
			return #dst == 1
				and {"let", dst[1], {"multival", unpack(src)}}
				or {"let", dst, {"multival", unpack(src)}}
		end
	end

	local function as_shorthand(allowed, fn)
		local _, line = peek(-1)
		local prev_endcb = endcb
		endcb = function(off) return line ~= select(2, peek(off)) end
		if not allowed or endcb() then
			return fail "unterminated shorthand"
		end
		return defer(function()
			if endcb(-1) then return fail "unterminated shorthand" end
			endcb = prev_endcb
		end, fn())
	end

	local function parse_ifsmt()
		local short = peek() == "("
		local cond = parse_exp()
		if accept "then" or accept "do" then
			local succ, fail = parse_block()
			if accept "else" then fail = parse_block(), require "end"				
			elseif accept "elseif" then fail = parse_ifsmt()
			else require "end" end
			return {"if", cond, succ, fail}
		else
			return as_shorthand(short, function()
				local succ, fail = parse_block()
				if not endcb() and accept "else" then
					fail = parse_block()
				end
				return {"if", cond, succ, fail}
			end)
		end
	end

	local function parse_while()
		local short = peek() == "("
		local cond = parse_exp()
		local function body() return {"while", cond, parse_block()} end

		if accept "do" then
			local res = body()
			require "end"
			return res
		else
			return as_shorthand(short, body)
		end
	end

	local function parse_repeat()
		local body = parse_block()
		require "until"
		local cond = parse_exp()
		return {"repeat", body, cond}
	end

	local function parse_for()
		if peek(1) == "=" then
			local var = identifier()
			require "="
			local a = parse_exp()
			require ","
			local b = parse_exp()
			local step = accept "," and parse_exp() or nil
			require "do"
			local res = {"for", {var, a, b, step}, parse_block()}
			require "end"
			return res
		else
			local vars = parse_list(try_identifier)
			require "in"
			local src = parse_list(parse_exp)
			require "do"
			local res = {
				"for_in", vars[2] and vars or vars[1],
				{"multival", unpack(src)}, parse_block()}
			require "end"
			return res
		end
	end

	local function parse_return()
		if peek() == ";" or at_smt_end() then
			return {"return"}
		else
			return {"return", unpack(parse_list(parse_exp))}
		end
	end

	local function parse_smt()
		local token = advance()
		if token == ";" then return end
		if token == "do" then
			local res = parse_block()
			require "end"
			return {"do", res}
		end
		if token == "if" then return parse_ifsmt() end
		if token == "while" then return parse_while() end
		if token == "repeat" then return parse_repeat() end
		if token == "for" then return parse_for() end
		if token == "break" then return {"break"} end
		if token == "return" then return parse_return(), true end
		if token == "local" then return parse_local() end
		if token == "goto" then return {"goto", identifier()} end
		if token == "::" then
			local name = identifier(), require "::"
			return {"label", name}
		end
		if token == "function" then
			local name, method = {identifier()}
			while accept "." do add(name, mklit(identifier())) end
			if accept ":" then
				add(name, mklit(identifier()))
				method = "self"
			end
			return {"store",
				parse_function(method),
				#name > 1 and name or name[1]}
		end
		advance(-1)
		local start = tpos()
		local val, assign = parse_exp()
		if accept "," or accept "=" then
			tpos(start)
			return parse_assign()
		elseif assign_ops[peek()] then
			if not assign then fail "cannot assign to value" end
			return parse_assign_op(assign)
		else
			return val
		end
	end

	parse_block = function()
		local block = {}
		while tpos() < tlen and not at_smt_end() do
			local smt, need_end = parse_smt()
			if smt then add(block, smt) end
			if need_end then accept ";" break end
		end

		local end_labels = {}
		while #block > 1 and block[#block][1] == "label" do
			add(end_labels, deli(block))
		end
		
		local smts = #block > 1 and {"seq", unpack(block)} or block[1]
		return #end_labels > 0
			and {"seq", {"do", smts}, unpack(end_labels)}
			or smts
	end

	return parse_block(), options
end)
local lzw_decompressor = [[
function(str, chars)
	local dict, pos, width, acc, bits, mask = {}, 1, 2, 0, 0,
	split",3,7,15,31,63,127,255,511,1023,2047,4095,8191,16383,32767,-1"
	local function add_dict(symbol)
		add(dict, symbol)
		if (count(dict) + 1 >= shl(1, width)) width += 1
	end
	for c in all(chars) do add_dict(c) end

	local function input()
		while bits < width do
			acc = bor(shl(acc, 8), lshr(ord(str, pos),16))
			bits += 8
			pos += 1
		end
		bits -= width
		local res = band(lshr(acc, bits-16), mask[width])
		if (res ~= 0) return res
	end

	local out = dict[input()]
	local prev = out
	for symbol in input do
		prev = (function(match)
			if match then
				add_dict(prev .. match[1])
				return match
			end
			match = prev .. prev[1]
			add_dict(match)
			return match
		end)(dict[symbol])
		out ..= prev
	end
	return out
end
]]

-- uses the actual bit operators instead of their function proxies
local lzw_decompressor_native = [[
function(str, chars)
	local dict, pos, width, acc, bits, mask = {}, 1, 2, 0, 0,
	split",3,7,15,31,63,127,255,511,1023,2047,4095,8191,16383,32767,-1"
	local function add_dict(symbol)
		add(dict, symbol)
		if (#dict + 1 >= 1<<width) width += 1
	end
	for c in all(chars) do add_dict(c) end

	local function input()
		while bits < width do
			acc <<= 8
			acc |= ord(str, pos) >>> 16
			bits += 8
			pos += 1
		end
		bits -= width
		local res = acc >>> bits-16 & mask[width]
		if (res ~= 0) return res
	end

	local out = dict[input()]
	local prev = out
	for symbol in input do
		prev = (function(match)
			if match then
				add_dict(prev .. match[1])
				return match
			end
			match = prev .. prev[1]
			add_dict(match)
			return match
		end)(dict[symbol])
		out ..= prev
	end
	return out
end
]]

function bit_writer(outfn)
	local acc, bits = 0, 0
	return function(n, val)
		acc <<= n
		acc |= val >>> 16
		bits += n
		while bits >= 8 do
			bits -= 8
			outfn(acc>>>bits-16&255)
		end
	end
end

function lzw_compress(str, outfn)
	local dict, revdict, width, idx =
		{}, {},	2, 1

	local function add_dict(w)
		if (idx >= 1<<width) width += 1
		if not dict[w] then
			dict[w] = idx
			revdict[idx] = ord(w)
			idx += 1
		end
	end

	for c in all(str) do add_dict(c) end
	local chars, len, window, pos =
		chr(unpack(revdict)), #str, 0, 1

	while pos <= len do
		local w, l = (function()
			for sz = window,0,-1 do
				local match = sub(str, pos, pos + sz)
				if (dict[match]) return match, sz + 1
			end
		end)()
		outfn(width, dict[w])
		add_dict(sub(str, pos, pos + l))
		window = max(window, l)
		pos += l
	end
	outfn(width+7, 0)
	return chars
end

local pico_process = python.import("pico_process")
local pico_output = python.import("pico_output")
local RangeSet = python.import("utils").RangeSet
local module = {}
local ROM_ENDADDR = 0x4300

Parens8Compiler = python.class(pico_process.CompilerBase)

-- TODO: consider moving all the ROM-related logic to shrinko itself? it's likely common across all compilers...

function split_args(args_str)
    local args = {}
    for arg in all(split(args_str, ' ', false)) do
        arg = split(arg, '=')
        args[arg[1]] = arg[2] or true
    end
    return args
end

function copy(tbl)
    local copy = {}
    for k,v in pairs(tbl) do copy[k] = v end
    return copy
end
function tohex(v)
    return sub(tostr(v, 1), 1, 6)
end
function isbigstr(v)
    local len = select(3, bigstring(v));
    return mid(len, 0x.7fff) != len
end

function get_parens8_data(ctxt)
    return ctxt.get_field("parens8_data", function()
        return {num_compilers=0, results={}, rom_ranges=RangeSet()}
    end)
end

function reset(opts)
    -- called once done with cart (e.g. important in the webapp and in test runs)
    opidx, opcodes, vm_ops = unpack(get_parens8_data(opts.ctxt).reset_data)
    -- we don't copy here - they'll be copied in their initial state again next compilation
end

function rename(ctxt, name)
    if ctxt.global_renames then
        name = python.attrs(ctxt.global_renames).get(name, name)
    end
    return name
end

function Parens8Compiler:__init(opts)
    self.raw_args = opts.args
    self.cl_args = split_args(self.raw_args)
    self.ctxt = opts.ctxt
    self.src = opts.src
    self.id = tostr(self, 1) -- used to identify this compiler instance inside strings

    get_parens8_data(self.ctxt).num_compilers += 1
end

function Parens8Compiler:get_dynamic_includes()
    local data = get_parens8_data(self.ctxt)

    local includes = {}
    if not data.has_interpreter then
        add(includes, "parens8.interpreter " .. self.raw_args)
        -- (guaranteed to set parens8.interpreter before next compilation)
    end

    if self.cl_args.dest then
        data.disable_cleanup = true
        add(includes, "parens8.assign " .. self.cl_args.dest .. " " .. self.id)
    else
        add(includes, "parens8.run " .. self.id)
    end
    
    return python.list(includes)
end

function Parens8Compiler:compile(root, opts)
    local code = pico_output.output_node(root, self.ctxt, --[[minify=]]false)
    local data = get_parens8_data(self.ctxt)

    -- save initial data to allow resetting it later
    if not data.needs_reset then
        data.reset_data = {opidx, copy(opcodes), copy(vm_ops)}
        python.attrs(self.ctxt.at_finish).append(reset)
        data.needs_reset = true
    end
    
    -- extract our options
    local parens_args = copy(self.cl_args)

    local rom_ranges = RangeSet()
    local rom_ranges_str = self.cl_args.rom_ranges; parens_args.rom_ranges = nil
    if rom_ranges_str then
        for range in all(split(rom_ranges_str, ',', false)) do
            range = split(range, ':')
            if #range != 2 then
                printh("parens8 - invalid rom range specified - format is start..end")
            else
                rom_ranges.add(python.list(range))
            end
        end
    end
    
    local rom_addr = self.cl_args.rom; parens_args.rom = nil
    if (rom_addr and type(rom_addr) != "number") rom_addr = 0

    local rom_endaddr = self.cl_args.rom_end; parens_args.rom_end = nil
    if (type(rom_endaddr) != "number" or rom_endaddr > ROM_ENDADDR) rom_endaddr = ROM_ENDADDR

    if (rom_addr) rom_ranges.add(python.list{rom_addr, rom_endaddr})

    local compress = self.cl_args.compress; parens_args.compress = nil
    if (compress and type(compress) != "string") compress = "lzw"
    
    parens_args.dest = nil; parens_args.bigstring = nil; parens_args.deserialize = nil

    -- modify non-string options
    data.num_compilers -= 1 -- to go...
    if not parens_args.vm_cleanup and data.num_compilers == 0 and not data.disable_cleanup then
        parens_args.vm_cleanup = "full"
    end
    parens_args.vm_cleanup = parens_args.vm_cleanup == "full" and vm_cleanup_full -- else empty
    
    if self.ctxt.global_renames and parens_args.vm_cleanup then -- need to rename cleanups in tandem...
        parens_args.vm_cleanup = copy(parens_args.vm_cleanup)
        for i, cleanup in pairs(parens_args.vm_cleanup) do
            parens_args.vm_cleanup[i] = rename(self.ctxt, cleanup)
        end
    end

    local byte_code = compile_crescent(parens_args, code)
    
    local compressed_dict
    if compress then
        -- (triggers if has multiple compiler instances and the first [which is used to build the interpreter] didn't request compression)
        if (not data.has_decompressor) stop("you must explicitly add '--$dynamic-include: parens8.interpreter compress' before the compiler switchings")

        -- TODO: removeme once parens8 fixes lzw_compress to supports bigstring
        if (isbigstr(byte_code)) stop("large inputs currently cannot be compressed via parens8 - try splitting into multiple compilation blocks")

        local compressed_code = ""
	    compressed_dict = lzw_compress(byte_code, bit_writer(function(byte) compressed_code..=chr(byte) end))
        byte_code = compressed_code
    end
    
    if self.cl_args.deserialize and not data.deserialize_kind then
        stop("the `deserialize` option should be supplied on the first `--$switch-compiler:`, or on the `--$dynamic-include:` if it exists")
    end
    if self.cl_args.bigstring != data.is_bigstring then
        stop("all parens8 comments ('--$switch-compiler:' and '--$dynamic-include:') should either have 'bigstring' as an option or not have it as an option")
    end
    if isbigstr(byte_code) and not data.is_bigstring then
        stop("input too large - add 'bigstring' to *all* parens8 comments to support large inputs (e.g. '--$switch-compiler: parens8 bigstring')")
    end

    byte_code = shrinko.to_memory(byte_code)
    assert(#byte_code != 0, "empty parens8 bytecode")

    local results = data.results
    results[self.id] = ""

    if python.builtins.bool(rom_ranges) then
        local total_len = 0
        local total_range = 0

        rom_ranges.__isub__(data.rom_ranges) -- lua has no proper -= metamethod
        for rom_addr, rom_endaddr in python.iterex(rom_ranges) do
            local max_len = python.builtins.min(rom_endaddr - rom_addr, #byte_code) -- #byte_code may be a python int
            rommemcpy(self.src.cart.rom, rom_addr, byte_code, 0, max_len)
            results[self.id] ..= format("chr(peek(`1`, `2`))", {rom_addr, max_len})

            -- ideally, we'd track an offset instead, but the offset may overflow, which is tricky to handle in lua
            byte_code = shrinko.to_memory(byte_code.get_block(max_len, #byte_code - max_len))
            data.rom_ranges.add(python.list{rom_addr, rom_addr + max_len})
            if (#byte_code != 0) results[self.id] ..= ".."

            total_len += max_len
            total_range += rom_endaddr - rom_addr
        end
        
        -- TODO: move this to a separate count report?
        printh(format("parens8 - used `1` out of `2` rom bytes", {total_len, total_range}))
    end

    if #byte_code != 0 then
        results[self.id] ..= pico_output.format_string_literal(shrinko.from_memory(byte_code))
    end

    if compress then
        local compressed_dict_lit = pico_output.format_string_literal(compressed_dict)
        results[self.id] = format("`1`(`2`, `3`)", {rename(self.ctxt, "_ps8_decompress"), results[self.id], compressed_dict_lit})
    end
end

function checked_gsub(tmpl, find, replace)
    local result = string.gsub(tmpl, find, replace)
    if (result == tmpl) stop("template changed - gsub no longer has effect")
    return result
end

function get_parens8_interpreter(opts)
    local data = get_parens8_data(opts.ctxt)
    if data.has_interpreter then
        printh("error - parens8 interpreter already written out, can't write it again") -- or could we?
    else
        data.has_interpreter = true

        printh("This cart is licensed via AGPLv3 and its source code & the license must be made available when distributing it")
        
        local decompressor = ""
        local cl_args = split_args(opts.args)
        if cl_args.compress then
            decompressor = checked_gsub(lzw_decompressor_native, '^function', 'function _ps8_decompress') -- _ for lint
            data.has_decompressor = true
        end
        if cl_args.bigstring then
            data.is_bigstring = true
        end
        if cl_args.deserialize then
            data.deserialize_kind = cl_args.deserialize
        end

        local const_name = 'ps8_const'
        local deserializer_name = 'ps8_decode'

        local hints = "--[[$lint: ps8_inst, ps8_val, ps8_binder]]"

        local template = checked_gsub(vm_template, '"`compiled_args`"', '--[[$placeholder-expr::parens8.interp_args]] ""')
        template = checked_gsub(template, '"`argcounts`"', '--[[$placeholder-expr::parens8.interp_argcounts]] ""')
        template = checked_gsub(template, 'return `runtime_ops`', '--[[$placeholder-stmt::parens8.interp_ops]] do end')
        -- 'preserve' locals used by vm ops. ideally we'd use ctxt.local_renames to rename them, but that's not trivial and not worth it
        template = checked_gsub(template, 'ps8_runtime%(a, b, c%)', 'ps8_runtime(--[[$rename::a]]a, --[[$rename::b]]b, --[[$rename::c]]c)')
        -- ignore the _ENV in the template for the purpose of safety checking, allowing to still rename globals
        template = checked_gsub(template, '%f[%w_]_ENV%f[^%w_]', '--[[$force-safe]]_ENV')
        template = checked_gsub(template, '`deserializer`', deserializer_name)
        template = checked_gsub(template, '`const`', const_name)
        
        local deserializer = data.deserialize_kind == "full" and deserializer_full or 
                             data.is_bigstring and deserializer_flat_bs or deserializer_flat
        deserializer = checked_gsub(deserializer, '`funcname`', deserializer_name)
        
        local boilerplate = checked_gsub(fp_boilerplate, '`funcname`', const_name)
        return hints .. boilerplate .. decompressor .. deserializer .. template
    end
end

function get_parens8_interp_ops(opts)
    local opfuncs = {}
    for opcode, vm_op in ipairs(vm_ops) do
		opfuncs[opcode] = vm_op[2]
	end
	return "return " .. join(opfuncs, ",\n")
end

function get_parens8_interp_args(opts)
    local compiled_args = {}
    for opcode, vm_op in ipairs(vm_ops) do
		compiled_args[opcode] = vm_op[1]
	end
	return '"' .. join(compiled_args, ",") .. '"'
end

function get_parens8_interp_argcounts(opts)
    local compiled_args = {}
    for opcode, vm_op in ipairs(vm_ops) do
		compiled_args[opcode] = vm_op[4]
	end
	return '"' .. join(compiled_args, ",") .. '"'
end

function get_parens8_run_code(opts)
    local result_id = opts.args
    return format('run_ps8(--[[$placeholder-expr::parens8.result `1`]] "")', {result_id})
end

function get_parens8_assign_code(opts)
    local sep = string.find(opts.args, " ")
    local dest = rename(opts.ctxt, sub(opts.args, 1, sep - 1))
    local result_id = sub(opts.args, sep + 1)
    return format('`1` = --[[$placeholder-expr::parens8.result `2`]] ""', {dest, result_id})
end

function get_parens8_result(opts)
    return get_parens8_data(opts.ctxt).results[opts.args]
end

function module.include_main(name)
    if (name == "parens8.interpreter") return get_parens8_interpreter
    if (name == "parens8.interp_ops") return get_parens8_interp_ops
    if (name == "parens8.interp_args") return get_parens8_interp_args
    if (name == "parens8.interp_argcounts") return get_parens8_interp_argcounts
    if (name == "parens8.run") return get_parens8_run_code
    if (name == "parens8.assign") return get_parens8_assign_code
    if (name == "parens8.result") return get_parens8_result
end

function module.compiler_main(name)
    if (name == "parens8") return Parens8Compiler
end

return module