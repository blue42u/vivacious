local f = io.open(arg[1], 'w')

f:write([[
#include <stdio.h>

void ensure();
]])

f:close()
