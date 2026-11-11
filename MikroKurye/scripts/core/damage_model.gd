class_name DamageModel
extends RefCounted

## Saf mantık: fizik ölçümlerini (darbe impulsu, açısal ivme, düşüş yüksekliği)
## 0..1 hasara çevirir. Durumsuz; her fonksiyon sonucu tek çağrıda 1.0'a kırpar.
##
## Eşikler/ölçekler kargo profilinden (`cargo.json` girdisi) gelir; anahtar
## eksikse ARCHITECTURE.md §4.1'deki varsayılanlar kullanılır (hasar yok).
## Sözleşme: ARCHITECTURE.md §4.1.

## Tek çağrıda dönülebilecek en yüksek hasar (üst sınır).
const MAX_DAMAGE: float = 1.0

## Eksik profil anahtarı için varsayılan eşik. INF kullanmıyoruz: çıkan değer
## sonlu kalır, kırpma NaN üretmez (ARCHITECTURE.md §4.1: "999.0").
const DEFAULT_THRESHOLD: float = 999.0

## Eksik profil anahtarı için varsayılan ölçek (sıfır => hasar yok).
const DEFAULT_SCALE: float = 0.0


## Darbe impulsu -> hasar: (impulse - eşik) * ölçek. Eşik ve altı, negatif ve
## NaN girdi 0 döner.
static func impact_damage(impulse: float, profile: Dictionary) -> float:
	if impulse <= 0.0:
		return 0.0
	var threshold: float = float(profile.get("impact_threshold", DEFAULT_THRESHOLD))
	if impulse <= threshold:
		return 0.0
	var scale: float = float(profile.get("impact_scale", DEFAULT_SCALE))
	return _clamp_damage((impulse - threshold) * scale)


## Çalkalanma (açısal ivme) -> hasar: (|a| - eşik) * ölçek * dt. Eşik altı ve
## dt <= 0 0 döner; ivmenin mutlak değeri kullanılır (yön hasar üretmez).
static func slosh_damage(angular_accel: float, dt: float, profile: Dictionary) -> float:
	if dt <= 0.0:
		return 0.0
	var magnitude: float = absf(angular_accel)
	var threshold: float = float(profile.get("slosh_threshold", DEFAULT_THRESHOLD))
	if magnitude <= threshold:
		return 0.0
	var scale: float = float(profile.get("slosh_scale", DEFAULT_SCALE))
	return _clamp_damage((magnitude - threshold) * scale * dt)


## Düşüş yüksekliği -> hasar: (h - eşik) * ölçek. Eşik altı / negatif / NaN 0.
static func fall_damage(drop_height: float, profile: Dictionary) -> float:
	if drop_height <= 0.0:
		return 0.0
	var threshold: float = float(profile.get("fall_threshold", DEFAULT_THRESHOLD))
	if drop_height <= threshold:
		return 0.0
	var scale: float = float(profile.get("fall_scale", DEFAULT_SCALE))
	return _clamp_damage((drop_height - threshold) * scale)


## Sonucu güvenli biçimde [0, 1] aralığına sokar: NaN ve negatif 0, üstü 1.0.
static func _clamp_damage(value: float) -> float:
	if is_nan(value) or value <= 0.0:
		return 0.0
	return minf(value, MAX_DAMAGE)
