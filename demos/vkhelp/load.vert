#version 450

// Load from the vertex Buffer
layout(location=0) in vec2 vert;

void main() {
	// Just put it out
	gl_Position = vec4(vert, 0, 1);
}
