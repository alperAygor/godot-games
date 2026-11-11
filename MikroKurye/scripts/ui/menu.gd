extends Control

## Ana menü: Oyna -> sipariş seçimi, Garaj -> yükseltmeler, Ayarlar -> ses.
## İlk açılışta üç sayfalık kısa rehber gösterilir (ARCHITECTURE.md §5.6).
## Geri tuşu: çıkış.

const PLAY_ICON_SIZE: int = 56
const GARAGE_ICON_SIZE: int = 48
const SETTINGS_ICON_SIZE: int = 44
const ON_PRIMARY: Color = Color(0.08, 0.24, 0.15)
const ON_SECONDARY: Color = Color(0.29, 0.20, 0.09)

@onready var play_button: Button = %PlayButton
@onready var garage_button: Button = %GarageButton
@onready var settings_button: Button = %SettingsButton
@onready var hint_label: Label = %Hint
@onready var _tutorial_panel: Control = %TutorialPanel
@onready var _tutorial_title: Label = %TutorialTitle
@onready var _tutorial_text: Label = %TutorialText
@onready var _tutorial_page_label: Label = %TutorialPage
@onready var _tutorial_next: Button = %TutorialNextButton
@onready var _tutorial_skip: Button = %TutorialSkipButton

var _tutorial_page: int = 0


func _ready() -> void:
	GameManager.set_phase(GameManager.Phase.MENU)
	play_button.text = UiStrings.MENU_PLAY
	garage_button.text = UiStrings.MENU_GARAGE
	settings_button.text = UiStrings.MENU_SETTINGS
	hint_label.text = UiStrings.MENU_HINT
	Icons.apply(play_button, "lucide/play", ON_PRIMARY, PLAY_ICON_SIZE)
	Icons.apply(garage_button, "lucide/truck", ON_SECONDARY, GARAGE_ICON_SIZE)
	Icons.apply(settings_button, "lucide/settings", ON_SECONDARY, SETTINGS_ICON_SIZE)
	play_button.pressed.connect(_on_play)
	garage_button.pressed.connect(_on_garage)
	settings_button.pressed.connect(_on_settings)
	GameManager.back_requested.connect(_on_back)
	_setup_tutorial()
	# Tıklama sesi tek yardımcıdan; yukarıdaki elle `play` çağrıları kaldırıldı.
	UiSfx.bind(self)


func _setup_tutorial() -> void:
	_tutorial_title.text = UiStrings.TUTORIAL_TITLE
	_tutorial_next.text = UiStrings.TUTORIAL_NEXT
	_tutorial_skip.text = UiStrings.TUTORIAL_SKIP
	_tutorial_next.pressed.connect(_on_tutorial_next)
	_tutorial_skip.pressed.connect(_on_tutorial_skip)
	var done: bool = SaveService.setting("tutorial_done")
	_tutorial_panel.visible = not done
	if not done:
		_show_tutorial_page(0)


func _show_tutorial_page(index: int) -> void:
	var last: int = UiStrings.TUTORIAL_PAGES.size() - 1
	_tutorial_page = clampi(index, 0, last)
	_tutorial_text.text = UiStrings.TUTORIAL_PAGES[_tutorial_page]
	_tutorial_page_label.text = "%d / %d" % [_tutorial_page + 1, last + 1]
	# Son sayfada "Devam" yerine başlatma niyeti; düğme yine aynı akışı kapatır.
	_tutorial_next.text = UiStrings.TUTORIAL_START if _tutorial_page == last \
		else UiStrings.TUTORIAL_NEXT


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
