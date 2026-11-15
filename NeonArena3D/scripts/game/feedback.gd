extends GameModule
class_name Feedback
## Juice kancaları: dünya parıltıları + vinyet (hasar/düşük can/renk tonu), hasar sayıları, kalp atışı,
## salt-görsel olay tepkileri (atılma, kalkan kırılması, hasar). Oynanış kararı vermez (C5 buradan genişletir).
## Not: savaş kodunun içine gömülü kıvılcım/sarsıntı çağrıları sıra (rastgele akış) korunsun diye yerinde kaldı.

var vignette_rect: ColorRect
var vignette_mat: ShaderMaterial
var hurt_fx := 0.0
var tint_fx := 0.0
var _heartbeat := 0.0

func build(layer_parent: Node) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 8
	layer_parent.add_child(layer)
	vignette_rect = ColorRect.new()
	vignette_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vignette_mat = ShaderMaterial.new()
	vignette_mat.shader = load("res://assets/shaders/vignette.gdshader")
	vignette_rect.material = vignette_mat
	layer.add_child(vignette_rect)

func reset_run() -> void:
	hurt_fx = 0.0
	tint_fx = 0.0

func tint(color: Color, amount: float) -> void:
	## Ekran renk tonu (toplama, nova): en az `amount` kadar.
	tint_fx = maxf(tint_fx, amount)
	vignette_mat.set_shader_parameter("tint_color", color)

func render_frame(delta: float) -> void:
	## Dünya efektleri: zemin, ışık diskleri, mermiler, kıvılcımlar, vinyet.
	var player := ctx.player
	var sparks := ctx.sparks
	if ctx.world != null and is_instance_valid(ctx.world):
		ctx.world.tick(delta, player.position)
	sparks.glow_begin()
	if player.visible:
		var menu_mode := ctx.state == "menu"
		sparks.glow_add(player.position.x, player.position.z, 1.7 if menu_mode else 2.6, Color(player.ship_color.r, player.ship_color.g, player.ship_color.b, 0.16 if menu_mode else 0.28))
	for e in ctx.enemies:
		if is_instance_valid(e) and not e.dead:
			var c: Color = e.color()
			sparks.glow_add(e.position.x, e.position.z, e.radius / ArenaSpace.SCALE * 2.8, Color(c.r, c.g, c.b, 0.22 if not e.is_spawning() else 0.12))
	var boss := ctx.boss
	if boss != null and is_instance_valid(boss):
		var bc: Color = boss.color()
		sparks.glow_add(boss.position.x, boss.position.z, 6.5, Color(bc.r, bc.g, bc.b, 0.4))
	for p in ctx.pickups:
		if is_instance_valid(p):
			var pc: Color = p.color()
			sparks.glow_add(p.position.x, p.position.z, 1.5, Color(pc.r, pc.g, pc.b, 0.4))
	for o in ctx.obstacles:
		var ow: Vector3 = o["world"]
		var oc: Color = o["color"]
		sparks.glow_add(ow.x, ow.z, float(o["radius"]) / ArenaSpace.SCALE * 2.3, Color(oc.r, oc.g, oc.b, 0.13))
	ctx.field.render(sparks, ctx.elapsed)
	sparks.tick(delta)
	hurt_fx = maxf(0.0, hurt_fx - delta * 1.8)
	tint_fx = maxf(0.0, tint_fx - delta * 2.2)
	var low := 0.0
	if ctx.state == "playing" and player.alive and player.hp / maxf(1.0, player.max_hp) < 0.3:
		low = 1.0
	vignette_mat.set_shader_parameter("hurt", hurt_fx)
	vignette_mat.set_shader_parameter("low_hp", low)
	vignette_mat.set_shader_parameter("tint", tint_fx)

func tick_low_hp(delta: float) -> void:
	## Can %30'un altındayken kalp atışı sesi.
	var player := ctx.player
	var ratio: float = player.hp / maxf(1.0, player.max_hp)
	if player.alive and ratio < 0.3:
		_heartbeat -= delta
		if _heartbeat <= 0.0:
			_heartbeat = 0.95
			Sound.play("low_hp")

func damage_number(at: Vector3, amount: float, crit: bool) -> void:
	ctx.hud.float_text(at, str(int(round(amount))), KIT.GOLD if crit else Color(0.92, 0.97, 1.0), 26 if crit else 17, 0.75 if crit else 0.55)

func on_player_dash(at: Vector2, direction: Vector2) -> void:
	Sound.play("dash")
	var world_at := ArenaSpace.to_world(at, 1.0)
	ctx.sparks.spray(world_at, -ArenaSpace.dir_to_world(direction), Color(0.6, 1.0, 1.0), 16, 12.0, 0.4, 1.1, 0.5)
	ctx.sparks.ring(world_at, Color(0.5, 1.0, 1.0), 0.4, 2.6, 0.3, 0.2)
	Fx.punch(direction, 4.0)
	Fx.vibrate(12)

func player_hurt_fx(amount: float) -> void:
	var player := ctx.player
	ctx.hud.flash_damage()
	ctx.hud.float_text(player.position, "-%d" % int(round(amount)), KIT.RED, 22, 0.8)
	hurt_fx = 1.0
	Fx.shake(12.0)
	Fx.hitstop(0.06, 0.15)
	Fx.vibrate(45)
	ctx.sparks.burst(player.position, Color(1.0, 0.4, 0.5), 20, 8.0, 0.6, 1.2)
	ctx.sparks.flash(player.position, Color(1.0, 0.25, 0.35), 6.0, 9.0, 0.25)

func on_shield_broken() -> void:
	var player := ctx.player
	Sound.play("shield_break")
	ctx.sparks.burst(player.position, Color(0.55, 0.8, 1.0), 26, 10.0, 0.5, 1.2)
	ctx.sparks.ring(player.position, Color(0.55, 0.8, 1.0), 1.0, 4.5, 0.4, 0.14)
	ctx.hud.toast(tr("KALKAN KIRILDI"), Color(0.55, 0.8, 1.0), 1.0)
	ctx.control.shield_timer = 0.0
	Fx.shake(7.0)
	Fx.vibrate(30)
