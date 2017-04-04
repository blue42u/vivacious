#version 450

layout(location=0) out vec4 outColor;

flat in uint inst;

vec3 colors[] = {
	{27, 112, 249},
	{16, 150, 34},
};

void main() {
	outColor = vec4(colors[inst]/256, 1.0);
}
