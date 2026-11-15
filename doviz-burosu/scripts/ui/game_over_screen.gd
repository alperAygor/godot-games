extends Control
## Oyunun sonu: 15. gün bittiğinde bayraklara göre bir son (Endings), ya da oyun içi bitiş (kovuldun, tutuklandın...).
## Oyun içi bitişte ASLA çıkmaz yok (O8, kural DayRetry + data/ads.json free_retry): sabah anlık görüntüsü varsa
## "Günü tekrar oyna" kartı ne kalacağını ve bedelini SEÇİMDEN ÖNCE gösterir:
## - RetryDayButton (birincil): günün ücretsiz hakkı / no_ads sahibine bedelsiz / hak bittiyse oyun içi PL bedeli. Hep vardır.
## - RetryAdButton: yalnız bedel varken; reklam hazırsa bedelsiz tekrar, değilse pasif ve "bedelli yol hep var" notu.
## - NewGameButton (sonucu yazılı), MenuButton.
## Görülen sonlar kayıttan bağımsız tutulur ve burada sayılır.

var _offer: Dictionary = {}
var _busy := false


func _ready() -> void:
	if GameSession.career == null and not GameSession.continue_game():
		UiKit.redirect_when_idle(get_tree(), Scenes.MAIN)
		return
	var career := GameSession.career
	var db := StoryDb.load_default()
	var ending := Endings.resolve(career, db)
	var over := career.is_over()
	if not ending.is_empty():
		GameSession.record_ending(str(ending["id"]))
		Analytics.log_event("ending", {"id": ending["id"]})
	AudioManager.play_track(_ending_track(str(ending.get("id", ""))), 2.0)
	if over:
		Feel.sfx("chime_fail")
	else:
		Feel.sfx("stinger_win")
		if _ending_track(str(ending.get("id", ""))) == "ending_warm":
			Fx.confetti(self)
	var can_retry := over and not career.morning_snapshot.is_empty()
	var column := UiKit.screen_column(self, 14)
	# İçerik tek blok halinde dikeyde ortalanır (üstte ve altta eşit boşluk; ortada ölü alan kalmaz).
	column.add_child(_spacer())
	var title := UiKit.label(tr(str(ending.get("title_key", "GAMEOVER_TITLE"))), &"BoothTitle", "GameOverTitle")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(title)
	var body := tr(str(ending["body_key"])) if not ending.is_empty() else ""
	if over:
		body = (body + "\n\n" if not body.is_empty() else "") + tr("END_OVER_%s" % career.game_over.to_upper())
	var message := UiKit.wrapped(body, &"BoothBody", "GameOverMessage")
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(message)
	var seen := UiKit.label(tr("ENDING_COUNT") % [GameSession.endings_seen().size(), Endings.all_ids(db).size()], &"BoothMuted", "EndingCount")
	seen.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(seen)
	if can_retry:
		column.add_child(_retry_card(career))
	# Tek birincil eylem: tekrar kartı varken onun düğmesi; yoksa (hikaye sonu) "Yeni oyun".
	var again := UiKit.button(tr("MENU_NEW_GAME"), "NewGameButton", &"GhostButton" if can_retry else &"InkButton", 88.0 if can_retry else 96.0)
	again.pressed.connect(func() -> void:
		GameSession.new_game()
		SceneManager.goto(Scenes.MORNING))
	var menu := UiKit.button(tr("END_MENU"), "MenuButton", &"GhostButton", 88.0)
	menu.pressed.connect(func() -> void: SceneManager.goto(Scenes.MAIN))
	if can_retry:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		for button: Button in [again, menu]:
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(button)
		column.add_child(row)
	else:
		column.add_child(again)
	var note := UiKit.wrapped(tr("B1_NEW_GAME_NOTE"), &"BoothMuted", "NewGameNote")
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(note)
	if not can_retry:
		column.add_child(menu)
	column.add_child(_spacer())
	print("[GameOver] son: %s%s" % [ending.get("id", "-"), " (oyun içi: %s)" % career.game_over if over else ""])


func _spacer() -> Control:
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return spacer


