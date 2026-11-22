shader_type canvas_item;
// Who's in the dark, drawn as an outline over them: only on the pixels
// that are dark (dithered like the floor, light.gdshaderinc).

#include "res://shaders/light.gdshaderinc"

uniform sampler2D light : filter_linear, repeat_disable;
uniform vec2 squares;
uniform vec2 origin;  // the world point of the light's top left
uniform float square_px = 4.0;
uniform float spread = 1.5;

varying vec2 world;

void vertex() {
	world = VERTEX;
}

void fragment() {
	vec2 uv = (world - origin) / (squares * square_px);
	if (light_level(light, uv, squares, spread, world) >= 0.5) {
		discard;
	}
}
