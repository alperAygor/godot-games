extends Control
## Akşam: günün özeti, ev giderleri (seçmeli), döviz birikimi, "Eve git". Mantık EveningPlan'da; burası sadece çizer.
## Geri tuşu bu ekranda bir şey yapmaz (karar vermeden çıkış yok).

const CONVERT_AMOUNTS_PL := [100, 500, 1000]

var plan: EveningPlan

var _cash_label: Label
var _after_label: Label
var _expense_box: VBoxContainer
var _savings_box: VBoxContainer
var _shop_box: VBoxContainer
var _mood_label: Label
var _warn_label: Label
var _net_label: Label
var _summary_box: VBoxContainer
var _tip_box: VBoxContainer


func _ready() -> void:
	var session := GameSession
	if session.career == null or session.shift == null:
		# Doğrudan açıldıysa (geliştirme): ana menüye dön.
		UiKit.redirect_when_idle(get_tree(), Scenes.MAIN)
		return
	plan = EveningPlan.new(session.career, session.shift)
	Feel.sfx("chime_win" if int(plan.report["mistake_transactions"]) < 3 else "chime_fail")
	var column := UiKit.screen_column(self, 10)
	column.add_child(UiKit.label(tr("EVENING_TITLE") % session.career.day, &"BoothHeading", "EveningTitle"))
	var list := UiKit.scroll_box()
	column.add_child(list.get_meta("scroll"))
	list.add_child(_summary_card())
	var letter := _letter_card(session.career)
	if letter != null:
		list.add_child(letter)
	list.add_child(_expenses_card())
	list.add_child(_savings_card())
	list.add_child(_shop_card())
	list.add_child(_family_card())
	var go := UiKit.button(tr("EVENING_GO_HOME"), "GoHomeButton", &"InkButton", 96.0)
	go.pressed.connect(_go_home)
	column.add_child(go)
	_refresh()
	Fx.reveal_children(_summary_box)
	print("[Evening] gün %d" % session.career.day)


func handle_back() -> bool:
	return true


func _summary_card() -> Control:
	var report := plan.report
	var box := UiKit.card(tr("EVENING_SUMMARY"), &"CardPanel", "SummaryCard", "document")
	var lines: Array[String] = [
		tr("END_SERVED") % [int(report["served"]), int(report["correct"])],
		tr("END_MISTAKES") % int(report["mistake_transactions"]),
		tr("END_SALARY") % UiKit.money(int(report["base_minor"]), "PL"),
		tr("END_BONUS") % UiKit.money(int(report["bonus_minor"]), "PL"),
		(tr("END_FINES") % UiKit.money(int(report["fines_minor"]), "PL")) if int(report["fines_minor"]) > 0 else tr("END_NO_FINES"),
	]
	if int(report["skim_minor"]) > 0:
		lines.append(tr("EVENING_SKIM") % UiKit.money(int(report["skim_minor"]), "PL"))
	if int(report["story_minor"]) > 0:
		lines.append(tr("EVENING_STORY_MONEY") % UiKit.money(int(report["story_minor"]), "PL"))
	if int(report["story_minor"]) < 0:
		lines.append(tr("EVENING_STORY_COST") % UiKit.money(-int(report["story_minor"]), "PL"))
	if int(report.get("calls_missed", 0)) > 0:
		lines.append(tr("EVENING_CALLS_MISSED") % int(report["calls_missed"]))
	if not str(report.get("directive_id", "")).is_empty():
		var directive_minor := int(report["directive_minor"])
		if bool(report["directive_met"]):
			lines.append(tr("DIR_EVENING_MET") % UiKit.money(directive_minor, "PL"))
		else:
			lines.append(tr("DIR_EVENING_FAILED") % ("-" + UiKit.money(-directive_minor, "PL")))
	for text in lines:
		box.add_child(UiKit.label(text, &"GoalLabel"))
	_net_label = UiKit.label(tr("END_NET") % UiKit.money(int(report["net_minor"]), "PL"), &"GoalTitle", "NetPay")
	box.add_child(_net_label)
	_summary_box = box
	_cash_label = UiKit.label("", &"BigNumber", "CashLabel")
	box.add_child(_cash_label)
	_add_double_pay_offer()
	return box.get_meta("panel")


## Evden gelen mektup (hikaye açıkken; günün koşulu sağlanan ilk mektubu). Yoksa null.
func _letter_card(career: Career) -> Control:
	if not career.story_enabled:
		return null
	var key := StoryDb.load_default().letter_key(career.day, career.story)
	if key.is_empty():
		return null
	var box := UiKit.card(tr("EVENING_LETTER"), &"SlipPanel", "LetterCard", "house")
	box.add_child(UiKit.wrapped(tr(key), &"SlipLine", "LetterText"))
	return box.get_meta("panel")


