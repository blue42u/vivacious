/**************************************************************************
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
***************************************************************************/

#include <libvivacious.h>
#include "internal.h"

#ifdef Vv_ENABLE_X
extern const Vv_Window libVv_wi_x;
#endif // Vv_ENABLE_X

VvAPI const struct libVv_Window libVv_wi = {
#ifdef Vv_ENABLE_X
	.x = &libVv_wi_x,
#else
	.x = NULL,
#endif
};

VvAPI const Vv_Window* vVwi(const Vv* V) {
	// For now, just use X
	return libVv_wi.x;
}
