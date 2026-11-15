extends GameModule
class_name MonetizationHooks
## Reklam akışının oyuna/menülere BAĞLANDIĞI tek yer (C8). Servis katmanı (`Ads` cephesi, AdManager, AdPacing) ve kurallar
## (`data/ads.json`) hazırdı; burası onları `scene.events` kancalarına ve menü eklenti noktalarına (seam) bağlar:
##   ölüm            RunFlow.on_player_died → offer_revive(): oyun duraklar, "İZLE VE CANLAN" teklifi (geri sayım + VAZGEÇ);
##                   ödül → RunFlow.revive("ad"); vazgeç/hata/zaman aşımı → RunFlow.finish_death() (normal oyun sonu)
##   oyun sonu       "İZLE: ÇEKİRDEK ×2" (gameover.add_reward_action, bir kez)  ·  TEKRAR OYNA / ANA MENÜ → geçiş reklamı
##   kart ekranı     yenileme bitince "İZLE: +1 YENİLE" (cards.add_below_reroll, koşu başına sınır veride)
##   ana menü        "GÜNLÜK BONUS" girişi (main.add_entry; gün başına bir kez)       ayarlar: gizlilik satırı (settings.add_row)
##   yaşam döngüsü   run_started → Ads.begin_run(); reklam gösterilirken oyun duraklar + ses kısılır, bitince ÖNCEKİ durum geri gelir
## Kurallar: ilk koşu temiz (hiçbir reklam arayüzü yok; AdFlow.min_completed_runs), demo/bot koşusunda hiçbir şey çıkmaz,
## `Ads.can_show` false ise düğme/teklif GÖRÜNMEZ. Geçiş reklamı yalnız oyun sonu ekranından, `then` her durumda bir kez.
## Dil değişince ekranlar yeniden kurulur (menus.screens_rebuilt): eklenen denetimler orada yeniden eklenir.

const OverlayScript = preload("res://scripts/ui/ad_overlay.gd")
const WATCHDOG_SECONDS := 0.5

var cfg: AdFlow
var enabled := true                 ## false: demo/bot koşusu (hiçbir reklam arayüzü yok)
var ad_active := false              ## bir reklam şu an gösteriliyor (ad_started .. bitiş)
var revive_used := false            ## bu koşuda reklamla diriltme verildi
var double_used := false            ## bu koşuda çekirdekler ikiye katlandı
var double_extra := 0               ## çift çekirdekle eklenen miktar
var overlay: AdOverlay

var _layer: CanvasLayer
var _manager: Node
var _run_serial := 0
var _run_unlocked := false          ## bu koşu BAŞLARKEN yeterince koşu bitmişti (ilk koşu temiz)
var _revive_pending := false        ## teklif açık ya da diriltme reklamı bekleniyor
var _transition_pending := false
var _double_busy := false
var _reroll_busy := false
var _daily_busy := false
var _hold: Dictionary = {}
var _double_button: Button
var _reroll_button: Button
var _daily_button: Button
var _privacy_row: Control


func build(parent: Node) -> void:
	## game3d._build_scene çağırır (menüler kurulduktan sonra).
	cfg = AdFlow.load_file()
	enabled = not ctx.options.demo
	_layer = CanvasLayer.new()
	_layer.layer = 20
	parent.add_child(_layer)
	overlay = OverlayScript.new()
	_layer.add_child(overlay)
	overlay.accepted.connect(_on_offer_accepted)
	overlay.declined.connect(_on_offer_declined)
	ctx.events.run_started.connect(_on_run_started)
	ctx.events.run_ended.connect(_on_run_ended)
	ctx.events.cards_shown.connect(_on_cards_shown)
	ctx.menus.screens_rebuilt.connect(_on_screens_rebuilt)
	_manager = Ads.manager()
	if _manager != null:
		_manager.ad_started.connect(_on_ad_started)
		_manager.rewarded_finished.connect(_on_rewarded_finished)
		_manager.interstitial_finished.connect(_on_interstitial_finished)
		_manager.ad_failed.connect(_on_ad_failed)
		_manager.availability_changed.connect(_on_availability_changed)
	_install_seams()


