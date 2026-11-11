// Full-screen finish: dark corners, film grain, a trace of colour fringing at the edges. Camcorder feel.
shader_type canvas_item;

uniform sampler2D screen : hint_screen_texture, repeat_disable, filter_linear;
uniform float vignette = 0.62;
uniform float grain = 0.035;
uniform float fringe = 0.0025;

void fragment() {
	vec2 p = SCREEN_UV - 0.5;
	vec2 shift = p * fringe * dot(p, p) * 4.0;
	vec3 col;
	col.r = texture(screen, SCREEN_UV + shift).r;
	col.g = texture(screen, SCREEN_UV).g;
	col.b = texture(screen, SCREEN_UV - shift).b;
	float corner = smoothstep(0.30, 0.82, length(p * vec2(1.0, 0.9)));
	col *= 1.0 - corner * vignette;
	float n = fract(sin(dot(FRAGCOORD.xy + fract(TIME) * 613.0, vec2(12.9898, 78.233))) * 43758.5453) - 0.5;
	col += n * grain;
	COLOR = vec4(col, 1.0);
}
