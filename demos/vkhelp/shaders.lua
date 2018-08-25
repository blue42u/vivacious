--[========================================================================[
   Copyright 2016-2017 Jonathon Anderson

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
--]========================================================================]

io.output(table.remove(arg, 1))
local function out(s) io.write(s..'\n') end

out([[
#include <vivacious/vulkan.h>
]])

for _,fn in ipairs(arg) do
	out('static uint32_t spv_'..fn:match '([^/]+)%.spv$'..'[] = {')
	local f = io.open(fn, 'r')
	for word in f:lines(4) do
		out(string.unpack('<I4', word)..',')
	end
	f:close()
	out '};'
end
