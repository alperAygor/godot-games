// Priz — pencere dışı manzara (gökyüzü + uzak tepeler + yakın binalar + ağaçlar).
// Işıksız (unshaded); dilim renkleri day_light.gd tarafından tween ile verilir.
// city_masks: R uzak silüet, G yakın binalar, B pencere ışıkları, A ağaçlar.
shader_type spatial;
render_mode unshaded, cull_back, fog_disabled;

uniform sampler2D city_tex : filter_linear_mipmap, repeat_enable;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform vec4 sky_top : source_color = vec4(0.45, 0.62, 0.85, 1.0);
uniform vec4 sky_horizon : source_color = vec4(0.85, 0.88, 0.9, 1.0);
uniform vec4 far_color : source_color = vec4(0.6, 0.66, 0.74, 1.0);
uniform vec4 near_color : source_color = vec4(0.45, 0.5, 0.58, 1.0);
uniform vec4 tree_color : source_color = vec4(0.25, 0.35, 0.28, 1.0);
uniform vec4 sun_color : source_color = vec4(1.0, 0.95, 0.85, 1.0);
uniform vec4 window_color : source_color = vec4(1.0, 0.75, 0.4, 1.0);
uniform vec2 sun_pos = vec2(0.3, 0.3);
uniform float sun_size = 0.06;
uniform float window_lights : hint_range(0.0, 1.0) = 0.0;
uniform float stars : hint_range(0.0, 1.0) = 0.0;
uniform float clouds : hint_range(0.0, 1.0) = 0.5;
uniform float brightness = 1.0;
uniform vec2 uv_scale = vec2(1.0, 1.0);
uniform vec2 uv_offset = vec2(0.0, 0.0);

void fragment() {
	vec2 uv = UV * uv_scale + uv_offset;
	float h = clamp(uv.y, 0.0, 1.0);
	vec3 sky = mix(sky_top.rgb, sky_horizon.rgb, smoothstep(0.0, 0.62, h));
	// Güneş/ay diski ve halesi
	float d = distance(uv * vec2(2.0, 1.0), sun_pos * vec2(2.0, 1.0));
	float disc = smoothstep(sun_size, sun_size * 0.8, d);
	float halo = exp(-d * 5.0) * 0.6;
	sky += sun_color.rgb * (disc * 1.5 + halo);
	// Bulutlar
	float c1 = texture(noise_tex, uv * vec2(0.8, 2.4) + vec2(TIME * 0.004, 0.0)).r;
	float c2 = texture(noise_tex, uv * vec2(1.7, 4.0) + vec2(TIME * 0.007, 0.3)).g;
	float cl = smoothstep(0.55, 0.85, c1 * 0.7 + c2 * 0.4) * clouds * (1.0 - smoothstep(0.35, 0.6, h));
	sky = mix(sky, mix(sky_horizon.rgb, sun_color.rgb, 0.35) * 1.05, cl * 0.6);
	// Yıldızlar
	float st = step(0.985, texture(noise_tex, uv * 9.0).b) * stars * (1.0 - smoothstep(0.2, 0.55, h));
	sky += vec3(st);
	vec4 m = texture(city_tex, uv);
	vec3 col = sky;
	col = mix(col, far_color.rgb, m.r);
	col = mix(col, near_color.rgb, m.g);
	float lit = step(0.55, m.b) * window_lights;
	col += window_color.rgb * lit * 1.4 * m.g * (1.0 - m.a);
	col = mix(col, tree_color.rgb, m.a);
	ALBEDO = col * brightness;
}