func _expenses_card() -> Control:
	var box := UiKit.card(tr("EVENING_EXPENSES"), &"CardPanel", "ExpensesCard", "wallet")
	_expense_box = VBoxContainer.new()
	_expense_box.add_theme_constant_override("separation", 6)
	box.add_child(_expense_box)
	_after_label = UiKit.label("", &"GoalLabel", "AfterLabel")
	box.add_child(_after_label)
	_warn_label = UiKit.wrapped(tr("EVENING_WARN"), &"CardDetail", "WarnLabel")
	box.add_child(_warn_label)
	return box.get_meta("panel")


func _savings_card() -> Control:
	var box := UiKit.card(tr("EVENING_SAVINGS"), &"CardPanel", "SavingsCard", "coin")
	_savings_box = VBoxContainer.new()
	_savings_box.add_theme_constant_override("separation", 6)
	box.add_child(_savings_box)
	_tip_box = VBoxContainer.new()
	_tip_box.add_theme_constant_override("separation", 6)
	box.add_child(_tip_box)
	_refresh_tip()
	return box.get_meta("panel")


func _shop_card() -> Control:
	var box := UiKit.card(tr("EVENING_TOOLS"), &"CardPanel", "ShopCard", "magnifier")
	_shop_box = VBoxContainer.new()
	_shop_box.add_theme_constant_override("separation", 6)
	box.add_child(_shop_box)
	return box.get_meta("panel")


func _family_card() -> Control:
	var box := UiKit.card("", &"CardPanel", "MoodCard")
	_mood_label = UiKit.label("", &"GoalLabel", "MoodLabel")
	box.add_child(_mood_label)
	return box.get_meta("panel")


## Planın durumuna göre tüm değişken parçaları yeniden çizer.
func _refresh() -> void:
	_cash_label.text = tr("EVENING_CASH") % UiKit.money(plan.cash_minor(), "PL")
	UiKit.clear(_expense_box)
	var due := plan.due()
	if due.is_empty():
		_expense_box.add_child(UiKit.label(tr("EVENING_EXPENSE_NONE"), &"CardDetail", "NoExpenses"))
	var any_unselected := false
	for expense in due:
		var expense_id := str(expense["id"])
		var toggle := Button.new()
		toggle.name = "Expense_%s" % expense_id
		toggle.theme_type_variation = &"SegmentButton"
		toggle.toggle_mode = true
		var status := tr("EVENING_WILL_PAY") if plan.is_selected(expense_id) else (tr("EVENING_WONT_PAY") if plan.can_toggle(expense_id) else tr("EVENING_CANT_AFFORD"))
		toggle.text = "%s — %s   [%s]" % [tr("EXPENSE_%s" % expense_id.to_upper()), UiKit.money(int(expense["amount_minor"]), "PL"), status]
		toggle.set_pressed_no_signal(plan.is_selected(expense_id))
		toggle.disabled = not plan.can_toggle(expense_id)
		toggle.custom_minimum_size.y = 84
		toggle.pressed.connect(_on_expense_toggled.bind(expense_id))
		_expense_box.add_child(toggle)
		if not plan.is_selected(expense_id):
			any_unselected = true
	_after_label.text = tr("EVENING_AFTER") % UiKit.money(plan.remaining_cash(), "PL")
	_warn_label.visible = any_unselected
	_refresh_savings()
	_refresh_shop()
	var mood := plan.career.household.mood
	_mood_label.text = tr("EVENING_MOOD") % mood


