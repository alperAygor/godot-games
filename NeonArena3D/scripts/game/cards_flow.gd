extends GameModule
class_name CardsFlow
## Seviye kartı akışı: seviye atlayınca (RunState.level_up) bir sonraki karede kartları açar, oyunu duraklatır,
## yenileme (reroll) ve seçim; birden çok bekleyen seviye arka arkaya açılır. Kart havuzu/ağırlık: Loadout.
## SEAM(ads: reroll): `open` içinde cards_shown yayınlanır; reklamla ek yenileme `grant_reroll()` + `reroll()`.

var is_open := false
var pending_open := false
var _current: Array = []
var rng := RandomNumberGenerator.new()   ## kart çekilişi akışı (RunFlow.reseed tohumlar)

func reset() -> void:
	is_open = false
	pending_open = false

func on_level_up(_level: int) -> void:
	pending_open = true

func tick_pending() -> bool:
	## Bekleyen seviye kartını aç; açıldıysa true (bu kare oyun adımı atlanır).
	if pending_open and not is_open:
		pending_open = false
		open()
		if is_open:
			return true
	return false

func card_counts() -> Dictionary:
	var counts := {}
	for id in ctx.loadout.taken:
		counts[id] = int(counts.get(id, 0)) + 1
	return counts

func open(play_sound := true) -> void:
	var run := ctx.run
	var count := int(GameData.number("leveling.cards", 3))
	_current = ctx.loadout.roll(count, rng)
	if _current.is_empty():
		run.consume_level()
		return
	is_open = true
	ctx.host.get_tree().paused = true
	ctx.touch.release_all()
	ctx.hud.dimmed = true
	if play_sound:
		Sound.play("level_up")
	Sound.set_muffled(true)
	ctx.menus.show_cards(_current, run.level - run.pending_levels + 1, ctx.rerolls, card_counts())
	ctx.events.cards_shown.emit(_current, ctx.rerolls)
	if ctx.options.demo and not ctx.options.show_cards_demo:
		pick(randi() % _current.size())

func grant_reroll(count := 1) -> void:
	## SEAM(ads: reroll): ödüllü reklam sonrası ek yenileme hakkı (henüz çağıran yok).
	ctx.rerolls += count

func reroll() -> void:
	if not is_open or ctx.rerolls <= 0:
		return
	ctx.rerolls -= 1
	open(false)

func pick(index: int) -> void:
	if not is_open or index < 0 or index >= _current.size():
		return
	var run := ctx.run
	var player := ctx.player
	var card: Dictionary = _current[index]
	ctx.loadout.apply(card)
	ctx.control.apply_loadout()
	run.consume_level()
	is_open = false
	Sound.play("card_pick")
	ctx.events.card_picked.emit(card)
	if run.pending_levels > 0:
		open(false)
		return
	ctx.menus.hide_all()
	ctx.hud.dimmed = false
	ctx.host.get_tree().paused = false
	Sound.set_muffled(false)
	var accent: Color = KIT.TIER_COLOR.get(str(card.get("tier", "common")), KIT.CYAN)
	if str(card.get("tier", "")) == "synergy":
		ctx.hud.show_banner(tr("SİNERJİ"), tr(str(card.get("name", ""))), 2.0, accent)
		ctx.sparks.ring(player.position, accent, 0.4, 9.0, 0.7, 0.14, 1.0)
		Sound.play("synergy")
	else:
		ctx.hud.toast(tr(str(card.get("name", ""))), accent, 1.6)
	ctx.sparks.ring(player.position, accent, 0.4, 4.0, 0.5, 0.18)
	player.invuln = maxf(player.invuln, ctx.tuning.run_card_invuln)