# --- Uygunluk ------------------------------------------------------------------------
func completed_runs() -> int:
	return int(Settings.get_flag("run_counter", 0))


func ads_allowed_now() -> bool:
	## Menüde (koşu dışı): yeterince koşu bitti mi?
	return enabled and cfg.ads_unlocked(completed_runs())


func ads_allowed_this_run() -> bool:
	return enabled and _run_unlocked


# --- Koşu yaşam döngüsü --------------------------------------------------------------
func _on_run_started(_ship: String, _seed: int) -> void:
	Ads.begin_run()
	_run_serial += 1
	_run_unlocked = cfg.ads_unlocked(completed_runs())
	revive_used = false
	double_used = false
	double_extra = 0
	_revive_pending = false
	_transition_pending = false
	_double_busy = false
	_reroll_busy = false
	if ad_active:   # beklenmedik: yeni koşu başlarken reklam tutuluyorsa kilidi bırak (start_game zaten duraklatmayı kaldırdı)
		ad_active = false
		Sound.set_ad_muted(false)
	overlay.hide_overlay()
	_refresh_buttons()


func on_menu_shown() -> void:
	## RunFlow.enter_menu çağırır: ana menü girişi tazelenir.
	_refresh_daily()


func _on_run_ended(_summary: Dictionary) -> void:
	_refresh_buttons()


# --- Bekçiler: reklam sürerken menü eylemleri yok sayılır ----------------------------------
func busy() -> bool:
	return ad_active or _revive_pending or _transition_pending


func on_play() -> void:
	if not busy():
		ctx.flow.start_game()


func on_resume() -> void:
	if not busy():
		ctx.flow.resume()


func on_pause_requested() -> void:
	if not busy():
		ctx.flow.pause()


func on_card_picked(index: int) -> void:
	if not busy():
		ctx.cards.pick(index)


func on_reroll() -> void:
	if not busy():
		ctx.cards.reroll()


## TEKRAR OYNA / YENİDEN BAŞLA: koşu bittiyse (oyun sonu ekranı) önce geçiş reklamı kararı, sonra asıl işlem.
func on_restart() -> void:
	_leave_run(ctx.flow.start_game)


## ANA MENÜ.
func on_menu() -> void:
	_leave_run(ctx.flow.enter_menu)


func _leave_run(action: Callable) -> void:
	if busy():
		return
	if enabled and ctx.state == "dead":
		_transition_pending = true
		var done := func() -> void:
			_transition_pending = false
			action.call()
		# Settings.record_run ölümde zaten çalıştı (koşu sayacı biten koşuyu içerir). `done` her durumda TAM BİR KEZ.
		Ads.maybe_interstitial({"died": true}, done)
		return
	action.call()


# --- Reklam sırasında duraklat + sustur, bitince ÖNCEKİ durumu geri getir --------------------
func _on_ad_started(_placement: int) -> void:
	if ad_active:
		return
	ad_active = true
	var tree := ctx.host.get_tree()
	_hold = {"paused": tree.paused, "ad_muted": Sound.ad_muted}
	tree.paused = true
	Fx.settle_time()
	ctx.touch.release_all()
	Sound.set_ad_muted(true)
	overlay.show_veil()
	_watchdog(_run_serial)


func _release_ad() -> void:
	if not ad_active:
		return
	ad_active = false
	ctx.host.get_tree().paused = bool(_hold.get("paused", false))
	Sound.set_ad_muted(bool(_hold.get("ad_muted", false)))
	_hold = {}
	overlay.hide_overlay()


func _watchdog(serial: int) -> void:
	## Yönetici bekleyen isteği sessizce bıraktıysa (sağlayıcı değişti) oyun duraklı kalmasın.
	while ad_active and serial == _run_serial:
		await ctx.host.get_tree().create_timer(WATCHDOG_SECONDS, true, false, true).timeout
		if ad_active and _manager != null and is_instance_valid(_manager) and not bool(_manager.call("is_ad_pending")):
			_release_ad()


func _on_rewarded_finished(_placement: int, _success: bool) -> void:
	_release_ad()


func _on_interstitial_finished(_success: bool) -> void:
	_release_ad()


