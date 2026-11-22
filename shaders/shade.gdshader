shader_type canvas_item;
// The fog and the light over the floor. fog: per square, 0 never seen, 0.5
// seen before, 1 in sight. light: per square, 0 dark, 0.5 dim, 1 lit;
// smoothed over `spread` squares, then dithered (4x4 ordered) between
// lit / dim / dark, so the edges break up instead of a hard line.

uniform sampler2D fog : filter_nearest, repeat_disable;
uniform sampler2D light : filter_linear, repeat_disable;
uniform vec2 squares;
uniform float spread = 1.5;
uniform float greyed = 0.65;
uniform float dim_shade = 0.4;
uniform float dark_shade = 0.7;

varying vec2 world;

const float BAYER[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

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
		float v = 0.0;
		for (int dx = -2; dx <= 2; dx++) {
			for (int dy = -2; dy <= 2; dy++) {
				v += texture(light, UV + vec2(float(dx), float(dy)) * spread / 2.0 / squares).r;
			}
		}
		float lvl = v / 25.0 * 2.0;
		ivec2 p = ivec2(mod(floor(world), 4.0));
		float t = (BAYER[p.y * 4 + p.x] + 0.5) / 16.0;
		float l = floor(lvl) + (fract(lvl) > t ? 1.0 : 0.0);
		COLOR = vec4(0.0, 0.0, 0.0, l >= 1.5 ? 0.0 : (l >= 0.5 ? dim_shade : dark_shade));
	}
}
