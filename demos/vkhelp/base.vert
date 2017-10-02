#version 450

// This rotates around the origin by 90 degrees
const mat2 turn = mat2(
	 0, 1,
	-1, 0
);

// Colors for the corners of the triangles
const vec4 colors[] = {
	{1, 0, 0, 1},
	{0, 1, 0, 1},
	{0, 0, 1, 1},
};

// Output for vertex color
layout(location=0) out vec4 color;

void main() {
	// The InstanceIndex controls how many turns to make
	mat2 trans = mat2(
		1, 0,
		0, 1
	);
	for(int i=0; i<gl_InstanceIndex; i++)
		trans *= turn;

	// Transform the verts in xy-space, and color output
	gl_Position = vec4(trans*gl_Position.xy, 0, 1);
	color = colors[gl_VertexIndex];
}
