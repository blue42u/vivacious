package.path = package.path..';'..arg[2]..'/?.lua'
local slax = require 'slaxml'

io.open(arg[1], 'w'):write([[
#include "vivacious/suptest.h"

void ensure2() {
	ensure();
}
]])
