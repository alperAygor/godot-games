extends Node

## Tek ses girişi. Sahne script'leri `AudioStreamPlayer` yaratmaz; buradan çalar.
## Sesler ElevenLabs ile üretildi (`tools/make_sfx.py`, anahtar yoksa yedek sentez).

const SFX_DROP: AudioStream = preload("res://assets/audio/sfx/package_drop.wav")
const SFX_GLASS: AudioStream = preload("res://assets/audio/sfx/glass_break.wav")
const SFX_ICE: AudioStream = preload("res://assets/audio/sfx/ice_clink.wav")
const SFX_SUCCESS: AudioStream = preload("res://assets/audio/sfx/success.wav")

const BUS_SFX: StringName = &"SFX"
const BUS_MUSIC: StringName = &"Music"
const POOL_SIZE: int = 8

var _pool: Array[AudioStreamPlayer] = []
var _next: int = 0
var _silent: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Görselsiz/başsız çalıştırmada ses aygıtı yok: hiçbir şey çalma, hata da verme.
	_silent = DisplayServer.get_name() == "headless"
	for i: int in POOL_SIZE:
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.bus = BUS_SFX
		player.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(player)
		_pool.append(player)


func play_drop() -> void:
	_play(SFX_DROP, 0.09)


func play_glass_break() -> void:
	_play(SFX_GLASS, 0.04)


func play_ice_clink() -> void:
	_play(SFX_ICE, 0.12)


func play_success() -> void:
	_play(SFX_SUCCESS, 0.0)


func play_sfx(stream: AudioStream, pitch_variance: float = 0.06) -> void:
	_play(stream, pitch_variance)


func set_bus_volume(bus: StringName, linear: float) -> void:
	var index: int = AudioServer.get_bus_index(bus)
	if index < 0:
		return
	AudioServer.set_bus_volume_db(index, linear_to_db(clampf(linear, 0.0, 1.0)))


func _play(stream: AudioStream, pitch_variance: float) -> void:
	if _silent or stream == null or _pool.is_empty():
		return
	var player: AudioStreamPlayer = _pool[_next]
	_next = (_next + 1) % _pool.size()
	player.stream = stream
	player.pitch_scale = 1.0 + randf_range(-pitch_variance, pitch_variance)
	player.play()
