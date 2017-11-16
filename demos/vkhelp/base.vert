#version 450

// Colors for the corners of the triangles
const vec4 colors[] = {
	{1, 0, 0, 1},
	{0, 1, 0, 1},
	{0, 0, 1, 1},
};

// Input for the rotation to apply
layout(location=1) in float theta;

// Output for vertex color
layout(location=0) out vec4 color;

void main() {
	// The InstanceIndex controls how many turns to make
	mat2 trans = mat2(
		cos(theta), sin(theta),
		-sin(theta), cos(theta)
	);

	// Transform the verts in xy-space, and color output
	gl_Position = vec4(trans*gl_Position.xy, 0, 1);
	color = colors[gl_VertexIndex];
}
