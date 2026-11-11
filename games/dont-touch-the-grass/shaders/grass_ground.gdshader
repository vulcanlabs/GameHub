// Ground under the tufts: the blade base green plus world noise, kept dark so gaps between blades read as depth.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;

uniform vec3 color : source_color = vec3(0.07, 0.05, 0.028);
uniform vec3 color2 : source_color = vec3(0.06, 0.12, 0.032);
uniform sampler2D noise : hint_default_white, repeat_enable, filter_linear;
uniform float noise_scale = 9.0;
uniform float noise_mix = 0.5;

varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float n = texture(noise, world_position.xz / noise_scale).x;
	vec3 soil = mix(color, color * mix(0.75, 1.15, n), noise_mix);
	ALBEDO = mix(soil, color2, 0.35 + n * 0.25);
	ROUGHNESS = 0.95;
}
