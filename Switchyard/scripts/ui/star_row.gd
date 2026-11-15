class_name UiStarRow
extends HBoxContainer

## Üç yıldızlık sıra (seviye sonucu). Kazanılan yıldız altın, kalan sönük; `pop_in` yıldızları
## sırayla büyütür. Yıldız dolgulu özel ikondur (`shell/star-fill`): çizgili ikon sönük/dolu farkını vermezdi.

const ICON_NAME: String = "shell/star-fill"
const OFF_COLOR: Color = Color(0.0, 0.0, 0.0, 0.08)
const POP_STEP_SECONDS: float = 0.16
const POP_FROM: float = 0.2

var _stars: Array[TextureRect] = []
var _earned: int = 0


func setup(earned: int, pixels: float, gap: int) -> void:
	_earned = clampi(earned, 0, LevelProgress.MAX_STARS)
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", gap)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for index: int in LevelProgress.MAX_STARS:
		var star: TextureRect = UiKit.tinted_icon(ICON_NAME, pixels,
			UiKit.STAR if index < _earned else OFF_COLOR)
		star.pivot_offset = Vector2(pixels, pixels) * 0.5
		add_child(star)
		_stars.append(star)


func earned() -> int:
	return _earned


## Kazanılan yıldızlar sırayla yerine oturur; her biri için `on_step` (ses) çağrılır.
func pop_in(on_step: Callable = Callable()) -> void:
	var tween: Tween = create_tween()
	for index: int in _stars.size():
		var star: TextureRect = _stars[index]
		if index >= _earned:
			continue
		star.scale = Vector2.ONE * POP_FROM
		star.modulate.a = 0.0
		tween.tween_interval(POP_STEP_SECONDS)
		if on_step.is_valid():
			tween.tween_callback(on_step.bind(index))
		tween.tween_property(star, "modulate:a", 1.0, 0.05)
		tween.parallel().tween_property(star, "scale", Vector2.ONE * UiTokens.MOTION_POP_SCALE, 0.16)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_property(star, "scale", Vector2.ONE, UiTokens.MOTION_RELEASE_SECONDS)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
