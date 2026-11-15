extends TestCase

## Juice: tween'lerin gercekten donusturdugunu custom_step ile dogrular
## (sahne karesi beklemeden, deterministik).

var _control: Control = null
var _box: Node3D = null


func before_each() -> void:
	_control = Control.new()
	_control.size = Vector2(200, 100)
	add_node(_control)
	_box = Node3D.new()
	_box.position = Vector3(1, 2, 3)
	_box.scale = Vector3.ONE
	add_node(_box)


func after_each() -> void:
	if _control != null and _control.get_parent() != null:
		_control.free()
	_control = null
	if _box != null and _box.get_parent() != null:
		_box.free()
	_box = null


func test_pop_in_starts_small_and_ends_normal() -> void:
	var tween: Tween = Juice.pop_in(_control, 0.8, 0.28)
	assert_almost_eq(_control.scale.x, 0.8, 0.001, "baslangic olcegi kucuk olmali")
	assert_almost_eq(_control.modulate.a, 0.0, 0.001, "baslangicta seffaf")
	tween.custom_step(1.0)
	assert_almost_eq(_control.scale.x, 1.0, 0.01, "sonunda normal olcek")
	assert_almost_eq(_control.modulate.a, 1.0, 0.01, "sonunda gorunur")


func test_squash_returns_to_original_scale() -> void:
	var tween: Tween = Juice.squash(_box, 1.0)
	tween.custom_step(0.09)
	assert_true(_box.scale.y < 1.0, "ezilme fazinda Y kuculmeli")
	tween.custom_step(1.0)
	assert_true(_box.scale.is_equal_approx(Vector3.ONE), "sonunda eski olcege donmeli")


func test_shake_returns_to_rest_position() -> void:
	var tween: Tween = Juice.shake(_box, 0.02, 0.2)
	assert_true(_box.position.is_equal_approx(Vector3(1, 2, 3)))
	tween.custom_step(0.05)
	assert_false(_box.position.is_equal_approx(Vector3(1, 2, 3)), "titreme sirasinda kaymali")
	tween.custom_step(1.0)
	assert_true(_box.position.is_equal_approx(Vector3(1, 2, 3)), "sonunda geri donmeli")


func test_fade_reaches_target_alpha() -> void:
	var tween: Tween = Juice.fade(_control, 0.25, 0.1)
	tween.custom_step(0.5)
	assert_almost_eq(_control.modulate.a, 0.25, 0.01)
