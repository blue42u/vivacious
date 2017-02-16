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

#include "common.h"

int main() {
	setupVk();
	setupCb();

	VvVkP_Builder* b = vkp.create(&vkbind, 0, NULL);

	VvVkP_Operation* ops[3];

	ops[0] = vkp.addOperation(b, NULL, NULL, NULL,
		0, NULL,
		0, NULL);

	ops[1] = vkp.addOperation(b, NULL, NULL, NULL,
		0, NULL,
		1, (VvVkP_Dependency[]){ {ops[0]} });

	ops[2] = vkp.addOperation(b, NULL, NULL, NULL,
		0, NULL,
		0, NULL);

	vkp.depends(b, ops[2], 2, (VvVkP_Dependency[]){ {ops[0]}, {ops[1]} });

	vkp.removeOperation(b, ops[1]);

	vkp.destroy(b);

	cleanupCb();
	cleanupVk();
	return 0;
}
