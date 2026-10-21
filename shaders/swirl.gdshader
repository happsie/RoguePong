shader_type canvas_item;

// Arcade-party backdrop: wobbly sunburst rays, a halftone dot wash and drifting ping-pong balls.
// Kept dark and low-contrast near the middle so the table and ball carry the eye.
uniform vec4 col_a : source_color = vec4(0.12, 0.07, 0.20, 1.0);
uniform vec4 col_b : source_color = vec4(0.55, 0.13, 0.30, 1.0);
uniform vec4 col_c : source_color = vec4(0.05, 0.28, 0.46, 1.0);
uniform float spin_speed = 0.18;

float ball_layer(vec2 uv, float t, float seed) {
	vec2 g = uv * 3.0 + vec2(t * 0.15 * (seed + 1.0), -t * 0.1);
	vec2 id = floor(g);
	vec2 f = fract(g) - 0.5;
	float h = fract(sin(dot(id, vec2(12.9898, 78.233)) + seed * 37.0) * 43758.5453);
	if (h < 0.72) {
		return 0.0;
	}
	f += vec2(sin(t * 1.3 + h * 20.0), cos(t * 1.1 + h * 30.0)) * 0.12;
	float d = length(f);
	return smoothstep(0.17, 0.15, d) + smoothstep(0.2, 0.17, d) * 0.5;
}

void fragment() {
	vec2 p = (UV - 0.5) * vec2(16.0 / 9.0, 1.0);
	float len = length(p);
	float ang = atan(p.y, p.x);

	// rays that wobble and slowly rotate, pulsing like a beat
	float rays = sin((ang + TIME * spin_speed) * 9.0 + sin(len * 9.0 - TIME * 1.5) * 1.4);
	float beat = 0.5 + 0.5 * sin(TIME * 2.4);
	vec3 col = mix(col_a.rgb, col_b.rgb, smoothstep(-0.2, 0.9, rays) * (0.55 + 0.25 * beat));
	float rings = 0.5 + 0.5 * sin(len * 14.0 - TIME * 1.2);
	col = mix(col, col_c.rgb, smoothstep(0.55, 1.0, rings) * 0.5);

	// halftone dots whose size follows the rays
	vec2 cell = fract(UV * vec2(64.0, 36.0)) - 0.5;
	float dots = smoothstep(0.32 * (0.35 + 0.5 * (0.5 + 0.5 * rays)), 0.0, length(cell));
	col += vec3(0.07, 0.04, 0.09) * dots;

	// two parallax layers of drifting balls
	float b1 = ball_layer(p, TIME, 0.0);
	float b2 = ball_layer(p * 1.7 + 3.0, TIME * 1.4, 1.0);
	col = mix(col, vec3(1.0, 0.93, 0.8), clamp(b1 * 0.30 + b2 * 0.18, 0.0, 0.45));

	float vig = smoothstep(0.3, 1.1, length(UV - 0.5) * 1.5);
	COLOR = vec4(col * (1.0 - 0.6 * vig), 1.0);
}
