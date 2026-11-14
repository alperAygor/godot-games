class_name StoryState
extends RefCounted
## Hikaye bayrakları ve sayaçları (seçimler, kesinti sayısı...). Hikaye koşulları (`requires`) `matches` ile sınanır.

var flags: Dictionary = {}
var counters: Dictionary = {}


func flag(id: String, fallback := false) -> bool:
	return bool(flags.get(id, fallback))


func set_flag(id: String, value := true) -> void:
	flags[id] = value


func counter(id: String) -> int:
	return int(counters.get(id, 0))


func add(id: String, amount := 1) -> void:
	counters[id] = counter(id) + amount


## Koşul sözlüğü: {"flags": {id: bool}, "counters_min": {id: n}, "counters_max": {id: n}}. Hepsi sağlanmalı; boş koşul true.
func matches(condition: Dictionary) -> bool:
	var wanted_flags: Dictionary = condition.get("flags", {})
	for id: Variant in wanted_flags.keys():
		if flag(str(id)) != bool(wanted_flags[id]):
			return false
	var minimums: Dictionary = condition.get("counters_min", {})
	for id: Variant in minimums.keys():
		if counter(str(id)) < int(minimums[id]):
			return false
	var maximums: Dictionary = condition.get("counters_max", {})
	for id: Variant in maximums.keys():
		if counter(str(id)) > int(maximums[id]):
			return false
	return true


func to_dict() -> Dictionary:
	return {"flags": flags.duplicate(), "counters": counters.duplicate()}


static func from_dict(data: Dictionary) -> StoryState:
	var state := StoryState.new()
	state.flags = (data.get("flags", {}) as Dictionary).duplicate()
	for key: Variant in (data.get("counters", {}) as Dictionary).keys():
		state.counters[key] = int(data["counters"][key])
	return state
