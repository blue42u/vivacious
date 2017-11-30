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

TestObject = {doc=[[
	A testing-worthy object.
]], header='test',
	v0_1_0 = {
		{'defaultx', integer{}},
	},
}

TestObject.typedef.Test = compound{
	v0_1_2 = {
		{'a', integer{}},
		{'b', boolean{}},
		{'c', integer{}, 5},
		{'d', boolean{}, true},
	},
}

TestObject.v0_1_0.testMethod = {doc=[[
	Testing method.
]],
	{'a', TestObject.Test}, {'b', boolean{}, false},
	{integer{}}, {integer{}},
}

TestObject.v0_0_1.test2 = {doc=[[
	Another testing thing.
]],
	{'x', integer{}}, {'s', compound{
		v0_1_2={
			{'a', integer{}},
		},
		v0_2_1={
			{'x', boolean{}},
		},
	}},
	{integer{}}, {boolean{}, c_main=true},
}

TestObject.v0_1_0.testP = {doc=[[
	Another testing thing.
]],
	{'x', integer{}},
	{integer{}}, {boolean{}, c_main=true},
}

TestObject.TestChild = {doc=[[
	Test child.
]],
	v0_1_0={
		{'test', boolean{}},
	},
}

TestObject.TestChild.v0_1_1.test2 = {doc=[[
	A third testing method.
]],
	{'x', integer{}}, {'y', integer{}},
	{boolean{}},
}

OtherTest = {doc=[[
	Another testing thing.
]], header='test',
	TestObject,
}
