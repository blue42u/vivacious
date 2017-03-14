#version 450

layout(push_constant) uniform consts {
	uint id;
};

out gl_PerVertex {
	vec4 gl_Position;
};

vec2 pos[] = {
	{0, .75},
	{0, -.75},
	{.5*id, 0},
};

void main() {
	gl_Position = vec4(pos[gl_VertexIndex], 0.0, 1.0);
}
