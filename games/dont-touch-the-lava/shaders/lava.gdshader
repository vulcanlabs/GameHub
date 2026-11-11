// Adapted from https://godotshaders.com/shader/lava-shader-animated/
// by miwls. CanvasItem version uses COLOR and SCREEN_UV for a sprite.
// This spatial version keeps that animation and paints it on the lava mesh.

shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_opaque, cull_back;

uniform sampler2D noise_texture : hint_default_white, repeat_enable;

uniform float scroll_x             : hint_range(-2.0, 2.0)  = 0.30;
uniform float scroll_y             : hint_range(-2.0, 2.0)  = 0.15;

uniform float noise_scale          : hint_range(0.0, 10.0)  = 1.0;

uniform float wave_amplitude       : hint_range(0.0, 0.12)  = 0.018;
uniform float wave_frequency       : hint_range(1.0, 20.0)  = 6.0;
uniform float wave_speed           : hint_range(0.0, 5.0)   = 1.20;
uniform float wave_secondary       : hint_range(0.0, 1.0)   = 0.40;

uniform float noise_wave_amplitude : hint_range(0.0, 0.3)   = 0.060;
uniform float noise_wave_frequency : hint_range(1.0, 20.0)  = 4.0;
uniform float noise_wave_speed     : hint_range(0.0, 5.0)   = 0.80;
uniform float noise_wave_secondary : hint_range(0.0, 1.0)   = 0.50;

uniform float inner_margin         : hint_range(0.01, 0.35) = 0.100;

uniform vec4  noise_color_1        : source_color = vec4(1.000, 0.133, 0.000, 1.0);
uniform vec4  noise_color_2        : source_color = vec4(1.000, 0.467, 0.000, 1.0);
uniform vec4  noise_color_3        : source_color = vec4(1.000, 0.933, 0.000, 1.0);

uniform float oscillation_speed    : hint_range(0.0, 5.0)   = 1.00;
uniform float oscillation_strength : hint_range(0.0, 1.0)   = 0.25;

uniform float noise_glow_strength  : hint_range(0.0, 3.0)   = 1.20;

uniform float outer_glow_level     : hint_range(0.0, 10.0)  = 4.00;
uniform float outer_glow_power     : hint_range(1.0, 8.0)   = 3.0;
uniform vec4  outer_glow_primary   : source_color = vec4(1.000, 0.267, 0.000, 1.0);
uniform vec4  outer_glow_secondary : source_color = vec4(1.000, 0.000, 0.000, 1.0);

void fragment() {
	vec2 uv = UV;
	float t = TIME;

	float t1 = t * wave_speed;
	float wx = sin(uv.y * wave_frequency + t1) * wave_amplitude
		+ sin(uv.y * wave_frequency * 1.7 + t1 * 0.7 + 1.5) * wave_amplitude * wave_secondary;
	float wy = sin(uv.x * wave_frequency * 0.8 + t1 * 1.3) * wave_amplitude
		+ sin(uv.x * wave_frequency * 1.3 + t1 * 1.1 + 3.1) * wave_amplitude * wave_secondary;

	vec2 wuv = uv + vec2(wx, wy);

	float dist_x = min(wuv.x, 1.0 - wuv.x);
	float dist_y = min(wuv.y, 1.0 - wuv.y);
	float edge_dist = min(dist_x, dist_y);

	float lava_mask = step(inner_margin, edge_dist);
	float glow_t = clamp(edge_dist / inner_margin, 0.0, 1.0);

	float t2 = t * noise_wave_speed;
	vec2 suv = UV;
	float nwx = sin(suv.y * noise_wave_frequency + t2) * noise_wave_amplitude
		+ sin(suv.y * noise_wave_frequency * 2.1 + t2 * 0.6 + 2.3) * noise_wave_amplitude * noise_wave_secondary;
	float nwy = sin(suv.x * noise_wave_frequency * 0.9 + t2 * 1.4) * noise_wave_amplitude
		+ sin(suv.x * noise_wave_frequency * 1.5 + t2 * 1.2 + 0.8) * noise_wave_amplitude * noise_wave_secondary;

	vec2 noise_uv = (suv + vec2(nwx, nwy)) * noise_scale + vec2(scroll_x, scroll_y) * t;
	float noise_val = texture(noise_texture, noise_uv).r;
	float noise_edge = texture(noise_texture, suv * noise_scale + vec2(scroll_x, scroll_y) * t).r;

	float osc = sin(t * oscillation_speed) * oscillation_strength * 0.5;
	float noise_shifted = clamp(noise_val + osc, 0.0, 1.0);

	vec4 lava_col;
	if (noise_shifted < 0.4) {
		lava_col = mix(noise_color_1, noise_color_2, noise_shifted / 0.4);
	} else {
		lava_col = mix(noise_color_2, noise_color_3, (noise_shifted - 0.4) / 0.6);
	}

	lava_col.rgb += lava_col.rgb * pow(noise_val, 2.5) * noise_glow_strength;

	float falloff = pow(glow_t, outer_glow_power);
	vec4 glow_col = mix(outer_glow_secondary, outer_glow_primary, falloff);
	glow_col.rgb *= 1.0 + noise_edge * 0.4;
	float glow_alpha = clamp(falloff * outer_glow_level * 0.15, 0.0, 1.0);

	vec3 rgb = mix(glow_col.rgb, lava_col.rgb, lava_mask);
	float alpha = mix(glow_alpha, 1.0, lava_mask);

	ALBEDO = rgb;
	EMISSION = rgb;
	ALPHA = alpha;
}
