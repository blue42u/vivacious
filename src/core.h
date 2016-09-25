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

#ifndef H_core
#define H_core

#if defined(__clang__) && __has_attribute(visibility)
#	define VvAPI __attribute__((visibility("default")))
#elif defined(__GNUC__) && __GNUC__ >= 4
#	define VvAPI __attribute__((visibility("default")))
#else
#	warning "No visibility attribute availible!"
#	define VvAPI
#endif

#endif // H_core
