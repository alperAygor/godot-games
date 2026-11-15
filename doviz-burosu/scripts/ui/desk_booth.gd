class_name DeskBooth
extends RefCounted
## Masanın üst yarısı: gişe sahnesi (`BoothView`: müşteri, balon, isim plakası) ve üstüne binen bildirimler:
## uyarı fişi ("Slip": işlem sonucu) ve gün ortası / yeni kural duyurusu ("MiddayBanner"). Süreler `tick` ile işler.

const SLIP_SECONDS := 4.0
const MIDDAY_SECONDS := 4.0

var desk: DeskScreen
var view: BoothView
var face: FaceView
var name_label: Label
var bubble_label: Label
var slip: PanelContainer
var midday_banner: PanelContainer

var _slip_box: VBoxContainer
var _slip_left := 0.0
var _midday_left := 0.0


func _init(owner_desk: DeskScreen) -> void:
	desk = owner_desk


func build() -> BoothView:
	view = BoothView.new()
	face = view.figure.face
	name_label = view.plate_label
	bubble_label = view.bubble.label
	if Monetization.owns_no_ads():
		var decor := SupporterDecor.new()
		decor.position = Vector2(34, 232)
		view.overlay.add_child(decor)
	# Uyarı fişi ve gün ortası duyurusu gişe sahnesinin üstüne biner (sıradaki müşterinin banknotlarını örtmesin).
	slip = PanelContainer.new()
	slip.name = "Slip"
	slip.visible = false
	slip.z_index = 20
	slip.set_anchors_preset(Control.PRESET_TOP_WIDE)
	slip.gui_input.connect(_on_slip_input)
	_slip_box = VBoxContainer.new()
	_slip_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slip.add_child(_slip_box)
	view.overlay.add_child(slip)
	midday_banner = PanelContainer.new()
	midday_banner.name = "MiddayBanner"
	midday_banner.theme_type_variation = &"SlipPanel"
	midday_banner.visible = false
	midday_banner.z_index = 25
	midday_banner.set_anchors_preset(Control.PRESET_TOP_WIDE)
	midday_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	midday_banner.add_child(UiKit.label(tr("DESK_MIDDAY_UPDATE"), &"SlipTitle", "MiddayText"))
	view.overlay.add_child(midday_banner)
	return view


## Fiş ve duyuru zamanlayıcıları (vardiya saatiyle birlikte işler).
func tick(delta: float) -> void:
	if _slip_left > 0.0:
		_slip_left -= delta
		if _slip_left <= 0.0:
			slip.visible = false
	if _midday_left > 0.0:
		_midday_left -= delta
		if _midday_left <= 0.0:
			midday_banner.visible = false


func reset() -> void:
	midday_banner.visible = false
	slip.visible = false


## Duyuru şeridi: gün ortası kur güncellemesi ya da (modlarda) yeni kural.
func announce(text := "") -> void:
	if not text.is_empty():
		(midday_banner.get_child(0) as Label).text = text
	midday_banner.visible = true
	_midday_left = MIDDAY_SECONDS


func show_slip(result: Dictionary, verdict: Verdict) -> void:
	UiKit.clear(_slip_box)
	var title := ""
	if bool(result["correct"]):
		slip.theme_type_variation = &"SlipOkPanel"
		title = tr("SLIP_TITLE_OK") % UiKit.money(int(result["bonus_minor"]), "PL")
		if int(result["skimmed_minor"]) > 0:
			title += "  (+%s)" % UiKit.money(int(result["skimmed_minor"]), "PL")
	elif bool(result["fined"]):
		slip.theme_type_variation = &"CardBrokenPanel"
		title = tr("SLIP_TITLE_FINE") % UiKit.money(int(result["fine_minor"]), "PL")
	else:
		slip.theme_type_variation = &"SlipPanel"
		title = tr("SLIP_TITLE_WARNING")
	_slip_box.add_child(UiKit.label(title, &"SlipTitle", "SlipTitle"))
	var lines := Slip.lines(result["mistakes"], verdict)
	for line in lines:
		var text := UiKit.label("• " + format_line(line), &"SlipLine")
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_slip_box.add_child(text)
	var shift := desk.shift
	if not bool(result["correct"]) and not bool(result["fined"]):
		var left := maxi(0, int(shift.ctx.balance["shift"]["free_mistakes"]) - int(shift.stats["mistake_transactions"]))
		_slip_box.add_child(UiKit.label(tr("DESK_FREE_LEFT") % left, &"SlipLine"))
	slip.visible = true
	_slip_left = SLIP_SECONDS


## Fiş süresini (öğretici okurken) uzatır; fiş zaten kapalıysa bir şey yapmaz.
func hold_slip(seconds: float) -> void:
	if slip.visible:
		_slip_left = maxf(_slip_left, seconds)


static func format_line(line: Dictionary) -> String:
	var args: Array = []
	for arg: Variant in line["args"]:
		if arg is String and (arg as String).begins_with("@"):
			args.append(TranslationServer.translate((arg as String).substr(1)))
		elif arg is Dictionary and (arg as Dictionary).has("money"):
			args.append(UiKit.money(int(arg["money"][0]), str(arg["money"][1])))
		else:
			args.append(arg)
	var template := TranslationServer.translate(str(line["key"]))
	return template % args if not args.is_empty() else template


func _on_slip_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		slip.visible = false
		_slip_left = 0.0
