class_name Segment
extends Node3D
## Sonsuz mod yol parçası (sözleşme: PROJECT_SPEC §14, tools/segment_tools.py).
## Kök Node3D; içerik yerel -Z yönünde 0..length uzanır, zemin parçanın içindedir.
## Tuzak düğümleri `apply_difficulty(params)` sunarsa level zorluğu buradan dağıtılır.

@export var segment_id: String = ""
@export var length: float = 12.0


## Level zorluğunu bu parçadaki tüm tuzaklara uygular (LevelProgression ölçekleri).
func apply_level(level: int) -> void:
	var params: Dictionary = {
		"telegraph_scale": LevelProgression.telegraph_scale(level),
		"cycle_scale": LevelProgression.cycle_scale(level),
		"fan_scale": LevelProgression.fan_strength_scale(level),
	}
	for node: Node in find_children("*", "", true, false):
		if node.has_method("apply_difficulty"):
			node.call("apply_difficulty", params)


## Uzak parçaları gizler ve işlemeyi durdurur (çizim çağrısı + fizik maliyeti).
func set_active(active: bool) -> void:
	visible = active
	process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED


## Bölge teması: zemin yüzeyi ve ahşap kenar malzemesi (şerit/rota çizgileri değişmez).
func apply_floor(surface_material: Material, apron_material: Material) -> void:
	var surface: MeshInstance3D = get_node_or_null("Floor/Surface") as MeshInstance3D
	if surface != null:
		surface.material_override = surface_material
	var apron: MeshInstance3D = get_node_or_null("Apron") as MeshInstance3D
	if apron != null:
		apron.material_override = apron_material
