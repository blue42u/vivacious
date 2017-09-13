#version 450

layout(push_constant) uniform consts {
	uint id;
};

out gl_PerVertex {
	vec4 gl_Position;
};

out uint inst;

vec2 pos[] = {
	{-.5, .75},
	{-.5, -.75},
	{0, 0},
};

void main() {
	gl_Position = vec4(pos[gl_VertexIndex] + vec2(id*.3+
		gl_InstanceIndex*.1, 0), 0.0, 1.0);
	inst = gl_InstanceIndex;
}
