// The sea: gentle rolling waves, turquoise shallows fading to deep blue,
// and a band of foam that washes up and down the beach.
shader_type spatial;

uniform vec4 shallow_color : source_color = vec4(0.30, 0.72, 0.74, 1.0);
uniform vec4 deep_color : source_color = vec4(0.06, 0.28, 0.52, 1.0);
uniform vec4 foam_color : source_color = vec4(0.95, 0.97, 1.0, 1.0);
uniform float shore_radius = 33.0;   // distance from the village center to the waterline
uniform float wave_height = 0.04;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float w = sin(world_pos.x * 0.22 + TIME * 1.1) * wave_height
		+ sin(world_pos.z * 0.31 - TIME * 0.8) * wave_height * 0.7;
	VERTEX.y += w;
	world_pos.y += w;
}

void fragment() {
	float r = length(world_pos.xz);
	float depth = clamp((r - shore_radius) / 30.0, 0.0, 1.0);
	vec3 c = mix(shallow_color.rgb, deep_color.rgb, depth);
	// little ripples of lighter color
	float ripple = sin(world_pos.x * 1.7 + TIME * 2.0) * sin(world_pos.z * 1.3 - TIME * 1.6);
	c += vec3(0.04) * smoothstep(0.6, 1.0, ripple);
	// foam line: moves in and out like waves on the beach
	float angle = atan(world_pos.z, world_pos.x);
	float edge = shore_radius + 0.4 + sin(TIME * 0.9 + angle * 3.0) * 0.35;
	float foam = smoothstep(1.2, 0.0, abs(r - edge)) * (0.7 + 0.3 * sin(angle * 40.0 + TIME * 3.0));
	c = mix(c, foam_color.rgb, clamp(foam, 0.0, 1.0) * 0.85);
	ALBEDO = c;
	ROUGHNESS = 0.12;
	METALLIC = 0.05;
	SPECULAR = 0.7;
}
