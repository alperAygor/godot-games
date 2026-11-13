extends Control

## Ana menü: Oyna -> sipariş seçimi, Garaj -> yükseltmeler, Ayarlar -> ses.
## İlk açılışta üç sayfalık kısa rehber gösterilir (ARCHITECTURE.md §5.6).
## F7.6b: cüzdan çipleri, ikonlu gezinme düğmeleri ve nokta sayfa göstergesi
## eklendi; renkler UiTheme (data/theme.json) token'larından okunur.

const PLAY_ICON_SIZE: int = 26
const NAV_ICON_SIZE: int = 20
const WALLET_ICON_SIZE: int = 20

@onready var play_button: Button = %PlayButton
@onready var garage_button: Button = %GarageButton
@onready var settings_button: Button = %SettingsButton
@onready var sound_button: Button = %SoundButton
@onready var hint_label: Label = %Hint
@onready var title_part1: Label = %TitlePart1
@onready var title_part2: Label = %TitlePart2
@onready var gold_icon: TextureRect = %GoldIcon
@onready var scrap_icon: TextureRect = %ScrapIcon
@onready var gold_label: Label = %GoldLabel
@onready var scrap_label: Label = %ScrapLabel
@onready var _tutorial_panel: Control = %TutorialPanel
@onready var _tutorial_title: Label = %TutorialTitle
@onready var _tutorial_text: Label = %TutorialText
@onready var _tutorial_next: Button = %TutorialNextButton
@onready var _tutorial_skip: Button = %TutorialSkipButton

var _tutorial_page: int = 0
var _dots: Array[Control] = []


func _ready() -> void:
	GameManager.set_phase(GameManager.Phase.MENU)
	_stylize()
	play_button.text = UiStrings.MENU_PLAY
	garage_button.text = UiStrings.MENU_GARAGE
	settings_button.text = UiStrings.MENU_SETTINGS
	sound_button.text = UiStrings.MENU_SOUND
	hint_label.text = UiStrings.MENU_HINT
	Icons.apply(play_button, "lucide/play", UiTheme.color("on_primary"), PLAY_ICON_SIZE)
	Icons.apply(garage_button, "lucide/wrench", UiTheme.color("on_surface"), NAV_ICON_SIZE)
	Icons.apply(settings_button, "lucide/settings", UiTheme.color("on_surface"), NAV_ICON_SIZE)
	# İkon-metin aralığı tüm ekranlarda tutarlı (F7.6b tasarım dili).
	play_button.add_theme_constant_override("h_separation", 16)
	garage_button.add_theme_constant_override("h_separation", 12)
	settings_button.add_theme_constant_override("h_separation", 12)
	_refresh_wallet()
	_refresh_record()
	_refresh_sound_button()
	play_button.pressed.connect(_on_play)
	garage_button.pressed.connect(_on_garage)
	settings_button.pressed.connect(_on_settings)
	sound_button.pressed.connect(_on_sound_toggle)
	GameManager.back_requested.connect(_on_back)
	_setup_tutorial()
	# Birincil "Oyna" düğmesi hafifçe nefes alır; basış ölçeği animasyonu nefes
	# tween'iyle çakışmasın diye bu düğme için kapatılır (UiMotion tek yerde).
	play_button.add_to_group(UiMotion.NO_PRESS_SCALE_GROUP)
	# Tıklama sesi + basışta küçülme tek yardımcıdan; sahne kodu tekrar etmez.
	UiSfx.bind(self)
	UiMotion.fade_in(self)
	UiMotion.breathe(play_button)


func _stylize() -> void:
	(%Background as ColorRect).color = UiTheme.color("background")
	title_part1.text = "Micro "
	title_part2.text = "Courier"
	title_part1.add_theme_color_override("font_color", UiTheme.color("text"))
	title_part2.add_theme_color_override("font_color", UiTheme.color("primary"))
	# İnce başlık gölgesi: yumuşak, koyu lacivert; okunurluğu artırır.
	for part: Label in [title_part1, title_part2]:
		part.add_theme_color_override("font_shadow_color", UiTheme.color("text", 0.12))
		part.add_theme_constant_override("shadow_offset_x", 0)
		part.add_theme_constant_override("shadow_offset_y", 4)
		part.add_theme_constant_override("shadow_outline_size", 3)
	hint_label.add_theme_color_override("font_color", UiTheme.color("text_muted"))


