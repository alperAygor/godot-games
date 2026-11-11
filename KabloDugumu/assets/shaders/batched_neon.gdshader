shader_type spatial;

// Statik emissive parçaları (neon gösterge, sigorta, kelepçe halkası, uyarı
// ışıkları) TEK mesh'te birleştiren vertex-renkli malzeme.
// COLOR.rgb = neon rengi. emission_energy blackout modifier'ında kısılır (§12).

uniform float albedo_scale : hint_range(0.0, 1.0) = 0.35;
uniform float emission_energy : hint_range(0.0, 4.0) = 0.9;

void fragment() {
	ALBEDO = COLOR.rgb * albedo_scale;
	EMISSION = COLOR.rgb * emission_energy;
	METALLIC = 0.1;
	ROUGHNESS = 0.3;
}
