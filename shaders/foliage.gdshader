// Leaves: gentle wind sway, per-tree color tint, and a dithered fade when the
// camera gets close (so trees never hide the player).
shader_type spatial;

instance uniform vec4 tint : source_color = vec4(1.0);
uniform float sway_strength = 0.05;
uniform float fade_min = 3.5;
uniform float fade_max = 7.5;

void vertex() {
	vec3 origin = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float h = max(VERTEX.y - 1.5, 0.0);
	float t = TIME * 1.4 + origin.x * 0.35 + origin.z * 0.27;
	VERTEX.x += sin(t) * sway_strength * h;
	VERTEX.z += cos(t * 0.8) * sway_strength * 0.6 * h;
}

void fragment() {
	// vertex colors are authored in sRGB; convert to linear for lighting
	ALBEDO = pow(COLOR.rgb, vec3(2.2)) * tint.rgb;
	ROUGHNESS = 0.9;
	float d = length(VERTEX);
	float a = clamp((d - fade_min) / (fade_max - fade_min), 0.0, 1.0);
	float n = fract(52.9829189 * fract(dot(FRAGCOORD.xy, vec2(0.06711056, 0.00583715))));
	if (a < n) {
		discard;
	}
}
