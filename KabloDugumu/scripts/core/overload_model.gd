class_name OverloadModel
extends RefCounted

## Asiri yuk barinin durum makinesi. Sahne bilmez; birim testle sabitlenir.
##
## Kural (PROJECT_SPEC bolum 4):
##  - temas varken bar fill + extra*(contacts-1) hizinda dolar;
##  - temas yokken drain hizinda bosalir;
##  - kalkan aktifken dolum durur (temas sayilir), kalkan suresi tick ile azalir;
##  - add_load dogrudan ceza yukler; kalkan bunu da engeller;
##  - bar 1.0'a ulasinca sigorta atar (blown) ve bar tekrar dolmaz.

var value: float = 0.0
var peak: float = 0.0
var blown: bool = false
var shield_left: float = 0.0
var contact_count: int = 0

var _fill_per_second: float = 0.55
var _drain_per_second: float = 0.32
var _extra_per_contact: float = 0.3


func configure(fill_per_second: float, drain_per_second: float, extra_per_contact: float) -> void:
	_fill_per_second = maxf(0.0, fill_per_second)
	_drain_per_second = maxf(0.0, drain_per_second)
	_extra_per_contact = maxf(0.0, extra_per_contact)


## Kalkan suresini en az seconds yapar (uzatir, kucultmez).
func add_shield(seconds: float) -> void:
	if seconds <= 0.0:
		return
	shield_left = maxf(shield_left, seconds)


func is_shielded() -> bool:
	return shield_left > 0.0


func reset() -> void:
	value = 0.0
	peak = 0.0
	blown = false
	shield_left = 0.0
	contact_count = 0


## Dogrudan yuk ekleme (yanlis prize birakma cezasi gibi). Kalkan bunu da engeller.
func add_load(amount: float) -> void:
	if amount <= 0.0 or blown or is_shielded():
		return
	value = minf(1.0, value + amount)
	peak = maxf(peak, value)
	if value >= 1.0:
		blown = true


## contacts>0 iken saniyedeki dolum hizi; her ek temas hizi artirir.
func current_fill_rate(contacts: int) -> float:
	if contacts <= 0:
		return 0.0
	return _fill_per_second + _extra_per_contact * float(contacts - 1)


func tick(delta: float, contacts: int) -> void:
	if delta <= 0.0:
		return
	contact_count = maxi(0, contacts)
	var remaining: float = delta
	# Kalkanli gecen sure dolumu durdurur; kalkan bu tick icinde biterse kalan sure isler.
	if shield_left > 0.0:
		var consumed: float = minf(shield_left, remaining)
		shield_left -= consumed
		remaining -= consumed
	if blown or remaining <= 0.0:
		return
	var rate: float = current_fill_rate(contact_count)
	if rate > 0.0:
		value = minf(1.0, value + rate * remaining)
	else:
		value = maxf(0.0, value - _drain_per_second * remaining)
	peak = maxf(peak, value)
	if value >= 1.0:
		blown = true
