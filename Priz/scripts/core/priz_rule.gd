class_name PrizRule
extends RefCounted
## Kural türü tabanı. Her içerik öğesi (data/elements/*.json) bir ya da birkaç kural türünü
## parametreleriyle kullanır. Yeni bir kural türü gerekiyorsa bu sınıftan türeyen küçük bir
## betik yazılır; tahta, çözücü ve üretici değişmez.
##
## Sözleşme:
##  - Kurallar durumsuzdur; `setup` sonrası yalnız okunur (iş parçacıkları arasında paylaşılır).
##  - `check_plug` statiktir: yalnız cihaza ve prizin hat/oda/props alanlarına bakar
##    (priz kimliği, anchor ya da tahtadaki diğer cihazlar değil). Çözücü eş prizleri bu
##    varsayımla tek sınıfta toplar.
##  - Kapasite/yük/maske kancaları her (hat|cihaz, dilim) için saf fonksiyondur.
##  - Üretici kancası `gen_apply` yalnız `ctx.level` üzerinde değişiklik yapar ve `ctx.rng`
##    dışında rastgelelik kullanmaz (aynı tohum → aynı seviye).

## Üretim aşamaları.
const STAGE_NONE: int = 0
## Yerleştirmeden önce: yapı (oda, çoklu priz, gün kipi, cihaz dilimleri).
const STAGE_PRE_PLANT: int = 1
## Gizli çözüm yerleştirildikten sonra: çözüme uyan kısıtlar (toprak, zamanlayıcı, hat ekleri).
const STAGE_POST_PLANT: int = 2

var element_id: String = ""
var params: Dictionary = {}
var gen: Dictionary = {}
## Uygulama ve üretim sırası (küçük önce). Öğe dosyası "order" ile ezebilir.
var order: int = 100


func setup(owner_id: String, rule_params: Dictionary, gen_hints: Dictionary,
		order_override: int) -> void:
	element_id = owner_id
	params = rule_params
	gen = gen_hints
	order = order_override if order_override >= 0 else default_order()


func default_order() -> int:
	return 100


## PrizReason.OK ya da bir ret kodu.
func check_plug(_level: PrizLevel, _device: PrizDevice, _socket: PrizSocket) -> StringName:
	return PrizReason.OK


## Cihazın bu prizdeyken çalıştığı dilim maskesi.
func modify_mask(_level: PrizLevel, _device: PrizDevice, _socket: PrizSocket,
		mask: int) -> int:
	return mask


## Cihazın bu prizde, bu dilimde bindirdiği yük (blok). Çalışmadığı dilimde gelen değer 0'dır.
func modify_load(_level: PrizLevel, _device: PrizDevice, _socket: PrizSocket, _slice: int,
		blocks: int) -> int:
	return blocks


## Hattın bu dilimdeki etkin kapasitesi.
func modify_capacity(_level: PrizLevel, _line: PrizLine, _slice: int, capacity: int) -> int:
	return capacity


## Hatta cihazlardan bağımsız eklenen yük (ör. komşu hattı).
func external_load(_level: PrizLevel, _line: PrizLine, _slice: int) -> int:
	return 0


func gen_stage() -> int:
	return STAGE_NONE


## Üretici kancası. false dönerse bu deneme reddedilir ve üretici yeni tohumla yeniden dener.
func gen_apply(_ctx: PrizGenContext) -> bool:
	return true


# --- yardımcılar -------------------------------------------------------------

func param_str(key: String, fallback: String) -> String:
	return PrizJson.get_str(params, key, fallback)


func param_int(key: String, fallback: int) -> int:
	return PrizJson.get_int(params, key, fallback)


func param_slices(key: String, fallback_mask: int) -> int:
	if not params.has(key):
		return fallback_mask
	return PrizSlice.mask_from_ids(PrizJson.get_array(params, key))


## Üretici ipucundan aralık; tanıtım seviyesinde alt sınır kullanılır.
func gen_range(ctx: PrizGenContext, key: String, lo: int, hi: int) -> int:
	var r: Vector2i = PrizJson.get_range(gen, key, lo, hi)
	if ctx.intro:
		return r.x
	return ctx.rng.randi_range(r.x, maxi(r.x, r.y))
