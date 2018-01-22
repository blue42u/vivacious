std = 'lua53'
files['.luacheckrc'].global = false

stds.stdlib = {read_globals = {'newcontext', 'newtype'}}
stds.stdlib_w = {globals = {'newcontext', 'newtype'}}
stds.stdlib_g = {read_globals = {
	'integer','number','boolean','string','generic','memory','index',
	'array', 'options', 'flags', 'callable', 'compound',
}}
stds.cbound = {read_globals = {'unsigned', 'raw', 'flexmask'}}

files['apis/generator/*.lua'].std = '+stdlib'
files['apis/core/*.lua'].std = '+stdlib_w'
files['apis/*.lua'] = {
	std = '+stdlib_g',
	allow_defined_top = true,
}
files['apis/vulkan.lua'].std = '+cbound'
