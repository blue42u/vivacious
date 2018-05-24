--[========================================================================[
   Copyright 2016-2018 Jonathon Anderson

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

-- luacheck: globals array method callable versioned
local vk = require 'vulkan-raw'

vk.version = {__raw='uint32_t', __name="'M.m.p'"}

-- This is the most basic debugging-level transformation done: indicating _len
-- and _extraptr in the name of __index fields
local handled = {}
local function tinker(e)
	if handled[e] then return end
	handled[e] = true
	if e._extraptr then e.name = '\\*'..e.name end
  if e._len then e.name = e.name..'#['..e._len..']' end
	if e._value then e.doc = 'Automatically set to '..e._value end
	for _,e2 in ipairs(e.type.__index or {}) do tinker(e2) end
	for _,e2 in ipairs(e.type.__call or {}) do tinker(e2) end
end

for _,v in pairs(vk) do if not handled[v] then -- Anti-alias handling
	for _,e in ipairs(v.__index or {}) do tinker(e) end
end end

return vk
