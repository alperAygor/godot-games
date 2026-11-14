// Priz — pencereden giren ışık hüzmesi (Mobile çizicide hacimsel sis yok; bu, toz
// zerrecikli, kenarları yumuşak toplamalı bir hacim kabuğudur). Kalite kademesi "low"da kapatılır.
// UV.x: hüzme genişliği boyunca 0..1, UV.y: pencereden uzaklık 0..1.
shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, fog_disabled;

uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform sampler2D depth_tex : hint_depth_texture, filter_linear;
uniform vec4 shaft_color : source_color = vec4(1.0, 0.9, 0.7, 1.0);
uniform float intensity = 0.0;
uniform float edge_soft = 0.38;
uniform float dust = 0.6;

void fragment() {
	float ex = smoothstep(0.0, edge_soft, UV.x) * smoothstep(1.0, 1.0 - edge_soft, UV.x);
	float along = smoothstep(0.0, 0.12, UV.y) * (1.0 - smoothstep(0.55, 1.0, UV.y));
	vec2 drift = vec2(TIME * 0.01, -TIME * 0.02);
	float n = texture(noise_tex, UV * vec2(1.5, 3.0) + drift).r;
	float motes = smoothstep(0.82, 0.95, texture(noise_tex, UV * vec2(5.0, 9.0) + drift * 3.0).b) * dust;
	// Yüzeye yaklaşınca sön (sert kesişim çizgisi olmasın)
	float depth = texture(depth_tex, SCREEN_UV).r;
	vec4 world = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
	float scene_z = -world.z / world.w;
	float frag_z = -VERTEX.z;
	float prox = clamp((scene_z - frag_z) / 0.35, 0.0, 1.0);
	float a = ex * along * (0.45 + 0.55 * n) * prox;
	ALBEDO = shaft_color.rgb * (a * intensity + motes * a * intensity * 2.0);
}