## En iyi level/mesafe/puan; rekor yoksa ilk koşuya davet eder.
func _refresh_record() -> void:
	var label: Label = %RecordLabel
	label.add_theme_color_override("font_color", UiTheme.color("text_muted"))
	var save: Node = get_node_or_null("/root/SaveService")
	var profile: ProfileData = null
	if save != null:
		profile = save.call("profile") as ProfileData
	if profile == null or profile.records().best_level() <= 0:
		label.text = UiStrings.RECORD_NONE
		return
	var records: RunRecords = profile.records()
	label.text = UiStrings.RECORD_FORMAT % [records.best_level(), records.best_distance(), records.best_score()]


func _refresh_wallet() -> void:
	gold_icon.texture = Icons.texture("lucide/coins")
	scrap_icon.texture = Icons.texture("lucide/cog")
	gold_icon.modulate = UiTheme.color("secondary")
	scrap_icon.modulate = UiTheme.color("text_muted")
	var profile: ProfileData = SaveService.profile()
	if profile == null:
		gold_label.text = "0"
		scrap_label.text = "0"
		return
	gold_label.text = str(profile.wallet().gold())
	scrap_label.text = str(profile.wallet().scrap())


func _refresh_sound_button() -> void:
	var on: bool = SaveService.setting("sound_on")
	Icons.apply(sound_button, "lucide/volume-2" if on else "lucide/volume-x",
		UiTheme.color("on_surface"), NAV_ICON_SIZE)
	sound_button.add_theme_constant_override("h_separation", 12)


func _on_sound_toggle() -> void:
	var on: bool = not SaveService.setting("sound_on")
	SaveService.set_setting("sound_on", on)
	AudioService.set_muted(not on)
	_refresh_sound_button()


func _setup_tutorial() -> void:
	_tutorial_title.text = UiStrings.TUTORIAL_TITLE
	_tutorial_next.text = UiStrings.TUTORIAL_NEXT
	_tutorial_skip.text = UiStrings.TUTORIAL_SKIP
	_tutorial_next.pressed.connect(_on_tutorial_next)
	_tutorial_skip.pressed.connect(_on_tutorial_skip)
	# Nokta göstergesi: Dots kapsayıcısının çocukları sayfa başına bir nokta.
	var dots_parent: Control = %TutorialDots
	_dots.clear()
	for child: Node in dots_parent.get_children():
		var dot: Control = child as Control
		if dot != null:
			_dots.append(dot)
	var done: bool = SaveService.setting("tutorial_done")
	_tutorial_panel.visible = not done
	if not done:
		_show_tutorial_page(0)


func _show_tutorial_page(index: int) -> void:
	var last: int = UiStrings.TUTORIAL_PAGES.size() - 1
	_tutorial_page = clampi(index, 0, last)
	_tutorial_text.text = UiStrings.TUTORIAL_PAGES[_tutorial_page]
	# Son sayfada "Devam" yerine başlatma niyeti; düğme yine aynı akışı kapatır.
	_tutorial_next.text = UiStrings.TUTORIAL_START if _tutorial_page == last \
		else UiStrings.TUTORIAL_NEXT
	var active: Color = UiTheme.color("primary")
	var idle: Color = UiTheme.color("text_muted", 0.30)
	for i: int in _dots.size():
		_dots[i].modulate = active if i == _tutorial_page else idle


func _on_tutorial_next() -> void:
	if _tutorial_page >= UiStrings.TUTORIAL_PAGES.size() - 1:
		_close_tutorial()
		return
	_show_tutorial_page(_tutorial_page + 1)


func _on_tutorial_skip() -> void:
	_close_tutorial()


func _close_tutorial() -> void:
	_tutorial_panel.visible = false
	SaveService.set_setting("tutorial_done", true)


func _on_play() -> void:
	GameManager.goto_scene(&"order")


func _on_garage() -> void:
	GameManager.goto_scene(&"garage")


func _on_settings() -> void:
	GameManager.goto_scene(&"settings")


func _on_back() -> void:
	get_tree().quit()
