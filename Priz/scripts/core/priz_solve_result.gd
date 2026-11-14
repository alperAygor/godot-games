class_name PrizSolveResult
extends RefCounted
## Çözücü sonucu.
##
## `count` ayrık çözüm sayısıdır: eş prizler (aynı hat, oda, bayrak) ve birebir aynı davranan
## cihazlar yer değiştirdiğinde oluşan kopyalar bir kez sayılır. Oyuncunun gözünde "hangi
## cihaz hangi tür prize" sorusunun farklı cevaplarıdır.

var count: int = 0
## Sayım `cap` değerine ulaştı ve durdu (gerçek sayı en az bu kadar).
var capped: bool = false
## Düğüm sınırı aşıldı; sonuç eksik olabilir.
var node_limit_hit: bool = false
var nodes: int = 0
## İlk bulunan çözüm: cihaz kimliği → priz kimliği (çözüm yoksa boş).
var solution: Dictionary = {}


func is_solvable() -> bool:
	return count > 0


## Sayım kesin mi (ne çözüm sınırı ne düğüm sınırı devreye girdi)?
func is_exact() -> bool:
	return not capped and not node_limit_hit
