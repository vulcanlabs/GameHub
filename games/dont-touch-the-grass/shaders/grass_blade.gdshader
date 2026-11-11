// Grass tufts: UV.y gradient plus world noise (StayAtHomeDev style). Indoors there is no wind, so the slow sway reads as wrong.
// `stir` goes to 1 while monsters chase: the whole floor shivers.
shader_type spatial;
// specular_disabled: grass has no shine worth paying for, and it is most of the pixels on screen.
render_mode cull_disabled, blend_mix, depth_draw_opaque, specular_disabled;

uniform vec3 color : source_color = vec3(0.012, 0.075, 0.010);
uniform vec3 color2 : source_color = vec3(0.17, 0.56, 0.06);
uniform sampler2D noise : hint_default_white, repeat_enable, filter_linear;
uniform float noise_scale = 9.0;
uniform float noise_mix = 0.5;
uniform float stir = 0.0;

varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 w = world_position.xz;
	float bend = UV.y * UV.y;
	float calm = sin(TIME * 0.7 + w.x * 0.35 + w.y * 0.27) + 0.5 * sin(TIME * 1.3 + w.y * 0.9);
	float shiver = sin(TIME * 14.0 + w.x * 3.1 + w.y * 2.3);
	float amount = calm * 0.05 + shiver * 0.09 * stir;
	VERTEX.x += amount * bend;
	VERTEX.z += amount * bend * 0.6;
	// Light every blade like the floor under it. Per-triangle normals make thin blades sparkle.
	NORMAL = vec3(0.0, 1.0, 0.0);
}

void fragment() {
	float n = texture(noise, world_position.xz / noise_scale).x;
	vec3 gradient = mix(color, color2, UV.y);
	ALBEDO = mix(gradient, gradient * n, noise_mix);
	ROUGHNESS = 0.85;
	// Faint self-glow keeps the green readable in dark corners. It is what makes the grass look unnatural.
	EMISSION = color2 * UV.y * mix(0.02, 0.06, stir);
}
