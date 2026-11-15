class_name ConsentSheet
extends Control
## Gizlilik ve reklam penceresi — TEK onay deneyiminin oyun tarafı (bkz. ConsentFlow, docs/MONETIZATION.md).
##  - UMP'nin geçerli olmadığı bölgelerde (NOTICE): ilk açılışta bir kez kısa, dürüst bilgi + "kişiselleştirilmiş / kişiselleştirilmemiş reklam" seçimi.
##    Kararı `Monetization.apply_consent` uygular; reklam SDK'sı bundan sonra başlar. Ayarlar > Gizlilik seçenekleri'nde aynı pencere tercihi değiştirir.
##  - UMP'nin geçerli olduğu bölgelerde (FORM, AB/UK): ilk açılışta bu pencere ÇIKMAZ (yalnızca Google'ın formu çıkar). Ayarlardan açılırsa
##    "Reklam seçenekleri" düğmesi UMP formunu yeniden açar; kişiselleştirme kararı UMP'nindir.
## Her iki kipte de gizlilik politikası bağlantısı (adres geçerliyse) ve metin gerçeği söyler: analitik yok, hesap yok, kişisel veri toplanmaz.
## Düğme adları (TouchInput): ConsentAcceptButton, ConsentDeclineButton, ConsentFormButton, PrivacyPolicyButton, ConsentCloseButton.

signal decided(personalized: bool)

var form_mode := false


func _init() -> void:
	name = "ConsentSheet"
	form_mode = Monetization.provider_form_applies()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	z_index = 50
	var dim := ColorRect.new()
	dim.color = UiKit.DIM_COLOR
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := UiKit.card("", &"FloatCard")
	box.get_meta("panel").custom_minimum_size.x = 600.0
	center.add_child(box.get_meta("panel"))
	box.add_child(UiKit.label(tr("MON_PRIVACY_TITLE"), &"SheetTitle", "ConsentTitle"))
	box.add_child(UiKit.wrapped(tr("MON_FORM_TEXT" if form_mode else "MON_NOTICE_TEXT"), &"GoalLabel", "ConsentText"))
	if form_mode:
		var choices := UiKit.button(tr("MON_AD_CHOICES"), "ConsentFormButton", &"", 84.0)
		choices.pressed.connect(_open_form)
		box.add_child(choices)
	else:
		var accept := UiKit.button(tr("MON_PERSONAL"), "ConsentAcceptButton", &"", 84.0)
		accept.pressed.connect(_decide.bind(true))
		box.add_child(accept)
		var decline := UiKit.button(tr("MON_NONPERSONAL"), "ConsentDeclineButton", &"GhostButton", 84.0)
		decline.pressed.connect(_decide.bind(false))
		box.add_child(decline)
	if Monetization.privacy_policy_visible():
		var policy := UiKit.button(tr("MON_PRIVACY_POLICY"), "PrivacyPolicyButton", &"GhostButton", 76.0)
		policy.pressed.connect(Monetization.open_privacy_policy)
		box.add_child(policy)
	if form_mode:
		var close := UiKit.button(tr("COMMON_CLOSE"), "ConsentCloseButton", &"GhostButton", 76.0)
		close.pressed.connect(queue_free)
		box.add_child(close)


func _open_form() -> void:
	Monetization.open_ump_privacy_options()
	queue_free()


func _decide(personalized: bool) -> void:
	Monetization.apply_consent(personalized)
	decided.emit(personalized)
	queue_free()
