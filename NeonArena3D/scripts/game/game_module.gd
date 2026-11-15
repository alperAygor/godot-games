extends Node
class_name GameModule
## Oyun modüllerinin tabanı: paylaşılan duruma (`ctx`) erişir. Modüller game3d'nin çocuk düğümleridir ama
## `_process` tanımlamaz: kare sırası tek yerde, game3d._process içinde yönetilir (belirlenimlilik).

const KIT = preload("res://scripts/ui/ui_kit.gd")
const ARENA := GameContext.ARENA

var ctx: GameContext

func setup(context: GameContext) -> void:
	ctx = context
