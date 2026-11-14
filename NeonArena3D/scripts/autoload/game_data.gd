extends Node
## data/*.json yükler; denge, kartlar ve haritalar erişilebilir olur.

const BALANCE_PATH := "res://data/balance.json"
const CARDS_PATH := "res://data/cards.json"
const MAPS_PATH := "res://data/maps.json"
const SHIPS_PATH := "res://data/ships.json"
const UPGRADES_PATH := "res://data/upgrades.json"
const ACTIONS := {
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"move_up": [KEY_W, KEY_UP],
	"move_down": [KEY_S, KEY_DOWN],
	"dash": [KEY_SPACE, KEY_SHIFT],
	"fire": [KEY_J],
	"nova": [KEY_Q, KEY_E, KEY_F],
	"restart": [KEY_R],
	"mute": [KEY_M],
	"pause": [KEY_ESCAPE, KEY_P],
}

var balance: Dictionary = {}
var cards: Array = []
var maps: Array = []
var ships: Array = []
var upgrades: Array = []

func _ready() -> void:
	balance = _load_dict(BALANCE_PATH)
	cards = _load_array(CARDS_PATH)
	maps = _load_array(MAPS_PATH)
	ships = _load_array(SHIPS_PATH) if FileAccess.file_exists(SHIPS_PATH) else []
	upgrades = _load_array(UPGRADES_PATH) if FileAccess.file_exists(UPGRADES_PATH) else []
	_register_actions()

func _load_dict(path: String) -> Dictionary:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("JSON sözlük okunamadı: " + path)
		return {}
	return parsed

func _load_array(path: String) -> Array:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_ARRAY:
		push_error("JSON dizi okunamadı: " + path)
		return []
	return parsed

func value(path: String, fallback: Variant = 0.0) -> Variant:
	var node: Variant = balance
	for part in path.split("."):
		if typeof(node) != TYPE_DICTIONARY or not (node as Dictionary).has(part):
			return fallback
		node = (node as Dictionary)[part]
	return node

func number(path: String, fallback := 0.0) -> float:
	return float(value(path, fallback))

func enemy_stats(kind: String) -> Dictionary:
	var stats: Dictionary = (balance.get("enemies", {}) as Dictionary).get(kind, {})
	return stats.duplicate()

func boss_stats(kind := "") -> Dictionary:
	## Temel boss değerleri + türe özel üzerine yazmalar (balance.json → boss_kinds).
	var out := (balance.get("boss", {}) as Dictionary).duplicate()
	var kinds: Dictionary = balance.get("boss_kinds", {})
	if kinds.has(kind):
		out.merge(kinds[kind], true)
	return out

func map_theme(index: int) -> Dictionary:
	if maps.is_empty():
		return {}
	return maps[index % maps.size()]

func _register_actions() -> void:
	for action in ACTIONS:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.2)
		for key in ACTIONS[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action, event)
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event("fire", mouse)
	var right := InputEventMouseButton.new()
	right.button_index = MOUSE_BUTTON_RIGHT
	InputMap.action_add_event("nova", right)

func elite_def() -> Dictionary:
	return (balance.get("elite", {}) as Dictionary).duplicate()

func card_by_id(id: String) -> Dictionary:
	for card in cards:
		if str(card.get("id", "")) == id:
			return card
	return {}
