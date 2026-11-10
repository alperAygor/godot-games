class_name PackagePhysics
extends Package

## Paket fizik davranışı: cam kırılması ve buz erimesi.
## Sarsıntı şiddeti `apply_shake()` ile beslenir; kırılma/erime kararı burada verilir,
## sonuç Main'e sinyalle bildirilir (sahne/duraklatma kararı oradan verilir).

enum Kind { STANDARD, GLASS, ICE, IRON, SPRING }

## `data/packages.json` anahtarları — denge sayıları orada durur.
const KIND_KEYS: Dictionary = {
	Kind.STANDARD: "standard",
	Kind.GLASS: "glass",
	Kind.ICE: "ice",
	Kind.IRON: "iron",
	Kind.SPRING: "spring",
}

signal broken(package: PackagePhysics)
signal melted(package: PackagePhysics)
signal repaired(package: PackagePhysics)

@export var kind: Kind = Kind.STANDARD
## Birikmiş stres bu eşiğe ulaşınca cam kırılır (stres = şiddet x süre x kırılganlık).
@export var break_threshold: float = 2.2
@export var fragility: float = 1.0
## Buzun SARSINTISIZ tamamen erime süresi (saniye). Sarsıntı en fazla 2.5 kat hızlandırır.
@export var melt_seconds: float = 3.0
## Testler ve özel durumlar için: kapatılırsa data tablosu uygulanmaz.
@export var use_data_tuning: bool = true

var stress: float = 0.0
var melt: float = 0.0
var is_broken: bool = false
var is_melted: bool = false


func _ready() -> void:
	super._ready()
	if use_data_tuning:
		_apply_tuning()


func kind_key() -> String:
	return String(KIND_KEYS.get(kind, "standard"))


## Denge değerleri `data/packages.json`. Tablo yoksa `@export` varsayılanları kalır.
func _apply_tuning() -> void:
	var row_variant: Variant = GameData.table("packages").get(kind_key())
	if not (row_variant is Dictionary):
		return
	var row: Dictionary = row_variant
	var threshold: Variant = row.get("break_threshold", null)
	if threshold is float or threshold is int:
		break_threshold = float(threshold)
	var frag: Variant = row.get("fragility", null)
	if frag is float or frag is int:
		fragility = float(frag)
	var melt: Variant = row.get("melt_seconds", null)
	if melt is float or melt is int:
		melt_seconds = float(melt)


func apply_shake(intensity: float, delta: float) -> void:
	match kind:
		Kind.GLASS:
			if is_broken:
				return
			stress += intensity * fragility * delta
			if stress >= break_threshold:
				_break()
		Kind.ICE:
			if is_melted:
				return
			# taban 1.0: melt_seconds gerçekten "tam erime süresi" olsun; sarsıntı hızlandırır
			melt = minf(1.0, melt + delta * (1.0 + intensity * 1.5) / maxf(melt_seconds, 0.1))
			_update_melt_visual()
			if melt >= 1.0:
				_melt()
		_:
			pass


## Komşu paketten gelen ek stres (eriyen buzun sarsıntısı, bant kurtarma vb.).
func add_stress(amount: float) -> void:
	if kind != Kind.GLASS or is_broken:
		return
	stress += amount * fragility
	if stress >= break_threshold:
		_break()


func repair() -> void:
	if not is_broken:
		return
	is_broken = false
	stress = 0.0
	visible = true
	scale = home_scale
	var tween: Tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(self, "scale", home_scale * 1.16, 0.12) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", home_scale, 0.22) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	repaired.emit(self)


func melt_ratio() -> float:
	return melt


func _break() -> void:
	is_broken = true
	is_melted = false
	stress = break_threshold
	broken.emit(self)
	# Duraklatılmış sahnede de oynasın diye tween PROCESS modunda.
	var tween: Tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(self, "scale", home_scale * Vector3(1.18, 0.82, 1.18), 0.07) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", home_scale * 0.05, 0.24) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_callback(_hide_after_break)


func _hide_after_break() -> void:
	visible = false


func _melt() -> void:
	is_melted = true
	melt = 1.0
	scale = home_scale * 0.62
	melted.emit(self)


func _update_melt_visual() -> void:
	# Eriyen buz küçülür: ızgaradaki doluluk görsel olarak da okunur.
	var shrink: float = 1.0 - 0.38 * melt
	scale = home_scale * Vector3(shrink, shrink - 0.1 * melt, shrink)
