// Drop ceiling: 0.6 m acoustic tiles in a metal grid, water stains, a few tiles missing.
shader_type spatial;

uniform vec3 tile_color : source_color = vec3(0.62, 0.58, 0.44);
uniform vec3 bar_color : source_color = vec3(0.36, 0.34, 0.27);
uniform vec3 stain_color : source_color = vec3(0.24, 0.17, 0.08);
uniform sampler2D noise : hint_default_white, repeat_enable, filter_linear_mipmap;
uniform float tile_size = 0.6;
uniform vec2 tile_offset = vec2(0.0, 0.3);
uniform float missing_ratio = 0.035;

varying vec3 world_position;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 t = (world_position.xz - tile_offset) / tile_size;
	vec2 id = floor(t);
	vec2 f = fract(t);
	float edge = min(min(f.x, 1.0 - f.x), min(f.y, 1.0 - f.y));
	float bar = 1.0 - smoothstep(0.018, 0.03, edge);

	vec3 tile = tile_color * mix(0.74, 1.0, hash(id + 7.3));
	float speckle = texture(noise, world_position.xz * 2.3).r;
	tile *= mix(0.80, 1.0, smoothstep(0.35, 0.5, speckle));
	float stain = smoothstep(0.56, 0.80, texture(noise, world_position.xz * 0.06 + 0.5).r);
	tile = mix(tile, stain_color, stain * 0.75);

	float missing = step(hash(id), missing_ratio);
	tile = mix(tile, vec3(0.004), missing);

	ALBEDO = mix(tile, bar_color, bar);
	ROUGHNESS = 0.95;
}
