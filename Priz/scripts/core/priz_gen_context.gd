class_name PrizGenContext
extends RefCounted
## Üretici kancalarına (PrizRule.gen_apply) verilen bağlam. Kancalar yalnız `level` alanını
## değiştirir ve yalnız `rng` ile rastgelelik üretir.

var level: PrizLevel
var registry: PrizElementRegistry
var catalog: PrizCatalog
var rng: RandomNumberGenerator
## Seviye numarası (günlük seviyede sanal numara).
var number: int = 0
## Kancanın öğesi bu seviyede ilk kez tanıtılıyor: en yumuşak hâliyle uygula.
var intro: bool = false
## Gizli çözüm: cihaz kimliği → priz kimliği (POST_PLANT aşamasında dolu).
var plan: Dictionary = {}


## Gizli çözümün mevcut kurallarla her hat ve dilimdeki yükü (dış yük dahil): [hat*4 + dilim].
func planted_loads() -> PackedInt32Array:
	var c: PrizCompiled = PrizCompiled.build(level, registry)
	return c.line_loads(plan_indices(c))


func plan_indices(c: PrizCompiled) -> PackedInt32Array:
	var result: PackedInt32Array = PackedInt32Array()
	result.resize(c.n_devices)
	result.fill(-1)
	for d: int in c.n_devices:
		var sock_id: String = str(plan.get(level.devices[d].id, ""))
		result[d] = int(c.socket_index.get(sock_id, -1))
	return result


func planted_socket(device: PrizDevice) -> PrizSocket:
	return level.find_socket(str(plan.get(device.id, "")))


## Gizli çözümde bu hatta takılı cihazlar.
func planted_devices_on(line_id: String) -> Array[PrizDevice]:
	var result: Array[PrizDevice] = []
	for device: PrizDevice in level.devices:
		var socket: PrizSocket = planted_socket(device)
		if socket != null and socket.line == line_id:
			result.append(device)
	return result


## Diziden rastgele bir öğe dizini (boşsa -1).
func pick_index(size: int) -> int:
	if size <= 0:
		return -1
	return rng.randi_range(0, size - 1)


func shuffle_ints(values: Array[int]) -> void:
	for i: int in range(values.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var t: int = values[i]
		values[i] = values[j]
		values[j] = t
