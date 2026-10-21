shader_type canvas_item;

// Full-screen retro pass: mild barrel distortion, chromatic aberration, scanlines, vignette.
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float barrel = 0.03;
uniform float scan_strength = 0.035;

void fragment() {
	vec2 cc = SCREEN_UV - 0.5;
	float d = dot(cc, cc);
	vec2 uv = cc * (1.0 + d * barrel) + 0.5;
	float ca = 0.0004 + d * 0.0018;
	vec3 col;
	col.r = texture(screen_tex, uv + vec2(ca, 0.0)).r;
	col.g = texture(screen_tex, uv).g;
	col.b = texture(screen_tex, uv - vec2(ca, 0.0)).b;
	col *= 1.0 - scan_strength + scan_strength * sin(uv.y * 720.0 * 3.14159);
	col *= 1.0 - smoothstep(0.25, 0.9, d * 2.4) * 0.22;
	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
		col = vec3(0.0);
	}
	COLOR = vec4(col, 1.0);
}