## "Günü tekrar oyna" kartı: ne kalır, hangi yol ne tutar; birincil düğme ve (bedel varsa) reklam alternatifi.
func _retry_card(career: Career) -> Control:
	_offer = DayRetry.quote(career, Monetization.owns_no_ads())
	var day := int(_offer["day"])
	var box := UiKit.card(tr("B1_RETRY_TITLE") % day, &"CardPanel", "RetryCard", "refresh")
	box.add_child(UiKit.wrapped(tr("B1_RETRY_KEEP") % [day, UiKit.money(int(_offer["morning_cash_minor"]), "PL")], &"GoalLabel", "RetryKeep"))
	var kind := str(_offer["kind"])
	var text := tr("B1_RETRY_FREE")
	var detail := tr("B1_RETRY_FREE_NOTE") % UiKit.money(int(_offer["price_minor"]), "PL")
	if kind == DayRetry.KIND_NO_ADS:
		text = tr("B1_RETRY_NOADS")
		detail = tr("B1_RETRY_NOADS_NOTE")
	elif kind == DayRetry.KIND_PAID and int(_offer["cost_minor"]) > 0:
		text = tr("B1_RETRY_PAID") % UiKit.money(int(_offer["cost_minor"]), "PL")
		detail = tr("B1_RETRY_PAID_NOTE") % [UiKit.money(int(_offer["morning_cash_minor"]), "PL"), UiKit.money(int(_offer["cash_after_minor"]), "PL")]
	elif kind == DayRetry.KIND_PAID:
		text = tr("B1_RETRY_PAID_ZERO")
		detail = tr("B1_RETRY_PAID_ZERO_NOTE")
	var retry := UiKit.button(text, "RetryDayButton", &"InkButton", 96.0)
	retry.pressed.connect(_retry_without_ad)
	box.add_child(retry)
	box.add_child(UiKit.wrapped(detail, &"CardDetail", "RetryDetail"))
	if bool(_offer["ad_useful"]):
		var options := Monetization.retry_day_options()
		var ad: Dictionary = options["ad"]
		if bool(ad["visible"]):
			var ad_button := UiKit.icon_button("ad", tr("B1_RETRY_AD") if bool(ad["enabled"]) else tr("AD_UNAVAILABLE"), "RetryAdButton", true, false, 88.0)
			ad_button.disabled = not bool(ad["enabled"])
			ad_button.pressed.connect(_retry_with_ad.bind(ad_button))
			box.add_child(ad_button)
			box.add_child(UiKit.wrapped(tr("B1_RETRY_AD_NOTE") if bool(ad["enabled"]) else tr("B1_RETRY_AD_NONE"), &"CardDetail", "RetryAdDetail"))
	return box.get_meta("panel")


## Ücretsiz / reklamsız / bedelli tekrar. Bedel T-M1 sözleşmesinden gelir (take_free_retry → cost), kuralı DayRetry uygular.
func _retry_without_ad() -> void:
	if _busy:
		return
	_busy = true
	var career := GameSession.career
	var cfg := DayRetry.config().duplicate(true)
	var taken := Monetization.take_free_retry()
	if bool(taken.get("ok", false)):
		cfg["cost"] = {"kind": str(taken["cost_kind"]), "value": int(taken["cost_value"])}
	var offer := DayRetry.quote(career, Monetization.owns_no_ads(), cfg)
	Analytics.log_event("retry_day", {"kind": offer["kind"], "cost_pl": int(offer["cost_minor"]) / Money.UNIT, "day": offer["day"]})
	_finish(DayRetry.apply(career, offer))


func _retry_with_ad(button: Button) -> void:
	if _busy:
		return
	_busy = true
	button.disabled = true
	Monetization.request_reward("retry_day", func(rewarded: bool) -> void:
		if not is_inside_tree():
			return
		if rewarded:
			Analytics.log_event("retry_day", {"kind": DayRetry.KIND_AD, "cost_pl": 0, "day": GameSession.career.day})
			_finish(DayRetry.apply(GameSession.career, DayRetry.quote(GameSession.career, Monetization.owns_no_ads()), true))
		else:
			_busy = false
			button.disabled = not bool(Monetization.retry_day_options()["ad"]["enabled"]))


func _finish(ok: bool) -> void:
	if not ok:
		_busy = false
		return
	GameSession.save()
	SceneManager.goto(Scenes.MORNING)


## Sonun havasına göre müzik: sıcak (dürüst, merhametli, muhbir), kaçış, koyu (kovulma, tutuklanma, gri).
static func _ending_track(ending_id: String) -> String:
	if ending_id in ["honest", "mercy", "informant"]:
		return "ending_warm"
	if ending_id == "escape":
		return "ending_escape"
	return "ending_dark"


func handle_back() -> bool:
	SceneManager.goto(Scenes.MAIN)
	return true
