#version 450

// Vertex color, which is interpolated
layout(location=0) in vec4 vcolor;

// Frag color out
layout(location=0) out vec4 color;

void main() {
	// Tada.
	color = vcolor;
}
