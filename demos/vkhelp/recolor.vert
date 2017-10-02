#version 450

// Color output, must match up with the other
layout(location=0) out vec4 color;

void main() {
	// "Transform" the color to secondary colors
	color = mat4(
		.5, .5,  0,  0,
		 0, .5, .5,  0,
		.5,  0, .5,  0,
		 0,  0,  0,  1) * color;
}
