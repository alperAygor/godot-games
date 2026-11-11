shader_type spatial;

// Statik parçaları TEK mesh'te birleştirmek için vertex-renkli matte malzeme
// (ARCHITECTURE §14 draw call bütçesi). COLOR.rgb = albedo, COLOR.a = metallic.
// BoardBuilder ve AmbientBackdrop ortak kullanır; her parça için ayrı
// MeshInstance3D/StandardMaterial3D yerine tek draw call yeter.

uniform float roughness : hint_range(0.0, 1.0) = 0.45;
uniform float metallic_scale : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	ALBEDO = COLOR.rgb;
	METALLIC = COLOR.a * metallic_scale;
	ROUGHNESS = roughness;
}
