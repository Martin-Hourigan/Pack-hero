// The light at a world pixel: per square 0 dark, 0.5 dim, 1 lit, smoothed
// over `spread` squares, then dithered (4x4 ordered) to 0 dark, 1 dim or
// 2 lit, so the edges break up instead of a hard line.

const float BAYER[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

float light_level(sampler2D light, vec2 uv, vec2 squares, float spread, vec2 world) {
	float v = 0.0;
	for (int dx = -2; dx <= 2; dx++) {
		for (int dy = -2; dy <= 2; dy++) {
			v += texture(light, uv + vec2(float(dx), float(dy)) * spread / 2.0 / squares).r;
		}
	}
	float lvl = v / 25.0 * 2.0;
	ivec2 p = ivec2(mod(floor(world), 4.0));
	float t = (BAYER[p.y * 4 + p.x] + 0.5) / 16.0;
	return floor(lvl) + (fract(lvl) > t ? 1.0 : 0.0);
}
