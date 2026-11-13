class_name ZenSession
extends RefCounted

## Bir zen oturumunun durumu: kaçıncı tahta, bu oturumda temizlenenler, tahtadaki dokunuşlar ve
## kurtarma sayısı. Tahtalar LevelPrefetch ile arka planda üretilir: sıradaki tahta daha oyuncu
## oynarken hazırdır, geçiş takılmaz (üretim saf ve iş parçacığı güvenlidir: ZenMode.build_level).

## Oturum tohumu: oturumdan oturuma farklı tahta dizisi; oturum İÇİNDE (tohum + sıra) deterministik.
var base_seed: int = 0
var step: int = 0
var cleared: int = 0
var rescues: int = 0
var taps: Array[int] = []
var cfg: Dictionary = {}


func _init(config: Dictionary, seed_override: int = -1) -> void:
	cfg = config
	var modulo: int = maxi(ProgressData.to_count(config.get(ZenMode.KEY_SEED_MOD), ZenMode.FALLBACK_SEED_MOD), 1)
	base_seed = seed_override if seed_override >= 0 else int(Time.get_unix_time_from_system()) % modulo
	# İlk tahta ve ardından gelen hemen hazırlanır.
	_request(step)


## Sıradaki tahta; sonrakini arka planda isteyip dokunuş/kurtarma durumunu sıfırlar.
func next_level() -> Dictionary:
	var level: Dictionary = LevelPrefetch.take(ZenMode.level_key(base_seed + step),
		ZenMode.build_level.bind(base_seed + step, step, cfg))
	step += 1
	taps.clear()
	rescues = 0
	_request(step)
	return level


## Oyun her durum değiştiren dokunuştan sonra çağırır: dokunuş listesi geri-al geçmişiyle eş kalır.
func note_tap(id: int, board: LaundryBoard) -> void:
	if board.history_size() == taps.size() + 1:
		taps.append(id)


func on_cleared() -> int:
	cleared += 1
	ZenMode.add_cleared()
	AnalyticsLog.record(ZenMode.EVENT_CLEAR, {"count": cleared})
	return cleared


## Kayıp yerine sakin kurtarma (bkz. ZenMode.rescue).
func rescue(level: Dictionary, board: LaundryBoard) -> Dictionary:
	var result: Dictionary = ZenMode.rescue(level, taps, board, rescues, cfg)
	rescues += 1
	return result


func _request(index: int) -> void:
	var variant_seed: int = base_seed + index
	LevelPrefetch.request(ZenMode.level_key(variant_seed), ZenMode.build_level.bind(variant_seed, index, cfg))
