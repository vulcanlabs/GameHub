// Soft column of light standing on the finish pad. Fades out toward the top.
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec3 glow_color : source_color = vec3(0.55, 1.0, 0.90);
uniform float height = 2.2;

varying float rise;

void vertex() {
	rise = clamp(VERTEX.y / height + 0.5, 0.0, 1.0);
}

void fragment() {
	float fade = (1.0 - rise) * (1.0 - rise);
	float a = fade * (0.10 + 0.04 * sin(TIME * 2.2));
	ALBEDO = glow_color * a;
	ALPHA = a;
}
