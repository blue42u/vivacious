-- luacheck: no global (This is a Tup-Lua file)

local function test(exp)
	local p = io.popen(exp..' 2>&1', 'r')
	p:read(1)
	return not not p:close()
end

if tup.getconfig 'XCB_CFLAGS' ~= '' or tup.getconfig 'XCB_LDLIBS' ~= '' then
	XCB_CFLAGS = tup.getconfig 'XCB_CFLAGS'
	XCB_LDLIBS = tup.getconfig 'XCB_LDLIBS'
elseif test('pkg-config --exists xcb') then
	-- All output should be on one line, so we only get the first line.
	local pc,pl = io.popen 'pkg-config --cflags xcb', io.popen 'pkg-config --libs xcb'
	XCB_CFLAGS,XCB_LDLIBS = pc:read 'l', pl:read 'l'
	pc:close()
	pl:close()
else
	error "No reasonable way to find libxcb!"
end
