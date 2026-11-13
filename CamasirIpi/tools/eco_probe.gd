extends SceneTree

## Ekonomi probu (headless): GERÇEK oyun sahnesinde kazanma/kayıp akışını oynar ve doğrular:
## jeton, seri, 3 galibiyetten sonra +1 askı, seviye başına tek devam, 2x jeton,
## geçiş reklamı sıklığı. Reklam sağlayıcısı anında biten bir test sağlayıcısıdır
## (AdManager'ın gerçek akışı kullanılır; Mock'un 1.2 sn bekleyişi ve rastgele hatası yok).
##   godot --headless --path . -s res://tools/eco_probe.gd      çıkış 0 = geçti

const WIN_LEVELS: Array[int] = [1, 2, 3, 4]
const SETTLE_FRAMES: int = 2
const MAX_WAIT_FRAMES: int = 2000000

## NOT: EcoFlow tipi burada ANILMAZ; `-s` kipinde autoload kimlikleri derleme anında yoktur.
## Anında ödül veren/vermeyen sağlayıcı.
class InstantProvider extends AdsProvider:
	var reward: bool = true
	var shown_count: int = 0

	func is_ready(_placement: int) -> bool:
		return true

	func show(_placement: int) -> void:
		shown_count += 1
		shown.emit()
		if reward:
			rewarded.emit()
		else:
			failed.emit("no_fill")

var _failed: bool = false
var _started: bool = false
var _game: Node = null
var _provider: InstantProvider = InstantProvider.new()
## Her kazançta ustalık kurallarından (3 yıldız bonusu + zincir bonusu) beklenen ödül/yıldız toplamı.
var _expected_coins: int = 0
var _expected_stars: int = 0


func _process(_delta: float) -> bool:
	if _started:
		return false
	_started = true
	_run()
	return false


