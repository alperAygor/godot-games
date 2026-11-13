class_name RetentionSheet
extends Sheet

## Üç tutundurma sayfasının ortak tabanı: başlık, kilitli görünüm, "Tamam" düğmesi, kutlama.
## Sayfa kapanınca (closed) giriş satırı rozetleri Progress.changed ile zaten tazelenir.

const OK_HEIGHT: float = 126.0
const LOCK_ICON: String = "lucide/clock"

var _today: String = ""


## Boş sayfayı kurar (alt sınıf `open` içinde çağırır).
func _setup(parent: Node) -> void:
	_today = RetentionStore.today()
	build(parent, false)
	dismiss_on_dim = true


func _add_title(text: String) -> void:
	content().add_child(UiKit.label(text, RetentionUi.TITLE_SIZE))


func _add_gap(height: float) -> void:
	content().add_child(UiKit.spacer(height))


func _add_ok() -> void:
	var ok: Button = UiKit.button(UiStrings.ok(), &"SecondaryButton", "", OK_HEIGHT)
	ok.pressed.connect(close)
	content().add_child(ok)


## Seviye yetersizse tüm sayfa yerine bu görünüm kurulur.
func _fill_locked(title: String, unlock_level: int) -> void:
	var holder: CenterContainer = CenterContainer.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(RetentionUi.disc(LOCK_ICON, UiKit.ACCENT_SOFT, UiKit.ACCENT, 112.0, 52.0))
	content().add_child(holder)
	_add_gap(RetentionUi.GAP)
	_add_title(title)
	_add_gap(RetentionUi.GAP * 0.4)
	content().add_child(UiKit.label(RetentionStrings.locked(unlock_level), RetentionUi.BODY_SIZE, UiKit.TEXT_MUTED))
	_add_gap(RetentionUi.GAP * 1.6)
	_add_ok()
	play_intro()


## Bir düğmenin merkezinde kutlama (sayfanın yerel koordinatında).
func _celebrate_at(control: Control, reward: Dictionary) -> void:
	var center: Vector2 = control.global_position + control.size * 0.5 - global_position
	RetentionUi.celebrate(self, center, RetentionUi.reward_text(reward))
	AudioService.play_pitched("chest_open", 1.0, -4.0)
	AudioService.play_pitched("coin", 1.0, -6.0)