func _on_ad_failed(_placement: int, _reason: String) -> void:
	_release_ad()


func _on_availability_changed() -> void:
	_install_privacy()
	_refresh_buttons()


# --- Ölümde reklamla diriltme ---------------------------------------------------------------
func offer_revive() -> bool:
	## RunFlow.on_player_died çağırır (kart diriltmesi YOKSA). true = ölüm sekansı bekletildi.
	if not ads_allowed_this_run() or revive_used or _revive_pending:
		return false
	if not Ads.can_show(AdPlacement.Id.REVIVE):
		return false
	_revive_pending = true
	ctx.host.get_tree().paused = true
	Fx.settle_time()
	ctx.touch.release_all()
	ctx.hud.dimmed = true
	Sound.set_muffled(true)
	overlay.show_offer(cfg.revive_offer_seconds)
	return true


func _end_offer_pause() -> void:
	overlay.hide_overlay()
	ctx.host.get_tree().paused = false
	ctx.hud.dimmed = false
	Sound.set_muffled(false)


func _on_offer_accepted() -> void:
	if not _revive_pending:
		return
	# Geri çağrılar senkron da gelebilir (reklam yok): _revive_pending bayrağı her yolu tek sefere indirir.
	Ads.show_rewarded(AdPlacement.Id.REVIVE, _on_revive_reward, _on_revive_failed)


func _on_offer_declined() -> void:
	if not _revive_pending:
		return
	_revive_pending = false
	_end_offer_pause()
	ctx.flow.finish_death()


func _on_revive_reward() -> void:
	if not _revive_pending:
		return
	_revive_pending = false
	revive_used = true
	_end_offer_pause()
	ctx.flow.revive("ad")


func _on_revive_failed(_reason: String) -> void:
	if not _revive_pending:
		return
	_revive_pending = false
	_end_offer_pause()
	ctx.flow.finish_death()


# --- Eklenti noktaları (seam) --------------------------------------------------------------
func _on_screens_rebuilt() -> void:
	_install_seams()


func _install_seams() -> void:
	## Dil değişiminde ekran modülleri yeni örnek olur; eklenenler gider: hepsi yeniden eklenir.
	var menus := ctx.menus
	_double_button = KIT.button(tr("İZLE: ÇEKİRDEK ×2"), KIT.GOLD, Vector2(360, 52), 20)
	_double_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_double_button.visible = false
	_double_button.pressed.connect(_on_double_pressed)
	menus.gameover.add_reward_action(_double_button)
	_reroll_button = KIT.button(tr("İZLE: +1 YENİLE"), KIT.GREEN, Vector2(250, 46), 18)
	_reroll_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_reroll_button.visible = false
	_reroll_button.pressed.connect(_on_reroll_ad_pressed)
	menus.cards.add_below_reroll(_reroll_button)
	_daily_button = KIT.button(tr("GÜNLÜK BONUS  +%d") % cfg.daily_bonus_cores, KIT.GOLD, Vector2(360, 54), 20)
	_daily_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_daily_button.visible = false
	_daily_button.pressed.connect(_on_daily_pressed)
	menus.main.add_entry(_daily_button)
	_privacy_row = null
	_install_privacy()
	_refresh_buttons()


func _install_privacy() -> void:
	if _privacy_row != null and is_instance_valid(_privacy_row):
		return
	if not Ads.privacy_options_required():
		return
	var open := KIT.button(tr("AÇ"), KIT.VIOLET, Vector2(170, 50), 20)
	open.pressed.connect(func() -> void: Ads.show_privacy_options(func() -> void: pass))
	_privacy_row = ctx.menus.settings.add_row(tr("GİZLİLİK SEÇENEKLERİ"), open)


func _refresh_buttons() -> void:
	_refresh_double()
	_refresh_daily()
	if ctx.cards != null and ctx.cards.is_open:
		_refresh_reroll()


func _alive(node: Control) -> bool:
	return node != null and is_instance_valid(node)


