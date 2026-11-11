// Finish pad: a square of cold light on the last platform. Rings travel outward from the middle.
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec3 glow_color : source_color = vec3(0.55, 1.0, 0.90);

void fragment() {
	vec2 p = abs(UV * 2.0 - 1.0);
	// Rounded square distance: 0 in the middle, 1 on the rim.
	float r = pow(pow(p.x, 4.0) + pow(p.y, 4.0), 0.25);
	float pulse = 0.5 + 0.5 * sin(TIME * 2.2);
	float rim = smoothstep(0.09, 0.0, abs(r - 0.86));
	float wave_at = fract(TIME * 0.3) * 0.86;
	float wave = smoothstep(0.06, 0.0, abs(r - wave_at)) * (1.0 - wave_at);
	float core = smoothstep(0.86, 0.0, r) * mix(0.35, 0.55, pulse);
	float a = (rim * 1.3 + wave * 0.9 + core) * smoothstep(1.0, 0.92, r);
	ALBEDO = glow_color * a * 2.4;
	ALPHA = clamp(a, 0.0, 1.0);
}
