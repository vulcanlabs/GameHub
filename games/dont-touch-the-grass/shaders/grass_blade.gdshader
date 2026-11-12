// Grass tufts: UV.y gradient plus world noise (StayAtHomeDev style). Indoors there is no wind, so the slow sway reads as wrong.
// `stir` goes to 1 while monsters chase: the whole floor shivers.
shader_type spatial;
// specular_disabled: grass has no shine worth paying for, and it is most of the pixels on screen.
render_mode cull_disabled, blend_mix, depth_draw_opaque, specular_disabled;

uniform vec3 color : source_color = vec3(0.035, 0.075, 0.02);
uniform vec3 color2 : source_color = vec3(0.20, 0.26, 0.07);
uniform vec3 dry : source_color = vec3(0.40, 0.34, 0.12);
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
	NORMAL = vec3(0.0, 1.0, 0.0);
}

void fragment() {
	float n = texture(noise, world_position.xz / noise_scale).x;
	float fine = texture(noise, world_position.xz * 0.35 + 1.7).x;
	vec3 gradient = mix(color, color2, smoothstep(0.12, 0.92, UV.y));
	gradient *= mix(0.62, 1.22, fine);
	vec3 blade = mix(gradient, gradient * mix(0.8, 1.1, n), noise_mix);
	float straw = smoothstep(0.68, 1.0, UV.y) * smoothstep(0.38, 0.75, fine);
	ALBEDO = mix(blade, dry, straw * 0.5);
	ROUGHNESS = 0.9;
	EMISSION = vec3(0.0);
}
