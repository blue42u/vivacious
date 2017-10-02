#version 450

// Coords for the other triangles
const vec2 tri[] = {
	{.2, .8},
	{.6, .8},
	{.4, .4},
};

void main() {
	// Overwrite whatever load.vert had
	gl_Position = vec4(tri[gl_VertexIndex], 0, 1);
}
