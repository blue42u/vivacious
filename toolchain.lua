-- luacheck: no global (Disable globals checking)

-- Since there's a lot of things to test... a testing function!
local function test(exec)
	local p = io.popen(exec..' 2>&1')
	p:read(1)	-- Make sure the subprocess gets access to the pipe
	return not not p:close()
end

-- If our host system is Linux, we check the following, in order:
-- - The CC and AR environment variables
-- - clang (ar), gcc (ar), and cc (ar) on the PATH
if tup.getconfig 'TUP_PLATFORM' == 'linux' then
	if not HOST_CC then
		if test '${CC} --version' then HOST_CC = '${CC}'
		elseif test 'clang --version' then HOST_CC = 'clang'
		elseif test 'gcc --version' then HOST_CC = 'gcc'
		elseif test 'cc --version' then HOST_CC = 'cc' end
		if not HOST_LDLIBS then HOST_LDLIBS = '-ldl -lm' end
	end
	if not HOST_AR then
		if test '${AR} --version' then HOST_AR = '${AR}'
		elseif test 'ar --version' then HOST_AR = 'ar' end
	end
end

-- If all else fails... well, we error.
assert(HOST_CC, 'No host C compiler is available, cannot continue!')
assert(HOST_AR, 'No host C archiver is available, cannot continue!')

-- Get the TARGET from the config, or use the HOST's settings
for part,dep in pairs{
	CPPFLAGS='CC', CFLAGS='CC', LDFLAGS='CC', LDLIBS='CC',
	CC=false, AR=false,
} do
	local nam = 'TARG_'..part
	if tup.getconfig(part) ~= '' then _G[nam] = tup.getconfig(part)
	elseif dep and tup.getconfig('HOST_'..dep) then _G[nam] = ''
	else _G[nam] = _G['HOST_'..part] end
end
