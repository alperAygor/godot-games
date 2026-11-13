extends SceneTree

## Ekonomi probu (headless): GERÇEK oyun sahnesinde kazanma/kayıp akışını oynar ve doğrular:
## jeton, seri, 3 galibiyetten sonra +1 askı, seviye başına tek devam (YALNIZ ödüllü reklamla; jetonla
## devam kaldırıldı), kayıpta jeton yok, 2x jeton (yalnız galibiyette), geçiş reklamı kuralları
## (4. seviyeden itibaren HER geçişte; "reklamları kaldır" varsa asla; ödüllü sonrası asla; zaman aşımı). Reklam sağlayıcısı anında biten bir test sağlayıcısıdır
## (AdManager'ın gerçek akışı kullanılır; Mock'un 1.2 sn bekleyişi ve rastgele hatası yok).
##   godot --headless --path . -s res://tools/eco_probe.gd      çıkış 0 = geçti

const WIN_LEVELS: Array[int] = [1, 2, 3, 4]
const SETTLE_FRAMES: int = 2
const MAX_WAIT_FRAMES: int = 2000000
## Reklam gelmezse AdManager zaman aşımı (3 sn) + pay.
const SILENT_WAIT_MSEC: int = 6000

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

## Hiç yanıt vermeyen sağlayıcı: AdManager'ın gösterim zaman aşımını sınar.
class SilentProvider extends AdsProvider:
	func is_ready(_placement: int) -> bool:
		return true

	func show(_placement: int) -> void:
		pass

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
	var coins_before_loss: int = int(progress.call("coins"))
	await _lose_current_level()
	_check(int(progress.call("streak")) == 0, "kayıpta seri sıfırlanmalı")
	_check(not bool(progress.call("streak_extra_slot")), "bonus askı kayıpla gitmeli")
	var slots_before: int = _board().rack_slots()
	var coins_after_loss: int = int(progress.call("coins"))
	_check(coins_after_loss == coins_before_loss, "kayıpta jeton verilmemeli/alınmamalı")
	# Kayıp sayfasında jetonla devam düğmesi yok: yalnız "+1 askı" (reklam) ve "Tekrar dene".
	var buttons: int = _count_buttons(_game.get("_overlay") as Node)
	_check(buttons == 2, "kayıp sayfasında 2 düğme olmalı (reklamla devam + tekrar dene), gelen %d" % buttons)
	_check(not _game.has_method("_on_revive_coins"), "jetonla devam yolu silinmiş olmalı")
	# Sahte düğme ağaca eklenmez: iş bitince elle silinir (yoksa çıkışta düğüm/tema/yazı tipi sızıntısı).
	var revive_button: Button = Button.new()
	_game.call("_on_revive_ad", revive_button)
	await _frames(SETTLE_FRAMES)
	revive_button.free()
	_check(_board().rack_slots() == slots_before + 1, "reklamla devam +1 askı vermeli")
	_check(_game.get("_overlay") == null, "devam sonrası katman kapanmalı")
	_check(bool(_game.get("_revived")), "seviyede devam kullanıldı")
	_check(int(progress.call("coins")) == coins_after_loss, "reklamla devam jeton harcamaz")
	_check(not bool(ads.call("can_offer", ads.Placement.REVIVE_EXTRA_SLOT)), "devam reklamı seviyede tükenmeli")

	# --- Geçiş reklamı kuralları ---
	# Yeni seviye başlar: önceki seviyedeki ödüllü izleme ("+1 askı") bu geçişi etkilemez.
	_game.set("debug_level", {})
	_game.call("_start_level")
	_provider.shown_count = 0
	var shown_logged: int = AnalyticsLog.count("interstitial_shown")
	progress.call("reset_state")
	ads.call("reset_session_limits")
	var flow: Node = _game.get("_eco") as Node
	var ran: Array[int] = [0]
	var next: Callable = func() -> void: ran[0] += 1
	# İlk 3 seviye reklamsız: 2., 3. ve 4. seviyeye geçişlerden yalnız 4.'ye geçişte reklam var.
	flow.call("maybe_interstitial", 2, next)
	flow.call("maybe_interstitial", 3, next)
	_check(_provider.shown_count == 0 and ran[0] == 2, "seviye 4'ten önce geçiş reklamı yok")
	# 4. seviyeden itibaren HER geçişte (aralık/süre koşulu yok): art arda üç geçiş = üç reklam.
	for level: int in [4, 5, 6]:
		flow.call("maybe_interstitial", level, next)
	_check(_provider.shown_count == 3 and ran[0] == 5, "4. seviyeden itibaren her geçişte reklam: %d" % _provider.shown_count)
	_check(AnalyticsLog.count("interstitial_shown") == shown_logged + 3, "her geçiş için interstitial_shown kaydı")
	# Bu geçişte ödüllü reklam izlendiyse hemen ardından geçiş reklamı yok; sonraki geçişte yine var.
	_provider.shown_count = 0
	flow.call("watch", ads.Placement.DOUBLE_COINS, func() -> void: pass)
	flow.call("maybe_interstitial", 7, next)
	_check(_provider.shown_count == 1 and ran[0] == 6, "ödüllü reklamın kendisi sayılır, ardından geçiş reklamı eklenmemeli")
	_game.call("_start_level")
	_provider.shown_count = 0
	flow.call("maybe_interstitial", 8, next)
	_check(_provider.shown_count == 1, "sonraki geçişte reklam geri gelir")
	# "Reklamları kaldır": geçiş reklamı asla; ödüllü reklam hâlâ sunulur.
	progress.call("set_remove_ads_owned", true)
	_provider.shown_count = 0
	for level: int in [4, 9, 30]:
		flow.call("maybe_interstitial", level, next)
	_check(_provider.shown_count == 0, "reklamlar kaldırıldıysa geçiş reklamı yok")
	_check(bool(ads.call("can_offer", ads.Placement.DOUBLE_COINS)), "ödüllü reklam açık kalmalı")
	progress.call("set_remove_ads_owned", false)
	# Reklam hiç gelmezse (zaman aşımı) akış sessizce devam eder; sayaç işaretlenmez.
	var silent: SilentProvider = SilentProvider.new()
	ads.call("set_provider", silent)
	var ran_before: int = ran[0]
	flow.call("maybe_interstitial", 10, next)
	var waited_ms: int = Time.get_ticks_msec()
	while ran[0] == ran_before and Time.get_ticks_msec() - waited_ms < SILENT_WAIT_MSEC:
		await process_frame
	_check(ran[0] == ran_before + 1, "gelmeyen reklam zaman aşımıyla akışı serbest bırakmalı")
	_check(Time.get_ticks_msec() - waited_ms < SILENT_WAIT_MSEC, "zaman aşımı kısa olmalı")
	ads.call("set_provider", _provider)
	_check(AnalyticsLog.count("level_start") > 0 and AnalyticsLog.count("level_win") >= 4
		and AnalyticsLog.count("level_lose") >= 1, "analitik olayları kaydedildi")

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
		var double_button: Button = Button.new()
		_game.call("_on_double_coins", double_button, reward)
		await _frames(SETTLE_FRAMES)
		double_button.free()
	# Devam: geçiş reklamı kararı burada işler (sağlayıcı anında biter).
	var flow: Node = _game.get("_eco") as Node
	flow.call("maybe_interstitial", int(_game.get("_level_number")), func() -> void: pass)


func _lose_current_level() -> void:
	for id: int in [0, 1, 2, 3]:
		_game.call("_tap", id)
		await _frames(4)
	await _wait_overlay()
	_check(_board().is_lost(), "seviye kaybedilmeli")


func _count_buttons(node: Node) -> int:
	if node == null:
		return 0
	var total: int = 1 if node is Button else 0
	for child: Node in node.get_children():
		total += _count_buttons(child)
	return total


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
