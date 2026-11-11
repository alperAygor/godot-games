class_name CargoVisual
extends Node3D
## Sepetteki seçili kargo modelini gösterir — yalnızca görsel; CargoBasket fiziğine
## dokunmaz. `GameManager.selected_cargo_id` kimliğini hazır GLB setiyle eşler.
## Renk/anahat stilini Robot.tscn içindeki StyleA düğümü üstlenir; bu düğüm yalnız
## doğru modeli örnekler, ölçekler ve sepete yerleştirir (vitrin gibi okunaklı).

const MODEL_ROOT: String = "res://assets/models/"
const DEFAULT_CARGO_ID: String = "pencil_battery"
const CARGO_MODELS: Dictionary = {
	"pencil_battery": "cargo_pencil_battery.glb",
	"sd_card": "cargo_sd_card.glb",
	"espresso_capsule": "cargo_espresso_capsule.glb",
}
## Vitrin ölçeği: gerçek kargo 6-12 cm; sepetin içinde tek başına okunacak kadar
## büyütülür (stil laboratuvarı üç kargoyu birlikte 1.7× ile gösteriyordu).
const CARGO_SCALE: float = 2.0

var _instance: Node3D = null


func _ready() -> void:
	var cargo_id: String = _selected_cargo_id()
	var model_name: Variant = CARGO_MODELS.get(cargo_id, CARGO_MODELS[DEFAULT_CARGO_ID])
	var packed: PackedScene = load(MODEL_ROOT + String(model_name)) as PackedScene
	if packed == null:
		push_warning("CargoVisual: kargo modeli yüklenemedi: %s" % String(model_name))
		return
	_instance = packed.instantiate() as Node3D
	if _instance == null:
		return
	add_child(_instance)
	_instance.position = Vector3.ZERO
	_instance.scale = Vector3.ONE * CARGO_SCALE


func _selected_cargo_id() -> String:
	var manager: Node = get_node_or_null("/root/GameManager")
	if manager == null:
		return DEFAULT_CARGO_ID
	var raw: Variant = manager.get("selected_cargo_id")
	if raw is String and not (raw as String).is_empty():
		return raw as String
	return DEFAULT_CARGO_ID
