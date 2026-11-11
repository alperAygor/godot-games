class_name CargoHealth
extends RefCounted

## Kargo sağlığı: DamageModel'in tek-çağrı hasarlarını biriktirir, Şok Emici Jel
## korumasını yönetir, kırılmayı izler. Sözleşme: ARCHITECTURE.md §4.2.
##
## apply_* dönüş değeri GERÇEKTEN eklenen hasardır (kırpma/jel sonrası fark);
## kırık kargoya hasar eklenmez (0.0 döner).

## Hasarda üst sınır (bu değerde kargo kırılır).
const MAX_DAMAGE: float = 1.0

## Jel bir kırıcı vuruşu emdiğinde hasarın oturduğu tavan (kırılma yok).
const JELLY_CEILING: float = 0.95

var _profile: Dictionary
var _damage: float = 0.0
var _jelly: int = 0


func _init(profile: Dictionary, jelly_charges: int = 0) -> void:
	_profile = profile
	# Negatif jel hakkı, jel olmamasıyla aynıdır (ARCHITECTURE.md §4.2).
	_jelly = maxi(jelly_charges, 0)


func apply_impact(impulse: float) -> float:
	return _apply(DamageModel.impact_damage(impulse, _profile))


func apply_slosh(angular_accel: float, dt: float) -> float:
	return _apply(DamageModel.slosh_damage(angular_accel, dt, _profile))


func apply_fall(drop_height: float) -> float:
	return _apply(DamageModel.fall_damage(drop_height, _profile))


func damage() -> float:
	return _damage


func integrity() -> float:
	return MAX_DAMAGE - _damage


func is_broken() -> bool:
	return _damage >= MAX_DAMAGE


func jelly_left() -> int:
	return _jelly


## Tek-çağrı hasarı ekler; jel kuralını uygular; eklenen miktarı döner.
func _apply(incoming: float) -> float:
	if _damage >= MAX_DAMAGE or is_nan(incoming) or incoming <= 0.0:
		return 0.0
	var remaining: float = MAX_DAMAGE - _damage
	# Bu vuruş kargoyu kıracaksa ve jel varsa: jel emer, hasar max(mevcut, 0.95)
	# seviyesinde kalır; kırılma olmaz (ARCHITECTURE.md §4.2).
	if incoming >= remaining and _jelly > 0:
		_jelly -= 1
		var target: float = maxf(_damage, JELLY_CEILING)
		var applied: float = target - _damage
		_damage = target
		return applied
	var applied: float = minf(incoming, remaining)
	_damage += applied
	return applied
