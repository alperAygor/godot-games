class_name SliceAudio
extends Node
## Kesitin ses katmanları (AudioService üzerinden; docs/AUDIO.md "Katmanlama yönergesi"):
## ortam (dilime göre) en altta, planlama müziği, elektrik uğultusu (perde = en dolu hattın oranı),
## takılı her cihazın döngüsü. Sahne silinirken tüm katmanlar kısılıp bırakılır (dil değişimi /
## ana ekran: sızan katman kalmaz).

const HUM_ID: String = "hum"
const DEVICE_PREFIX: String = "dev_"
const DEVICE_DB: float = -10.0
const DEVICE_CROWD_DB: float = -2.0
const HUM_BASE_DB: float = -26.0
const HUM_FULL_DB: float = -15.0
const MUSIC_DB: float = -14.0
const AMBIENCE_DB: float = -7.0

var _devices: Array[String] = []
var _service: Node


func _ready() -> void:
	_service = get_node_or_null("/root/AudioService")


func _exit_tree() -> void:
	stop_all(0.25)


func begin_level(slice: int) -> void:
	if _service == null:
		return
	_service.call("play_ambience", "ambience_%s" % PrizSlice.id_of(slice), AMBIENCE_DB)
	_service.call("play_music", "music_plan", MUSIC_DB)
	_service.call("start_loop", HUM_ID, "hum_mains", HUM_BASE_DB, 1.0)
	set_tension(0.0)


func set_ambience(slice: int) -> void:
	if _service != null:
		_service.call("play_ambience", "ambience_%s" % PrizSlice.id_of(slice), AMBIENCE_DB)


## Gerilim 0..1+: uğultu perdesi 1.0 → 1.6 ve seviyesi yükselir.
func set_tension(t: float) -> void:
	if _service == null:
		return
	var k: float = clampf(t, 0.0, 1.0)
	_service.call("set_loop_pitch", HUM_ID, 1.0 + 0.6 * k, 0.4)
	_service.call("set_loop_volume", HUM_ID, lerpf(HUM_BASE_DB, HUM_FULL_DB, k), 0.4)


func device_on(device_id: String, loop_sound: String) -> void:
	if _service == null:
		return
	if not _devices.has(device_id):
		_devices.append(device_id)
	var db: float = DEVICE_DB + (DEVICE_CROWD_DB if _devices.size() > 4 else 0.0)
	_service.call("start_loop", DEVICE_PREFIX + device_id, loop_sound, db, 0.6)


func device_off(device_id: String) -> void:
	_devices.erase(device_id)
	if _service != null:
		_service.call("stop_loop", DEVICE_PREFIX + device_id, 0.5)


func device_count() -> int:
	return _devices.size()


func play(sound: String, variance: float = 0.0) -> void:
	if _service != null:
		_service.call("play", sound, variance)


func play_pitched(sound: String, pitch: float, db: float = 0.0) -> void:
	if _service != null:
		_service.call("play_pitched", sound, pitch, db)


## Fişin oturması: üç "tık" dönüşümlü, ±%3 perde.
func seat_click() -> void:
	if _service != null:
		_service.call("play_variant", "plug_seat", 3, randf_range(0.97, 1.03), 0.0)


## Kazanma: uğultu ve müzik iner, cihaz katmanları kısılır, kazanma parçası yükselir.
func win() -> void:
	if _service == null:
		return
	_service.call("stop_loop", HUM_ID, 0.6)
	_service.call("stop_music", 0.8)
	for device_id: String in _devices:
		_service.call("set_loop_volume", DEVICE_PREFIX + device_id, DEVICE_DB - 8.0, 1.2)
	_service.call("play_ambience", "ambience_night", AMBIENCE_DB)
	_service.call("play_jingle", "music_win", -3.0)


## Seviye değişimi / çıkış: tüm cihaz katmanları ve uğultu kısılıp bırakılır.
func stop_all(fade: float = 0.4) -> void:
	_devices.clear()
	if _service == null:
		return
	_service.call("stop_all_loops", fade)
