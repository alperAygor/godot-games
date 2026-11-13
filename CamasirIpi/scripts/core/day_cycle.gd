class_name DayCycle
extends RefCounted

## Seviye ilerledikçe günün saati değişir: şafak -> sabah -> öğle -> ikindi -> altın saat ->
## gün batımı -> alacakaranlık -> gece -> (başa döner). Saf mantık; sahne bilgisi yok.
## Neden seviye başına bir adım: oyuncu her seviyede zamanın aktığını fark etsin, ilerleme bir
## yolculuk gibi hissettirsin. Bir seviyede ikiden fazla adım olmaz; sabit aşağıdan değiştirilir.

const DATA_PATH: String = "res://data/day_cycle.json"
const PHASE_COUNT: int = 8
## 1 = her seviyede bir aşama. 2 yapılırsa aşamalar arası blend_for() 0 ile 0.5 arasında gider.
const LEVELS_PER_PHASE: int = 1
## Aşama geçişi (crossfade) süresi; oyuncu seviye başında zamanın aktığını görsün.
const FADE_SECONDS: float = 1.5

static var _looks: Array[DayLook] = []


## 1 tabanlı seviye -> aşama (0 = şafak). 8'den sonra başa sarar.
static func phase_for(level: int) -> int:
	var steps: int = floori(float(maxi(level, 1) - 1) / float(LEVELS_PER_PHASE))
	return posmod(steps, PHASE_COUNT)


## Aşamanın içindeki ilerleme 0..1 (LEVELS_PER_PHASE = 1 iken hep 0). Sonraki aşamaya
## doğru yumuşak ara değer isteyen çağıran için.
static func blend_for(level: int) -> float:
	return float((maxi(level, 1) - 1) % LEVELS_PER_PHASE) / float(LEVELS_PER_PHASE)


static func phase_name(phase: int) -> String:
	return look_for_phase(phase).phase_name


## Ses katmanı için ipucu: "birds" ya da "crickets". Ses üretimi bu dosyanın işi değil.
static func ambience_for(level: int) -> String:
	return look_for_phase(phase_for(level)).ambience


## Aşamanın paylaşılan (değiştirilmemesi gereken) görünümü.
static func look_for_phase(phase: int) -> DayLook:
	_ensure_loaded()
	return _looks[posmod(phase, _looks.size())]


## Seviyenin görünümü: aşama + sonraki aşamaya blend. blend 0 ise paylaşılan nesne döner.
static func look_for_level(level: int) -> DayLook:
	var phase: int = phase_for(level)
	var blend: float = blend_for(level)
	var current: DayLook = look_for_phase(phase)
	if blend <= 0.0:
		return current
	var mixed: DayLook = DayLook.new()
	mixed.blend(current, look_for_phase(phase + 1), blend)
	return mixed


static func _ensure_loaded() -> void:
	if not _looks.is_empty():
		return
	var parsed: Variant = null
	if FileAccess.file_exists(DATA_PATH):
		parsed = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	if parsed is Dictionary:
		for entry: Variant in ((parsed as Dictionary).get("phases", []) as Array):
			if entry is Dictionary:
				_looks.append(DayLook.from_dict(entry as Dictionary))
	if _looks.is_empty():
		# Veri dosyası bozuksa oyun yine açılır: tek varsayılan "sabah" görünümü.
		_looks.append(DayLook.new())
