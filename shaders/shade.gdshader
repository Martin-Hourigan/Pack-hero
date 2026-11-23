shader_type canvas_item;
// The fog and the light over the floor. sight: per square, a byte, 1 in
// sight now; seen: 1 seen before; light: see light.gdshaderinc.

#include "res://shaders/light.gdshaderinc"

uniform sampler2D sight : filter_nearest, repeat_disable;
uniform sampler2D seen : filter_nearest, repeat_disable;
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
	if (texture(sight, UV).r < 0.5 / 255.0) {
		COLOR = vec4(0.0, 0.0, 0.0, texture(seen, UV).r < 0.5 / 255.0 ? 1.0 : greyed);
	} else {
		float l = light_level(light, UV, squares, spread, world);
		COLOR = vec4(0.0, 0.0, 0.0, l >= 1.5 ? 0.0 : (l >= 0.5 ? dim_shade : dark_shade));
	}
}