func _run() -> void:
	var progress: Node = root.get_node("Progress")
	var ads: Node = root.get_node("AdManager")
	progress.set("persist", false)
	progress.call("reset_state")
	ads.call("set_provider", _provider)
	AnalyticsLog.echo = false
	AnalyticsLog.clear()

	# --- Galibiyetler: jeton, seri, 3. galibiyetten sonra +1 askı ---
	for index: int in range(3):
		await _load_game(progress.call("level"))
		_check(int(_board().rack_slots()) == 4, "seri 3'ten önce askı 4 olmalı (kazanç %d)" % index)
		await _win_current_level()
	# Ödül artık temel (20) + kusursuz bonusu + zincir bonusudur; beklenen, oyunun RunStats'ından hesaplanır.
	_check(int(progress.call("coins")) == _expected_coins,
		"3 galibiyet = %d jeton (temel+ustalık), gelen %d" % [_expected_coins, int(progress.call("coins"))])
	_check(int(progress.call("stars")) == _expected_stars,
		"yıldızlar derecelerin toplamı olmalı: %d, gelen %d" % [_expected_stars, int(progress.call("stars"))])
	_check(_expected_coins >= 60, "ustalık ödülü temelin altına inemez")
	_check(int(progress.call("best_stars", 1)) >= 1 and int(progress.call("best_stars", 3)) >= 1, "en iyi yıldız kaydı")
	_check(int(progress.call("streak")) == 3, "seri 3 olmalı")
	_check(int(progress.call("level")) == 4, "seviye 4 olmalı")
	_check(bool(progress.call("streak_extra_slot")), "seri bonusu açık olmalı")
	_check(int(progress.call("booster_count", "undo")) == 0, "seviye 6'dan önce hediye yok")

	await _load_game(progress.call("level"))
	_check(_board().rack_slots() == 5, "3 galibiyetten sonra seviye +1 askıyla başlamalı, gelen %d" % _board().rack_slots())

	# --- 2x jeton: ödüllü reklam sonrası ödül ikiye katlanır ---
	var coins_before: int = int(progress.call("coins"))
	var reward_before: int = _expected_coins
	await _win_current_level(true)
	var total_reward: int = _expected_coins - reward_before
	_check(int(progress.call("coins")) == coins_before + total_reward * 2,
		"2x jeton ödülü TOPLAMI ikiler: %d" % int(progress.call("coins")))
	_check(AnalyticsLog.count("rewarded_watched") == 1, "izlenen reklam kaydı")

	# --- Kayıp: seri sıfırlanır, devam seviye başına 1 kez ---
	_check(int(progress.call("streak")) == 4, "2x kazançtan sonra seri 4")
	# Kayıp senaryosu 4 slotlu kuruludur: bonus askı onu bozmasın diye seri düşürülür
	# (bonusun kayıpla gittiği aşağıda ve birim testte ayrıca doğrulanır).
	(progress.get("data") as ProgressData).streak = 2
	await _load_game(progress.call("level"))
	_game.set("debug_level", _losing_level())
	_game.call("_start_level")
	_check(_board().rack_slots() == 5 or _board().rack_slots() == 4, "kayıp seviyesi yüklendi")
	await _lose_current_level()
	_check(int(progress.call("streak")) == 0, "kayıpta seri sıfırlanmalı")
	_check(not bool(progress.call("streak_extra_slot")), "bonus askı kayıpla gitmeli")
	var slots_before: int = _board().rack_slots()
	var paid_before: int = int(progress.call("coins"))
	_check(paid_before >= 100, "devam için yeterli jeton olmalı (%d)" % paid_before)
	var cost: int = int(ProgressData.load_balance()["continue_cost"])
	_game.call("_on_revive_ad", Button.new())
	await _frames(SETTLE_FRAMES)
	_check(_board().rack_slots() == slots_before + 1, "reklamla devam +1 askı vermeli")
	_check(_game.get("_overlay") == null, "devam sonrası katman kapanmalı")
	# Aynı seviyede ikinci devam (jetonla) reddedilmeli.
	_game.call("_on_revive_coins", cost)
	_check(_board().rack_slots() == slots_before + 1, "seviye başına tek devam")
	_check(int(progress.call("coins")) == paid_before, "ikinci devamda jeton harcanmamalı")
	_check(not bool(ads.call("can_offer", ads.Placement.REVIVE_EXTRA_SLOT)), "devam reklamı seviyede tükenmeli")

	# Jetonla devam: yeni seviyede, reklam yerine jeton.
	_game.set("debug_level", {})
	_game.call("_start_level")
	_game.set("debug_level", _losing_level())
	_game.call("_start_level")
	await _lose_current_level()
	var before_pay: int = int(progress.call("coins"))
	var slots_pay: int = _board().rack_slots()
	_game.call("_on_revive_coins", cost)
	_check(int(progress.call("coins")) == before_pay - cost, "jetonla devam 100 jeton düşmeli")
	_check(_board().rack_slots() == slots_pay + 1, "jetonla devam +1 askı")

	# --- Geçiş reklamı sıklığı ---
	_provider.shown_count = 0
	var shown_logged: int = AnalyticsLog.count("interstitial_shown")
	progress.call("reset_state")
	var data: ProgressData = progress.get("data") as ProgressData
	var flow: Node = _game.get("_eco") as Node
	var ran: Array[int] = [0]
	var next: Callable = func() -> void: ran[0] += 1
	# Seviye 3'e geçiş: erken, reklam yok.
	data.levels_since_interstitial = 5
	flow.call("maybe_interstitial", 3, next)
	_check(_provider.shown_count == 0 and ran[0] == 1, "seviye 4'ten önce geçiş reklamı yok")
	# Yeterli seviye geçti ama az önce ödüllü izlendi: yok.
	data.last_rewarded_time = Time.get_unix_time_from_system()
	flow.call("maybe_interstitial", 5, next)
	_check(_provider.shown_count == 0 and ran[0] == 2, "ödüllü sonrası geçiş reklamı yok")
	# Ödüllü eski, süre ve seviye koşulu tamam: gösterilir ve sayaç sıfırlanır.
	data.last_rewarded_time = 0.0
	flow.call("maybe_interstitial", 5, next)
	_check(_provider.shown_count == 1 and ran[0] == 3, "koşullar tamamsa geçiş reklamı gösterilmeli")
	_check(data.levels_since_interstitial == 0, "gösterimden sonra sayaç sıfırlanmalı")
	_check(AnalyticsLog.count("interstitial_shown") == shown_logged + 1, "interstitial_shown kaydı")
	# Hemen ardından: seviye ve 90 sn koşulu yüzünden yok.
	data.levels_since_interstitial = 5
	flow.call("maybe_interstitial", 6, next)
	_check(_provider.shown_count == 1 and ran[0] == 4, "90 sn dolmadan ikinci reklam yok")
	_check(AnalyticsLog.count("level_start") > 0 and AnalyticsLog.count("level_win") >= 4
		and AnalyticsLog.count("level_lose") >= 2, "analitik olayları kaydedildi")

	# Reklam başarısızsa ödül verilmez.
	_provider.reward = false
	var coins_now: int = int(progress.call("coins"))
	flow.call("watch", ads.Placement.DOUBLE_COINS, func() -> void: progress.call("add_coins", 999))
	_check(int(progress.call("coins")) == coins_now, "başarısız reklam ödül vermemeli")
	_check(AnalyticsLog.count("rewarded_skipped") == 1, "atlanan reklam kaydı")

	print("ECO SONUC: %s" % ("kaldi" if _failed else "gecti"))
	quit(1 if _failed else 0)


