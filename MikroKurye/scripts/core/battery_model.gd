class_name BatteryModel
extends RefCounted

## Batarya: seviye, tüketime, şarj, boost. Sözleşme: ARCHITECTURE.md §4.3.
##
## Varsayılanlar (sözleşmede): capacity 100.0, speed_drain 0.02,
## empty_speed_factor 0.35, boost_factor 1.25.
##
## Güvenlik: negatif/NaN girdi 0 sayılır; kapasite asla aşılmaz; boost süresi
## 0'ın altına inmez.

## Varsayılan kapasite (Wh).
const DEFAULT_CAPACITY: float = 100.0

## Varsayılan hız tüketime (hız^2 * dt * speed_drain).
const DEFAULT_SPEED_DRAIN: float = 0.02

## Varsayılan boşaltma hız çarpanı (dolu = 1.0).
const DEFAULT_EMPTY_SPEED_FACTOR: float = 0.35

## Varsayılan boost çarpanı (boost aktifken speed_factor).
const DEFAULT_BOOST_FACTOR: float = 1.25

var _capacity: float
var _level: float
var _speed_drain: float
var _empty_speed_factor: float
var _boost_factor: float
var _boost_time: float


func _init(capacity: float = DEFAULT_CAPACITY, params: Dictionary = {}) -> void:
	# Negatif/NaN kapasite 0 sayılır (güvenli); dolu batarya olmaz.
	_capacity = maxf(capacity, 0.0)
	_speed_drain = float(params.get("speed_drain", DEFAULT_SPEED_DRAIN))
	_empty_speed_factor = float(params.get("empty_speed_factor", DEFAULT_EMPTY_SPEED_FACTOR))
	_boost_factor = float(params.get("boost_factor", DEFAULT_BOOST_FACTOR))
	_level = _capacity
	_boost_time = 0.0


func level() -> float:
	# 0..1 arası doluluk oranı.
	if _capacity <= 0.0:
		return 0.0
	return clampf(_level / _capacity, 0.0, 1.0)


func drain(amount: float) -> void:
	# >= 0 harcar; negatif girdi 0 sayılır; 0'ın altına inmez.
	if amount <= 0.0:
		return
	_level = maxf(_level - amount, 0.0)


func drain_for_speed(speed: float, dt: float) -> void:
	# Tüketim = speed_drain * speed^2 * dt. Hız 0 veya negatifse, dt <= 0 ise 0.
	if speed <= 0.0 or dt <= 0.0:
		return
	var consumption: float = _speed_drain * speed * speed * dt
	drain(consumption)


func recharge(amount: float) -> void:
	# Şarj eder; kapasiteyi aşmaz. Negatif girdi 0 sayılır.
	if amount <= 0.0:
		return
	_level = minf(_level + amount, _capacity)


func refill_full() -> void:
	_level = _capacity


func is_empty() -> bool:
	return _level <= 0.0


func speed_factor() -> float:
	# Dolu: 1.0; boş: empty_speed_factor; arada level()'a göre DOĞRUSAL.
	# Boost aktifse boost_factor döner (batarya boş olsa da).
	if _boost_time > 0.0:
		return _boost_factor
	if _capacity <= 0.0:
		return _empty_speed_factor
	var lvl: float = level()
	return _empty_speed_factor + (1.0 - _empty_speed_factor) * lvl


func start_boost(seconds: float) -> void:
	# Boost süresi 0'ın altına inmez; <= 0 ise boost aktif değil.
	_boost_time = maxf(seconds, 0.0)


func boost_active() -> bool:
	return _boost_time > 0.0


func tick(dt: float) -> void:
	# Boost süresini azaltır (0'ın altına inmez).
	if dt <= 0.0:
		return
	_boost_time = maxf(_boost_time - dt, 0.0)