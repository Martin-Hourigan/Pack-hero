shader_type canvas_item;
// The fog and the light over the floor. fog: per square, 0 never seen, 0.5
// seen before, 1 in sight. light: see light.gdshaderinc.

#include "res://shaders/light.gdshaderinc"

uniform sampler2D fog : filter_nearest, repeat_disable;
uniform sampler2D light : filter_linear, repeat_disable;
uniform vec2 squares;
uniform float spread = 1.5;
uniform float greyed = 0.65;
uniform float dim_shade = 0.4;
uniform float dark_shade = 0.7;

varying vec2 world;

void vertex() {
	world = VERTEX;
}

void fragment() {
	float f = texture(fog, UV).r;
	if (f < 0.25) {
		COLOR = vec4(0.0, 0.0, 0.0, 1.0);
	} else if (f < 0.75) {
		COLOR = vec4(0.0, 0.0, 0.0, greyed);
	} else {
		float l = light_level(light, UV, squares, spread, world);
		COLOR = vec4(0.0, 0.0, 0.0, l >= 1.5 ? 0.0 : (l >= 0.5 ? dim_shade : dark_shade));
	}
}