func _board() -> LaundryBoard:
	return _game.get("_board") as LaundryBoard


func _load_game(level: int) -> void:
	if _game != null:
		_game.queue_free()
		await _frames(1)
	var packed: PackedScene = load("res://scenes/Game.tscn") as PackedScene
	_game = packed.instantiate()
	root.add_child(_game)
	current_scene = _game
	_game.set("_persist", false)
	_game.set("_level_number", level)
	_game.set("debug_level", {})
	_game.call("_start_level")
	await _frames(2)


## Çözücü yoluyla oynar; animasyonlar bitip katman çıkana dek bekler.
## `double`: katmandaki 2x düğmesini de kullan.
func _win_current_level(double: bool = false) -> void:
	var path: Array[int] = LevelSolver.solve(_game.get("_level") as Dictionary, 200000)
	_check(not path.is_empty(), "çözüm bulunmalı")
	for id: int in path:
		_game.call("_tap", id)
		await _frames(4)
	await _wait_overlay()
	_check(_board().is_won(), "seviye kazanılmalı")
	var stats: RunStats = _game.get("_run_stats") as RunStats
	var balance: Dictionary = ProgressData.load_balance()
	var rating: int = StarRating.rate_stats(stats, _board().item_ids().size(), balance)
	var breakdown: Dictionary = StarRating.breakdown(int(balance["win_coins"]), rating, stats.best_chain, balance)
	var reward: int = int(breakdown["total"])
	_expected_coins += reward
	_expected_stars += rating
	if double:
		_game.call("_on_double_coins", Button.new(), reward)
		await _frames(SETTLE_FRAMES)
	# Devam: geçiş reklamı kararı burada işler (sağlayıcı anında biter).
	var flow: Node = _game.get("_eco") as Node
	flow.call("maybe_interstitial", int(_game.get("_level_number")), func() -> void: pass)


func _lose_current_level() -> void:
	for id: int in [0, 1, 2, 3]:
		_game.call("_tap", id)
		await _frames(4)
	await _wait_overlay()
	_check(_board().is_lost(), "seviye kaybedilmeli")


func _wait_overlay() -> void:
	var waited: int = 0
	while waited < MAX_WAIT_FRAMES and (bool(_game.get("_playing")) or _game.get("_overlay") == null):
		await process_frame
		waited += 1


func _frames(count: int) -> void:
	for _i: int in range(count):
		await process_frame


func _losing_level() -> Dictionary:
	var colors: Array[int] = [2, 2, 3, 3, 2, 3, 0, 0, 0, 1, 1, 1]
	var blockers: Dictionary = {6: [4], 7: [4], 8: [4], 9: [5], 10: [5], 11: [5]}
	var items: Array[Dictionary] = []
	for index: int in range(colors.size()):
		items.append({"id": index, "color": colors[index], "blockers": blockers.get(index, []),
			"line": index / 6, "layer": 0 if index < 6 else 1, "slot": float(index % 6) * 0.6, "kind": index % 6})
	return {"level": 1, "items": items, "queue": [0, 1, 2, 3], "active_baskets": 2, "rack_slots": 4, "hard": false}


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		printerr("ECO HATA: %s" % message)
