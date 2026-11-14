class_name Haptics
extends RefCounted

## Titreşim yardımcısı: `Input.vibrate_handheld` üstünde ince katman. Titreşim ayarına saygılıdır
## (`Progress` "vibration"), masaüstünde hiçbir şey yapmaz. Süreler `data/balance.json` -> `haptics`.
## Kullanım: fiş oturunca `Haptics.thud()`, dokunuşta `Haptics.tick()`, kazanınca `Haptics.success()`.

const DEFAULT_TICK_MS: int = 12
const DEFAULT_THUD_MS: int = 35
const DEFAULT_SUCCESS_MS: int = 60
const SETTING_KEY: String = "vibration"
const PROGRESS_PATH: NodePath = ^"/root/Progress"

## Süre tablosu bir kez okunur (her dokunuşta dosya okunmasın).
static var _table: Dictionary = {}

enum Kind { TICK, THUD, SUCCESS }
const KEYS: Dictionary = {Kind.TICK: "tick_ms", Kind.THUD: "thud_ms", Kind.SUCCESS: "success_ms"}
const DEFAULTS: Dictionary = {
	Kind.TICK: DEFAULT_TICK_MS, Kind.THUD: DEFAULT_THUD_MS, Kind.SUCCESS: DEFAULT_SUCCESS_MS,
}


## Hafif tık (sürükleme, anahtar).
static func tick() -> void:
	_fire(Kind.TICK)


## Kısa, dolgun darbe (fiş prize oturdu).
static func thud() -> void:
	_fire(Kind.THUD)


## Başarı vurgusu (seviye kazanıldı).
static func success() -> void:
	_fire(Kind.SUCCESS)


## Bir türün süresi (ms); tablo eksik/bozuksa yedek.
static func duration_ms(kind: Kind, table: Dictionary = {}) -> int:
	var value: int = ProgressData.to_count(table.get(KEYS[kind]), int(DEFAULTS[kind]))
	return value if value > 0 else int(DEFAULTS[kind])


## Titreşim ayarı açık mı (Progress yoksa açık sayılır).
static func enabled() -> bool:
	var loop: SceneTree = Engine.get_main_loop() as SceneTree
	if loop == null:
		return true
	var progress: Node = loop.root.get_node_or_null(PROGRESS_PATH)
	if progress == null or not progress.has_method("setting"):
		return true
	return bool(progress.call("setting", SETTING_KEY))


## Cihazda gerçekten titreşim yapılabilir mi: yalnız mobil.
static func available() -> bool:
	return OS.has_feature("mobile")


static func _fire(kind: Kind) -> void:
	if not available() or not enabled():
		return
	if _table.is_empty():
		_table = ProgressData.load_balance().get("haptics", {}) as Dictionary
	Input.vibrate_handheld(duration_ms(kind, _table))
