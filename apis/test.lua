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

Test = {}

Test.type.Def1 = integer
Test.type.Def2 = compound{
	{'a', integer},
	{'b', number, 5.3},
}

Test.v1_2_3.testmeth = {
	returns = {integer},
	{'c', number}
}

Test.v1_2_3.rw.a = integer
Test.v1_2_3.ro.b = array{integer}

Test.Little = {}
Test.Little.v3_2_1.meth = {
	{'d', boolean}
}
