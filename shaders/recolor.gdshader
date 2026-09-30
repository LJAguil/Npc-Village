// Swaps the purple parts of the Kenney robot texture to another hue,
// so every NPC can share one model but still look different.
shader_type spatial;

uniform sampler2D tex : source_color, filter_linear_mipmap;
uniform float target_hue = 0.0;
uniform float source_hue = 0.74;   // the robot's purple

vec3 rgb2hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 hsv2rgb(vec3 c) {
	vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
	vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
	return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

void fragment() {
	vec3 col = texture(tex, UV).rgb;
	vec3 hsv = rgb2hsv(col);
	float d = abs(hsv.x - source_hue);
	d = min(d, 1.0 - d);
	if (d < 0.08 && hsv.y > 0.25) {
		hsv.x = target_hue;
		col = hsv2rgb(hsv);
	}
	ALBEDO = col;
	ROUGHNESS = 0.8;
}
