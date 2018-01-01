local f = io.open('vivacious.h', 'w')
f:write[[
// Generated from apis/vivacious.lua, do not edit

]]

for _,s in ipairs(arg) do
	f:write('#include <vivacious/'..s..'.h>\n')
end

f:close()
