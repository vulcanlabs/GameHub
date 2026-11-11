// Worn ceramic floor tiles: pale beige squares, thin grout, mottled stains, hairline cracks.
shader_type spatial;

uniform vec3 tile_color : source_color = vec3(0.78, 0.73, 0.58);
uniform vec3 grout_color : source_color = vec3(0.38, 0.35, 0.28);
uniform vec3 stain_color : source_color = vec3(0.34, 0.30, 0.22);
uniform sampler2D noise : hint_default_white, repeat_enable, filter_linear_mipmap;
uniform float tile_size = 0.52;

varying vec3 world_position;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 t = world_position.xz / tile_size;
	vec2 id = floor(t);
	vec2 f = fract(t);
	float edge = min(min(f.x, 1.0 - f.x), min(f.y, 1.0 - f.y));
	float grout = 1.0 - smoothstep(0.012, 0.028, edge);

	float n1 = texture(noise, world_position.xz * 0.55).r;
	float n2 = texture(noise, world_position.xz * 1.8 + 2.1).r;
	float n3 = texture(noise, world_position.xz * 4.6 + 7.0).r;
	vec3 tile = tile_color * mix(0.88, 1.04, hash(id + 4.1));
	tile *= mix(0.9, 1.05, n2);
	tile += (n3 - 0.5) * 0.04;

	float blot = smoothstep(0.52, 0.82, texture(noise, world_position.xz * 0.11 + id * 0.03).r);
	float smear = smoothstep(0.58, 0.88, texture(noise, world_position.xz * 0.28 + 1.4).r);
	tile = mix(tile, stain_color, blot * 0.55 + smear * 0.22);
	tile = mix(tile, tile * 0.78, (1.0 - n1) * 0.18);

	float crack_line = abs(f.y - 0.37 - 0.08 * n2);
	float crack = (1.0 - grout) * step(0.62, hash(id + 9.1)) * (1.0 - smoothstep(0.004, 0.012, crack_line));
	tile = mix(tile, grout_color * 0.7, crack * 0.55);

	ALBEDO = mix(tile, grout_color, grout);
	ROUGHNESS = mix(0.86, 0.96, grout + blot * 0.3);
	NORMAL_MAP = vec3(n3, n2, 1.0);
	NORMAL_MAP_DEPTH = 0.18;
}