func _refresh_savings() -> void:
	UiKit.clear(_savings_box)
	var code := EveningPlan.SAVINGS_CODE
	var rates := plan.rates()
	_savings_box.add_child(UiKit.label(tr("EVENING_SAVINGS_LINE") % [code, UiKit.money(plan.savings_minor(), code), UiKit.money(plan.savings_value_minor(), "PL")], &"GoalLabel", "SavingsLine"))
	_savings_box.add_child(UiKit.label(tr("EVENING_SAVINGS_RATES") % [UiKit.rate_text(int(rates["buy"])), UiKit.rate_text(int(rates["sell"]))], &"CardDetail", "SavingsRates"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_savings_box.add_child(row)
	for amount in CONVERT_AMOUNTS_PL:
		var button := UiKit.icon_button("coin", tr("EVENING_TO_FOREIGN") % [UiKit.money(Money.units(amount), "PL"), code], "ToForeign_%d" % amount, true, false, 72.0)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.fit_minimum = false
		button.disabled = Money.units(amount) > plan.cash_minor()
		button.pressed.connect(_on_buy_savings.bind(amount))
		row.add_child(button)
	var sell := UiKit.icon_button("refresh", tr("EVENING_SELL_ALL") % code, "SellAllButton", true, false, 72.0)
	sell.disabled = plan.savings_minor() <= 0
	sell.pressed.connect(_on_sell_savings)
	_savings_box.add_child(sell)


func _refresh_shop() -> void:
	UiKit.clear(_shop_box)
	var items := plan.shop()
	if items.is_empty():
		_shop_box.add_child(UiKit.label(tr("EVENING_NO_TOOLS"), &"CardDetail", "NoTools"))
	for item in items:
		var tool_id := str(item["id"])
		var button := UiKit.icon_button(tool_id if Icons.SHAPES.has(tool_id) else "coin", tr("EVENING_BUY_TOOL") % [tr("TOOL_%s" % tool_id.to_upper()), UiKit.money(int(item["price_minor"]), "PL")],
			"BuyTool_%s" % tool_id, true, false, 72.0)
		button.disabled = int(item["price_minor"]) > plan.cash_minor()
		button.pressed.connect(_on_buy_tool.bind(tool_id))
		_shop_box.add_child(button)


func _on_buy_tool(tool_id: String) -> void:
	plan.buy_tool(tool_id)
	_refresh()


func _on_expense_toggled(expense_id: String) -> void:
	plan.toggle(expense_id)
	_refresh()


func _on_buy_savings(amount_pl: int) -> void:
	plan.buy_savings(Money.units(amount_pl))
	_refresh()


func _on_sell_savings() -> void:
	plan.sell_savings(plan.savings_minor())
	_refresh()


# --- Ödüllü reklam teklifleri (hepsi isteğe bağlı) -------------------------------------------

## Teklif düğmesi: sınır dolduysa null (hiç görünmez); reklam hazır değilse "Reklam şu an yok" diye pasif.
func _offer_button(placement: String, text: String, node_name: String, on_reward: Callable) -> Button:
	var offer := Monetization.rewarded_offer(placement, plan.career.ad_uses(placement))
	if not bool(offer["visible"]):
		return null
	var button := UiKit.icon_button("ad", text if bool(offer["enabled"]) else tr("AD_UNAVAILABLE"), node_name, true, false, 76.0)
	button.ink = Color("2E5B8A")
	button.disabled = not bool(offer["enabled"])
	button.pressed.connect(func() -> void:
		button.disabled = true
		Monetization.request_reward(placement, func(rewarded: bool) -> void:
			if rewarded:
				plan.career.mark_ad_used(placement)
				on_reward.call()
			if is_inside_tree():
				_refresh_offers()))
	return button


func _add_double_pay_offer() -> void:
	var extra := plan.career.double_pay_preview()
	if extra <= 0:
		return
	var button := _offer_button("double_pay", tr("AD_DOUBLE_PAY") % UiKit.money(extra, "PL"), "DoublePayButton", _on_double_pay)
	if button != null:
		_summary_box.add_child(button)


func _on_double_pay() -> void:
	var extra := plan.career.double_pay()
	_net_label.text = tr("END_NET") % UiKit.money(int(plan.career.pending_report["net_minor"]), "PL")
	_summary_box.add_child(UiKit.label(tr("AD_BONUS") % UiKit.money(extra, "PL"), &"GoalLabel", "AdBonusLine"))
	_refresh()


func _refresh_tip() -> void:
	UiKit.clear(_tip_box)
	if plan.career.ad_uses("rate_tip") > 0:
		var tip := plan.career.rate_tip()
		var key := "AD_TIP_UP" if int(tip["direction"]) > 0 else ("AD_TIP_DOWN" if int(tip["direction"]) < 0 else "AD_TIP_FLAT")
		var percent := absf(float(tip["percent_tenths"]) / 10.0)
		_tip_box.add_child(UiKit.wrapped(tr(key) % [str(tip["code"]), "%.1f" % percent], &"GoalLabel", "RateTipLine"))
		return
	var button := _offer_button("rate_tip", tr("AD_RATE_TIP"), "RateTipButton", func() -> void: pass)
	if button != null:
		_tip_box.add_child(button)


func _refresh_offers() -> void:
	_refresh_tip()
	var double_button := _summary_box.get_node_or_null("DoublePayButton")
	if double_button != null and plan.career.double_pay_preview() <= 0:
		double_button.queue_free()


func _go_home() -> void:
	plan.finish()
	GameSession.shift = null
	GameSession.save()
	Monetization.count_play_unit()
	Analytics.log_event("day_end", {"day": plan.career.day - 1})
	var next_scene := GameSession.route()
	if GameSession.career.is_over():  # oyun bitti ekranının önüne reklam konmaz
		SceneManager.goto(next_scene)
		return
	Monetization.show_interstitial_then("day_end", func() -> void: SceneManager.goto(next_scene))
