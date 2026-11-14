// Priz — buhar parçacığı (çaydanlık). Yumuşak, gürültüyle aşınan, ömür boyunca genişleyip
// sönen bir pufla. Billboard; parçacık rengi/alfa ömür boyunca COLOR ile gelir.
shader_type spatial;
render_mode blend_mix, unshaded, cull_disabled, depth_draw_never, fog_disabled;

uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform float softness = 0.9;

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
}

void fragment() {
	vec2 d = UV - 0.5;
	float r = length(d) * 2.0;
	float seed = COLOR.b;
	float n = texture(noise_tex, UV * 0.8 + vec2(seed * 3.1, TIME * 0.08 + seed)).r;
	float shape = smoothstep(1.0, softness * 0.3, r + (n - 0.5) * 0.6);
	ALBEDO = vec3(0.96, 0.97, 0.98);
	ALPHA = shape * COLOR.a * 0.55;
}