# --- Çift çekirdek --------------------------------------------------------------------------
func _refresh_double() -> void:
	if not _alive(_double_button):
		return
	# Kazanç 0 ise ×2 değersiz: düğme çıkmaz (ölü teklif yok).
	_double_button.visible = ads_allowed_this_run() and ctx.state == "dead" and not double_used \
		and ctx.flow.cores_earned > 0 and Ads.can_show(AdPlacement.Id.DOUBLE_CORES)
	_double_button.disabled = _double_busy


func _on_double_pressed() -> void:
	if _double_busy or double_used or ad_active or ctx.state != "dead":
		return   # çift dokunuş: ikinci basış yok sayılır
	_double_busy = true
	_double_button.disabled = true
	var serial := _run_serial
	var started := Ads.show_rewarded(AdPlacement.Id.DOUBLE_CORES, _on_double_reward.bind(serial), _on_double_failed.bind(serial))
	if not started:
		_double_busy = false
		_refresh_double()


func _on_double_reward(serial: int) -> void:
	if serial != _run_serial or double_used:
		return
	_double_busy = false
	double_used = true
	double_extra = cfg.double_bonus(ctx.flow.cores_earned)
	Settings.meta.earn(double_extra)
	Settings.save()
	ctx.menus.gameover.set_cores(ctx.flow.cores_earned + double_extra, Settings.meta.cores)
	ctx.menus.sync_main_cores()
	_refresh_double()


func _on_double_failed(_reason: String, serial: int) -> void:
	if serial != _run_serial:
		return
	_double_busy = false
	_refresh_double()


# --- Kart ekranında +1 yenileme ---------------------------------------------------------------
func _on_cards_shown(_cards: Array, _rerolls: int) -> void:
	_refresh_reroll()


func _refresh_reroll() -> void:
	if not _alive(_reroll_button):
		return
	_reroll_button.visible = ads_allowed_this_run() and cfg.reroll_offer_wanted(ctx.rerolls) \
		and Ads.can_show(AdPlacement.Id.REROLL)
	_reroll_button.disabled = _reroll_busy


func _on_reroll_ad_pressed() -> void:
	if _reroll_busy or ad_active or not ctx.cards.is_open:
		return
	_reroll_busy = true
	_reroll_button.disabled = true
	var serial := _run_serial
	var started := Ads.show_rewarded(AdPlacement.Id.REROLL, _on_reroll_reward.bind(serial), _on_reroll_failed.bind(serial))
	if not started:
		_reroll_busy = false
		_refresh_reroll()


func _on_reroll_reward(serial: int) -> void:
	_reroll_busy = false
	if serial != _run_serial:
		return
	ctx.cards.grant_reroll(cfg.reroll_grant)
	ctx.menus.cards.set_rerolls(ctx.rerolls)
	_refresh_reroll()


func _on_reroll_failed(_reason: String, serial: int) -> void:
	_reroll_busy = false
	if serial == _run_serial:
		_refresh_reroll()


# --- Günlük bonus (ana menü) --------------------------------------------------------------------
func _refresh_daily() -> void:
	if not _alive(_daily_button):
		return
	_daily_button.visible = ads_allowed_now() and ctx.state == "menu" and Ads.daily_bonus_available()
	_daily_button.disabled = _daily_busy


func _on_daily_pressed() -> void:
	if _daily_busy or ad_active:
		return
	_daily_busy = true
	_daily_button.disabled = true
	var started := Ads.show_rewarded(AdPlacement.Id.DAILY_BONUS, _on_daily_reward, _on_daily_failed)
	if not started:
		_daily_busy = false
		_refresh_daily()


func _on_daily_reward() -> void:
	# Gün kaydı (flags.daily_bonus_date) AdManager'da ödülden ÖNCE yazıldı: aynı gün ikinci talep mümkün değil.
	_daily_busy = false
	Settings.meta.earn(cfg.daily_bonus_cores)
	Settings.save()
	ctx.menus.sync_main_cores()
	ctx.menus.notify(tr("GÜNLÜK BONUS: +%d ÇEKİRDEK") % cfg.daily_bonus_cores)
	Sound.play("revive")
	_refresh_daily()


func _on_daily_failed(_reason: String) -> void:
	_daily_busy = false
	_refresh_daily()
