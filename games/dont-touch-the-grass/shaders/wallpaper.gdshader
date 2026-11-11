// Backrooms wallpaper: faded mustard paper with a small chevron print, sun-bleached unevenly,
// dark damp creeping up from the grass, brown drip stains coming down from the ceiling.
shader_type spatial;

uniform vec3 paper_color : source_color = vec3(0.66, 0.56, 0.27);
uniform vec3 print_color : source_color = vec3(0.50, 0.41, 0.17);
uniform vec3 damp_color : source_color = vec3(0.10, 0.11, 0.045);
uniform sampler2D noise : hint_default_white, repeat_enable, filter_linear_mipmap;
uniform sampler2D stain_noise : hint_default_white, repeat_enable, filter_linear_mipmap;
uniform float room_height = 5.0;

varying vec3 world_position;
varying vec3 world_normal;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	// u runs along the wall, v is height above the floor.
	float u = abs(world_normal.x) > 0.5 ? world_position.z : world_position.x;
	float v = world_position.y;

	// Print: rows of small chevrons, every other row shifted half a step.
	vec2 cell = vec2(u / 0.16, v / 0.22);
	cell.x += mod(floor(cell.y), 2.0) * 0.5;
	vec2 f = fract(cell) - 0.5;
	float chevron = abs(f.y + abs(f.x) * 0.9 - 0.14);
	float motif = (1.0 - smoothstep(0.035, 0.075, chevron)) * (1.0 - smoothstep(0.22, 0.30, abs(f.x)));
	// Paper comes in 0.53 m rolls: a faint dark line where two strips meet.
	float seam = 1.0 - smoothstep(0.003, 0.010, abs(fract(u / 0.53) - 0.5));

	float fade = texture(stain_noise, vec2(u, v) * 0.11).r;
	float cloud = texture(stain_noise, vec2(u, v) * 0.045 + 0.31).r;
	float grain = texture(noise, vec2(u, v) * 0.9).r;
	float streak = texture(stain_noise, vec2(u * 0.55, v * 0.035) + 0.7).r;

	vec3 col = mix(paper_color, print_color, max(motif * 0.55, seam * 0.6));
	col *= mix(0.70, 1.04, fade);
	col *= mix(0.94, 1.03, grain);

	// Damp: a soft-edged dark tide line that rises higher in some places than others.
	float tide = 0.35 + cloud * 1.5;
	float damp = 1.0 - smoothstep(tide * 0.35, tide, v);
	col = mix(col, damp_color, damp * 0.88);
	col = mix(col, col * 0.72, (1.0 - smoothstep(tide, tide + 0.5, v)) * 0.6);

	float drip = smoothstep(room_height - 2.6, room_height, v) * smoothstep(0.50, 0.72, streak);
	col = mix(col, col * vec3(0.40, 0.33, 0.22), drip * 0.85);

	ALBEDO = col;
	ROUGHNESS = mix(0.93, 0.5, damp);
}
