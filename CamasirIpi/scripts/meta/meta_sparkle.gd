class_name MetaSparkle
extends Node2D

## Yumuşak "yenilendi" parıltısı: kısa bir ışık halesi + yukarı süzülen birkaç ışık noktası.
## Sayı ve süre `Motion.SPARKLE_*` ile aynı ölçekte (oyunun parçacık dili tek kalsın);
## sert yıldız/konfeti yok — sakin, ASMR hissi. İş bitince kendini siler.

const HALO_COLOR: Color = Color(1.0, 0.96, 0.85, 0.55)
const DOT_COLOR: Color = Color(1.0, 0.95, 0.8, 0.95)
const HALO_GROW: float = 1.35
const DOT_RADIUS_MIN: float = 7.0
const DOT_RADIUS_MAX: float = 15.0
## Noktalar yayılımın bu oranı kadar yukarı da süzülür (ışık "yükselir").
const DOT_RISE: float = 0.55
const DOT_DELAY_MAX: float = 0.18

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


## `at`: parıltı merkezi (parent koordinatı), `spread`: eşyanın yaklaşık yarıçapı (px).
static func burst(parent: Node, at: Vector2, spread: float, count: int = Motion.SPARKLE_COUNT) -> MetaSparkle:
	var node: MetaSparkle = MetaSparkle.new()
	node.position = at
	parent.add_child(node)
	node._play(spread, count)
	return node


func _play(spread: float, count: int) -> void:
	_rng.randomize()
	var lifetime: float = Motion.SPARKLE_LIFETIME
	var halo: Sprite2D = GlowTextures.make_sprite(GlowTextures.halo(), spread, true)
	halo.modulate = HALO_COLOR
	add_child(halo)
	var halo_tween: Tween = create_tween().set_parallel(true)
	halo_tween.tween_property(halo, "scale", halo.scale * HALO_GROW, lifetime * 0.8)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	halo_tween.tween_property(halo, "modulate:a", 0.0, lifetime * 0.8)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	for _index: int in range(count):
		var dot: Sprite2D = GlowTextures.make_sprite(GlowTextures.dot(),
			_rng.randf_range(DOT_RADIUS_MIN, DOT_RADIUS_MAX), true)
		var angle: float = _rng.randf() * TAU
		var start: Vector2 = Vector2(cos(angle), sin(angle)) * spread * _rng.randf_range(0.1, 0.5)
		var finish: Vector2 = start + Vector2(cos(angle), sin(angle)) * spread * _rng.randf_range(0.35, 0.8) \
			+ Vector2(0.0, -spread * DOT_RISE)
		dot.position = start
		dot.modulate = Color(DOT_COLOR, 0.0)
		add_child(dot)
		var delay: float = _rng.randf() * DOT_DELAY_MAX
		var move: Tween = create_tween()
		move.tween_property(dot, "position", finish, lifetime).set_delay(delay)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		var fade: Tween = create_tween()
		fade.tween_property(dot, "modulate:a", DOT_COLOR.a, lifetime * 0.25).set_delay(delay)
		fade.tween_property(dot, "modulate:a", 0.0, lifetime * 0.75)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	get_tree().create_timer(lifetime + DOT_DELAY_MAX + 0.1).timeout.connect(queue_free)
