/**************************************************************************
   Copyright 2016 Jonathon Anderson

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
***************************************************************************/

#ifndef H_vivacious_core
#define H_vivacious_core

// Convience macro for typedefing structures. Because repeatition is often bad.
// Use with a semicolon.
#define _Vv_TYPEDEF(name) typedef struct name name

// Convience macro for defining structure-based API types. Saves some typing.
// To be used as:
// _Vv_STRUCT(MyAwesomeStructure) {
//	int mySuperAwesomeMember;
// };
#define _Vv_STRUCT(name) \
_Vv_TYPEDEF(name); \
struct name

// Convience macro for defining enum-based API types. Saves some typing.
// To be used as:
// _Vv_ENUM(MyAwesomeEnum) {
//	MyAwesomeConstant, MyOtherAwesomeConstant,
// };
#define _Vv_ENUM(name) \
typedef enum name name; \
enum name

#endif // H_vivacious_core
