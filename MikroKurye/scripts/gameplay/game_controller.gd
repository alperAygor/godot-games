class_name GameController
extends Node3D

## Oyun akışının sahne sahibi: kargo sağlığı, batarya, kontrol noktaları, düşme
## cezası ve teslimatı `scripts/core/` sınıflarına bağlar. Sözleşme: ARCHITECTURE.md §5.2.
##
## Fizik yalnızca ölçüm üretir (kargo sinyalleri, hız, konum); hasar/ödül kararı
## core sınıflarındadır. `-s` probunda autoload kimliği derlenmediği için
## GameManager/GameData'ya yalnızca `/root/...` yoluyla erişilir (GOTCHAS #2).

signal finished(result: Dictionary)
## Kargo kırıldı ama reklamla kurtarma teklif edilebiliyor; tur HENÜZ bitmedi.
signal revive_offered()

const DEFAULT_CARGO_ID: String = "pencil_battery"
const DEFAULT_LEVEL_ID: String = "desk_01"
const LEVEL_PATH_TEMPLATE: String = "res://scenes/levels/%s.tscn"

## `balance.json` okunamazsa kullanılan makul varsayılanlar (ARCHITECTURE §5.2).
const DEFAULT_KILL_Y: float = -5.0
const DEFAULT_RESPAWN_DROP_HEIGHT: float = 1.0
const DEFAULT_CHECKPOINT_RADIUS: float = 2.0
const DEFAULT_BATTERY_CAPACITY: float = 100.0
const DEFAULT_RECHARGE_THRESHOLD: float = 0.15
const DEFAULT_RECHARGE_BOOST_SECONDS: float = 10.0
const DEFAULT_HEAVY_IMPULSE: float = 8.0
const DEFAULT_LIGHT_IMPULSE: float = 2.0

## §5.4 yükseltme anahtarları; `SaveService.mods()` toplamları bu adlarla gelir.
const MOD_CARGO_DAMPING: String = "cargo_damping_bonus"
const MOD_WHEEL_GRIP: String = "wheel_grip_bonus"
const MOD_BATTERY_CAPACITY: String = "battery_capacity_bonus"
const MOD_JELLY_CHARGES: String = "jelly_charges"
const MOD_KEYS: Array[String] = [MOD_CARGO_DAMPING, MOD_WHEEL_GRIP,
	MOD_BATTERY_CAPACITY, MOD_JELLY_CHARGES]

const PERCENT_SCALE: float = 100.0

## Sonsuz mod (PROJECT_SPEC §14).
const ENDLESS_LEVEL_ID: String = "endless_desk"
## Batarya bu süre boyunca boş kalırsa koşu biter (kasa tam ödenir).
const EMPTY_BATTERY_GRACE_SECONDS: float = 3.0
## Teslimat çizgisine bu kadar yakın olmayan bildirimler (ikinci gövde) yok sayılır.
const PAD_TOLERANCE: float = 6.0
const REASON_BATTERY: String = "battery"
const REASON_QUIT: String = "quit"

@onready var _robot: RobotController = $Robot as RobotController
@onready var _cargo: CargoBasket = $Robot/CargoBasket as CargoBasket
@onready var _hud: Hud = $HUD as Hud

var _level: LevelRoot = null
var _endless: EndlessLevel = null
var _level_number: int = 1
var _banked_gold: int = 0
var _banked_scrap: int = 0
var _levels_delivered: int = 0
var _start_z: float = 0.0
var _max_distance: float = 0.0
var _empty_battery_seconds: float = 0.0
var _level_id: String = DEFAULT_LEVEL_ID
var _robot_start: Marker3D = null
var _delivery_zone: Area3D = null
var _cargo_id: String = DEFAULT_CARGO_ID
var _profile: Dictionary = {}
var _battery_params: Dictionary = {}
var _battery_capacity: float = DEFAULT_BATTERY_CAPACITY
## Uygulanan yükseltme toplamları; `state()["mods"]` bunları raporlar.
var _mods: Dictionary[String, float] = {}
var _kill_y: float = DEFAULT_KILL_Y
var _respawn_drop_height: float = DEFAULT_RESPAWN_DROP_HEIGHT
var _checkpoint_radius_sq: float = DEFAULT_CHECKPOINT_RADIUS * DEFAULT_CHECKPOINT_RADIUS
var _recharge_threshold: float = DEFAULT_RECHARGE_THRESHOLD
var _recharge_boost_seconds: float = DEFAULT_RECHARGE_BOOST_SECONDS
var _heavy_impulse: float = DEFAULT_HEAVY_IMPULSE
var _light_impulse: float = DEFAULT_LIGHT_IMPULSE

## Reklam akışı AdManager üzerinden yürür; burada yalnız niyet ve sonuç tutulur.
var _ad_manager: Node = null
var _revive_offered: bool = false
var _revive_used: bool = false
var _revive_pending: bool = false
var _recharge_used: bool = false
var _recharge_pending: bool = false
var _recharge_available: bool = false
var _golden_box: Area3D = null
var _golden_box_collected: bool = false

var _health: CargoHealth = null
var _battery: BatteryModel = null
var _tracker: CheckpointTracker = null
var _checkpoints: Dictionary[int, Marker3D] = {}
var _checkpoint_ids: Array[int] = []

var _respawns: int = 0
var _elapsed: float = 0.0
var _delivered: bool = false
var _broken: bool = false
var _finished: bool = false


func _ready() -> void:
	add_to_group("game_controller")
	_connect_ad_manager()
	_reset_ad_limits()
	_load_profile()
	_load_balance()
	_load_mods()
	_build_models()
	_apply_mods()
	# Deneme modları yukarıda `_mods` içine alındı; etkisi bir koşulluktur.
	_clear_trial()
	var manager: Node = get_node_or_null("/root/GameManager")
	if manager != null:
		manager.connect("back_requested", _on_back_requested)
	if not _load_level():
		# Eksik varsayılan seviyede gövdeler boşluğa düşüp tur üretmesin.
		_robot.freeze = true
		_cargo.freeze = true
		set_physics_process(false)
		_refresh_hud()
		return
	_setup_checkpoints()
	_connect_signals()
	_setup_golden_box()
	_setup_endless()
	_place_robot(_robot_start.global_transform)
	_refresh_hud()


func _load_level() -> bool:
	var selected: String = DEFAULT_LEVEL_ID
	var manager: Node = get_node_or_null("/root/GameManager")
	if manager != null:
		var raw: Variant = manager.get("selected_level_id")
		# Kimlik bir dosya adı olmalı; seçim res:// dışına yol oluşturamaz.
		if raw is String and (raw as String).is_valid_identifier():
			selected = raw as String
	if not _instantiate_level(selected):
		if selected == DEFAULT_LEVEL_ID or not _instantiate_level(DEFAULT_LEVEL_ID):
			push_warning("GameController: varsayılan seviye yüklenemedi; oyun durduruldu.")
			return false
	if manager != null:
		manager.set("selected_level_id", _level_id)
	return true


func _instantiate_level(id: String) -> bool:
	var path: String = LEVEL_PATH_TEMPLATE % id
	if not ResourceLoader.exists(path, "PackedScene"):
		push_warning("GameController: seviye bulunamadı: %s" % path)
		return false
	var packed: PackedScene = load(path) as PackedScene
	if packed == null:
		return false
	var instance: Node = packed.instantiate()
	var level: LevelRoot = instance as LevelRoot
	if level == null:
		push_warning("GameController: seviye kökü LevelRoot olmalı: %s" % path)
		instance.free()
		return false
	var start: Marker3D = level.find_child("RobotStart", true, false) as Marker3D
	var delivery: Area3D = level.find_child("DeliveryZone", true, false) as Area3D
	if start == null or delivery == null:
		push_warning("GameController: seviye başlangıcı/teslimat alanı eksik: %s" % path)
		level.free()
		return false
	_level = level
	_endless = level as EndlessLevel
	_level_id = level.level_id if not level.level_id.is_empty() else id
	_robot_start = start
	_delivery_zone = delivery
	_level.name = "Level"
	add_child(_level)
	return true


func _load_profile() -> void:
	var cargo_table: Dictionary = {}
	var data: Node = get_node_or_null("/root/GameData")
	if data != null:
		cargo_table = data.call("table", "cargo") as Dictionary
	var selected: String = DEFAULT_CARGO_ID
	var manager: Node = get_node_or_null("/root/GameManager")
	if manager != null:
		var raw: Variant = manager.get("selected_cargo_id")
		if raw is String and not (raw as String).is_empty():
			selected = raw as String
	var profile: Dictionary = cargo_table.get(selected, {}) as Dictionary
	# Tanımsız sipariş kimliği oyunu kilitlemesin: varsayılan profile düş.
	if profile.is_empty() and selected != DEFAULT_CARGO_ID:
		selected = DEFAULT_CARGO_ID
		profile = cargo_table.get(DEFAULT_CARGO_ID, {}) as Dictionary
	_cargo_id = selected
	_profile = profile


func _load_balance() -> void:
	var balance: Dictionary = {}
	var data: Node = get_node_or_null("/root/GameData")
	if data != null:
		balance = data.call("table", "balance") as Dictionary
	var game_params: Dictionary = balance.get("game", {}) as Dictionary
	var battery_params: Dictionary = balance.get("battery", {}) as Dictionary
	_kill_y = float(game_params.get("kill_y", DEFAULT_KILL_Y))
	_respawn_drop_height = float(game_params.get(
		"respawn_drop_height", DEFAULT_RESPAWN_DROP_HEIGHT))
	var radius: float = float(game_params.get("checkpoint_radius", DEFAULT_CHECKPOINT_RADIUS))
	_checkpoint_radius_sq = maxf(radius, 0.0) * maxf(radius, 0.0)
	_battery_capacity = float(battery_params.get("capacity", DEFAULT_BATTERY_CAPACITY))
	_battery_params = battery_params
	_recharge_threshold = clampf(float(game_params.get(
		"recharge_threshold", DEFAULT_RECHARGE_THRESHOLD)), 0.0, 1.0)
	_recharge_boost_seconds = maxf(float(game_params.get(
		"recharge_boost_seconds", DEFAULT_RECHARGE_BOOST_SECONDS)), 0.0)
	var audio_params: Dictionary = balance.get("audio", {}) as Dictionary
	_heavy_impulse = maxf(float(audio_params.get("heavy_impulse", DEFAULT_HEAVY_IMPULSE)), 0.0)
	_light_impulse = maxf(float(audio_params.get("light_impulse", DEFAULT_LIGHT_IMPULSE)), 0.0)


func _build_models() -> void:
	_health = CargoHealth.new(_profile, _jelly_charges())
	# Batarya kapasitesi yükseltmesi model kurulmadan önce eklenir; aksi hâlde
	# `set_battery_level` eski kapasiteyle oran hesaplar.
	_battery_capacity = maxf(_battery_capacity
		+ float(_mods.get(MOD_BATTERY_CAPACITY, 0.0)), 0.0)
	_battery = BatteryModel.new(_battery_capacity, _battery_params)
	_tracker = CheckpointTracker.new()


## `SaveService.mods()` toplamları; servis yoksa (izole probe/test) hepsi 0.
func _load_mods() -> void:
	_mods.clear()
	for key: String in MOD_KEYS:
		_mods[key] = 0.0
	var save: Node = get_node_or_null("/root/SaveService")
	if save == null or not save.has_method("mods"):
		return
	var raw: Variant = save.call("mods")
	if not raw is Dictionary:
		return
	var totals: Dictionary = raw as Dictionary
	for key: String in MOD_KEYS:
		var value: Variant = totals.get(key, 0.0)
		if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
			continue
		var number: float = float(value)
		if is_finite(number):
			_mods[key] = maxf(number, 0.0)


func _apply_mods() -> void:
	_cargo.set_damping_bonus(float(_mods.get(MOD_CARGO_DAMPING, 0.0)))
	_robot.set_wheel_grip_bonus(float(_mods.get(MOD_WHEEL_GRIP, 0.0)))


func _setup_checkpoints() -> void:
	_checkpoints.clear()
	_checkpoint_ids.clear()
	_checkpoints[0] = _robot_start
	# Yalnız yüklenen seviyeyi tara: Game'deki eski test marker'ları karışmasın.
	for node: Node in _level.find_children("Checkpoint_*", "Marker3D", true, false):
		var marker: Marker3D = node as Marker3D
		var suffix: String = String(marker.name).trim_prefix("Checkpoint_")
		if not suffix.is_valid_int():
			continue
		var id: int = suffix.to_int()
		if id <= 0 or _checkpoints.has(id):
			continue
		_checkpoints[id] = marker
		_checkpoint_ids.append(id)
	_checkpoint_ids.sort()
	_tracker.register(0, _robot_start.global_position)
	for id: int in _checkpoint_ids:
		_tracker.register(id, _checkpoints[id].global_position)
	_tracker.reach(0)


## Sonsuz mod: ara kontrol noktalarını kaydeder ve başlangıç mesafesini tutar.
func _setup_endless() -> void:
	_start_z = _robot_start.global_position.z
	if _endless == null:
		return
	for position_3d: Vector3 in _endless.checkpoint_positions():
		_register_dynamic_checkpoint(position_3d)
	_endless.checkpoint_added.connect(_register_dynamic_checkpoint)
	_hud.announce_objective()


func _register_dynamic_checkpoint(position_3d: Vector3) -> int:
	var id: int = 1
	if not _checkpoint_ids.is_empty():
		id = _checkpoint_ids[_checkpoint_ids.size() - 1] + 1
	var marker: Marker3D = Marker3D.new()
	marker.position = position_3d
	_level.add_child(marker)
	_checkpoints[id] = marker
	_checkpoint_ids.append(id)
	_tracker.register(id, position_3d)
	return id


func _connect_signals() -> void:
	_cargo.impact_reported.connect(_on_cargo_impact)
	_cargo.slosh_reported.connect(_on_cargo_slosh)
	_delivery_zone.body_entered.connect(_on_delivery_body_entered)
	_hud.revive_accepted.connect(accept_revive)
	_hud.revive_declined.connect(decline_revive)
	_hud.recharge_requested.connect(request_recharge)


## Seviyedeki Altın Kutu'yu grubundan/alt ağacından bulur; yoksa sessizce geçer
## (Faz 3 seviyeleri kutusuz da çalışır).
func _setup_golden_box() -> void:
	_golden_box = _level.find_child("GoldenBox", true, false) as Area3D
	if _golden_box == null:
		for node: Node in get_tree().get_nodes_in_group("golden_box"):
			var candidate: Area3D = node as Area3D
			if candidate != null and _level.is_ancestor_of(candidate):
				_golden_box = candidate
				break
	if _golden_box == null:
		return
	if not _golden_box.is_in_group("golden_box"):
		_golden_box.add_to_group("golden_box")
	if not _golden_box.body_entered.is_connected(_on_golden_box_body_entered):
		_golden_box.body_entered.connect(_on_golden_box_body_entered)


func _physics_process(delta: float) -> void:
	if _finished or _revive_offered or _recharge_pending:
		return
	_elapsed += delta
	if _robot.global_position.y < _kill_y:
		_respawn()
		return
	_reach_checkpoints()
	if _endless != null:
		_endless.update_world(_robot.global_position.z)
		_max_distance = maxf(_max_distance, _start_z - _robot.global_position.z)
	_battery.tick(delta)
	_battery.drain_for_speed(_robot.speed(), delta)
	_robot.set_speed_factor(_battery.speed_factor())
	_refresh_hud()
	if _endless != null and _check_battery_end(delta):
		return
	if _health.is_broken():
		_handle_broken()


## Sonsuz modda batarya uzun süre boşsa koşu biter (kasa tam ödenir).
func _check_battery_end(delta: float) -> bool:
	if not _battery.is_empty():
		_empty_battery_seconds = 0.0
		return false
	_empty_battery_seconds += delta
	if _empty_battery_seconds < EMPTY_BATTERY_GRACE_SECONDS:
		return false
	_finish_endless(REASON_BATTERY)
	return true


func _reach_checkpoints() -> void:
	# Sayısal sıra isim sırasından bağımsızdır; eksik numaralar id'leri kaydırmaz.
	for id: int in _checkpoint_ids:
		if id <= _tracker.last_id():
			continue
		var marker: Marker3D = _checkpoints[id]
		if _robot.global_position.distance_squared_to(marker.global_position) <= _checkpoint_radius_sq:
			_tracker.reach(id)
			return


func _respawn() -> void:
	_respawns += 1
	var target: Vector3 = _tracker.last_position()
	if _tracker.last_id() < 0:
		target = _robot_start.global_position
	_place_robot(Transform3D(_robot_start.global_basis, target))
	_health.apply_fall(_respawn_drop_height)
	_refresh_hud()
	if _health.is_broken():
		_handle_broken()


func _on_cargo_impact(impulse: float) -> void:
	if _finished:
		return
	_play_impact_sound(impulse)
	_health.apply_impact(impulse)
	_refresh_hud()
	if _health.is_broken():
		_handle_broken()


func _on_cargo_slosh(angular_accel: float, dt: float) -> void:
	if _finished:
		return
	_health.apply_slosh(angular_accel, dt)
	_refresh_hud()
	if _health.is_broken():
		_handle_broken()


func _on_delivery_body_entered(body: Node3D) -> void:
	if _finished or _health.is_broken() or _recharge_pending:
		return
	# Sepet robotun altında top-level bir gövde; teslimat iki gruptan biriyle sayılır.
	if not body.is_in_group("robot") and not body.is_in_group("cargo"):
		return
	if _endless != null:
		_complete_level()
		return
	_finish_run(true)


## Sonsuz mod: level teslimatı. Ödül kasaya yazılır, hasar kısmen onarılır, batarya
## kısmen dolar, koşu bir sonraki level'a devam eder.
func _complete_level() -> void:
	if absf(_robot.global_position.z - _endless.level_end_z()) > PAD_TOLERANCE:
		return
	var reward: Dictionary = EndlessReward.level_reward(_level_number, _health.damage(), _profile)
	_banked_gold += int(reward.get("gold", 0))
	_banked_scrap += int(reward.get("scrap", 0))
	_levels_delivered += 1
	_health.repair(LevelProgression.heal_fraction(_level_number))
	_battery.recharge(_battery_capacity * LevelProgression.battery_refill(_level_number))
	_robot.set_speed_factor(_battery.speed_factor())
	AudioService.play("delivery")
	var pad_checkpoint: int = _register_dynamic_checkpoint(
		Vector3(0.0, _robot_start.global_position.y, _endless.level_end_z()))
	_tracker.reach(pad_checkpoint)
	_level_number += 1
	_endless.advance()
	_hud.announce_level(_level_number, int(reward.get("gold", 0)))
	_refresh_hud()


## Sonsuz mod koşusu biter: kırılmada kasanın yarısı, diğer nedenlerde tamamı ödenir.
func _finish_endless(reason: String) -> void:
	if _finished:
		return
	var payout: Dictionary = EndlessReward.payout(_banked_gold, _banked_scrap, reason)
	var difficulty: int = int(_profile.get("difficulty", 1))
	var result: Dictionary = {
		"endless": true,
		"reason": reason,
		"success": reason != EndlessReward.REASON_BROKEN,
		"damage": _health.damage(),
		"stars": 0,
		"multiplier": EndlessReward.cargo_multiplier(difficulty),
		"gold": int(payout["gold"]),
		"scrap": int(payout["scrap"]),
		"fee": int(payout["gold"]),
		"payout_fraction": float(payout["fraction"]),
		"banked_gold": _banked_gold,
		"banked_scrap": _banked_scrap,
		"level": _level_number,
		"levels_delivered": _levels_delivered,
		"distance": _max_distance,
		"score": EndlessReward.score(_max_distance, difficulty),
		"cargo_id": _cargo_id,
		"level_id": _level_id,
		"time": _elapsed,
		"golden_box": false,
		"doubled": false,
	}
	_delivered = _levels_delivered > 0
	_broken = _health.is_broken()
	_finished = true
	_revive_offered = false
	_recharge_available = false
	_refresh_hud()
	finished.emit(result)
	var manager: Node = get_node_or_null("/root/GameManager")
	if manager != null:
		manager.call("finish_run", result)


## Kargo kırıldı: teklif edilebiliyorsa tur beklemede kalır, aksi hâlde biter.
## Teklif tur başına bir kezdir; `_revive_used` ikinci kırılmada anında bitirir.
func _handle_broken() -> void:
	if _finished or _revive_offered:
		return
	AudioService.play("break_sound")
	if not _revive_used and _can_offer(AdManager.Placement.CARGO_INSURANCE):
		_revive_offered = true
		_set_ad_wait(true)
		_refresh_hud()
		revive_offered.emit()
		return
	_finish_or_endless(false)


func accept_revive() -> void:
	if _finished or not _revive_offered or _revive_pending:
		return
	if _ad_manager == null:
		_close_revive(false)
		return
	_revive_pending = true
	_refresh_hud()
	_ad_manager.call("show_rewarded", AdManager.Placement.CARGO_INSURANCE)


func decline_revive() -> void:
	if _finished or not _revive_offered or _revive_pending:
		return
	_revive_offered = false
	_finish_or_endless(false)


func request_recharge() -> void:
	if _finished or _recharge_used or _recharge_pending or not _recharge_available:
		return
	if _ad_manager == null:
		return
	_recharge_pending = true
	_set_ad_wait(true)
	_refresh_hud()
	_ad_manager.call("show_rewarded", AdManager.Placement.BATTERY_RECHARGE)


func _on_golden_box_body_entered(body: Node3D) -> void:
	if _finished or _revive_offered or _recharge_pending or _golden_box_collected:
		return
	if not body.is_in_group("robot") and not body.is_in_group("cargo"):
		return
	_golden_box_collected = true
	_golden_box.hide()


func _on_back_requested() -> void:
	if _revive_pending or _recharge_pending:
		return
	if _endless != null and not _finished and _levels_delivered > 0:
		_finish_endless(REASON_QUIT)
		return
	var manager: Node = get_node_or_null("/root/GameManager")
	if manager != null:
		manager.call("goto_scene", &"menu")


func _connect_ad_manager() -> void:
	_ad_manager = get_node_or_null("/root/AdManager")
	if _ad_manager == null:
		return
	if not _ad_manager.is_connected("rewarded_finished", _on_ad_rewarded):
		_ad_manager.connect("rewarded_finished", _on_ad_rewarded)
	if not _ad_manager.is_connected("ad_failed", _on_ad_failed):
		_ad_manager.connect("ad_failed", _on_ad_failed)


func _reset_ad_limits() -> void:
	if _ad_manager != null and _ad_manager.has_method("reset_run_limits"):
		_ad_manager.call("reset_run_limits")


func _can_offer(placement: int) -> bool:
	if _ad_manager == null:
		return false
	return bool(_ad_manager.call("can_offer", placement))


func _on_ad_rewarded(placement: int, success: bool) -> void:
	if placement == AdManager.Placement.CARGO_INSURANCE and _revive_pending:
		_revive_pending = false
		_close_revive(success)
	elif placement == AdManager.Placement.BATTERY_RECHARGE and _recharge_pending:
		_recharge_pending = false
		_set_ad_wait(false)
		if success:
			_apply_recharge()
		else:
			# Başarısız reklam hakkı yakmaz; teklif yeniden hesaplanabilsin.
			_refresh_hud()


## Reklam sonucunu uygular: başarıda kargo sıfırlanır ve son kontrol noktasına
## dönülür. Reklam başarısızsa teklif kapanır ve tur kırık biter.
func _close_revive(success: bool) -> void:
	_revive_offered = false
	_revive_pending = false
	_set_ad_wait(false)
	if not success:
		_finish_or_endless(false)
		return
	_revive_used = true
	_broken = false
	AudioService.play("revive")
	# CargoHealth'te setter yok; temiz bir model aynı sözleşmeyi (hasar 0) verir.
	# Jel revive ile yeniden dolmaz: onu tüketen vuruş zaten kırılmaya yol açmıştı.
	_health = CargoHealth.new(_profile)
	var target: Vector3 = _tracker.last_position()
	if _tracker.last_id() < 0:
		target = _robot_start.global_position
	_place_robot(Transform3D(_robot_start.global_basis, target))
	_refresh_hud()


func _apply_recharge() -> void:
	_recharge_used = true
	AudioService.play("boost")
	set_battery_level(1.0)
	if _battery != null:
		_battery.start_boost(_recharge_boost_seconds)
	_refresh_hud()


func _on_ad_failed(placement: int, _reason: String) -> void:
	if placement == AdManager.Placement.CARGO_INSURANCE and _revive_pending:
		_revive_pending = false
		_revive_offered = false
		_finish_or_endless(false)
	elif placement == AdManager.Placement.BATTERY_RECHARGE and _recharge_pending:
		_recharge_pending = false
		_set_ad_wait(false)
		_refresh_hud()


## can_offer salt okur; hazır olma durumu başka reklam bitince değişebilir.
func _update_recharge_availability() -> void:
	_recharge_available = _battery != null and not _finished \
		and not _revive_offered and not _recharge_pending and not _recharge_used \
		and _battery.level() < _recharge_threshold \
		and _can_offer(AdManager.Placement.BATTERY_RECHARGE)


func _set_ad_wait(waiting: bool) -> void:
	# Teklif sırasında kontrol noktası, süre ve batarya korunur; dünya durumu
	# ağaç genelinde pause edilmez, dolayısıyla servis callback'leri devam eder.
	_robot.freeze = waiting
	_cargo.freeze = waiting


## `jelly_charges` JSON'dan float gelebilir (GOTCHAS #20); tamsayıya çevrilir.
func _jelly_charges() -> int:
	var raw: float = float(_mods.get(MOD_JELLY_CHARGES, 0.0))
	if not is_finite(raw):
		return 0
	return maxi(int(roundf(raw)), 0)


func _play_impact_sound(impulse: float) -> void:
	if impulse >= _heavy_impulse:
		AudioService.play("impact_heavy")
	elif impulse >= _light_impulse:
		AudioService.play("impact_light")


func _clear_trial() -> void:
	var save: Node = get_node_or_null("/root/SaveService")
	if save != null and save.has_method("clear_trial"):
		save.call("clear_trial")


func _place_robot(target: Transform3D) -> void:
	_robot.global_transform = target
	_robot.linear_velocity = Vector3.ZERO
	_robot.angular_velocity = Vector3.ZERO
	_robot.set_move_input(Vector2.ZERO)
	_cargo.reset_sway()


## Mevcut level'ın teslimat çizgisine kalan yatay mesafe (metre).
func _distance_to_pad() -> float:
	if _endless == null or _robot == null:
		return 0.0
	return absf(_robot.global_position.z - _endless.level_end_z())


func _refresh_hud() -> void:
	if _hud == null or _health == null or _battery == null:
		return
	_hud.set_cargo_health(_health.integrity() * PERCENT_SCALE)
	_hud.set_battery(_battery.level() * PERCENT_SCALE)
	if _endless != null:
		_hud.set_run_info(_level_number, _distance_to_pad(), _banked_gold)
	_update_recharge_availability()
	_hud.set_ad_pending(_revive_pending or _recharge_pending)
	_hud.set_revive_offered(_revive_offered)
	_hud.set_recharge_available(_recharge_available)


## Kırılma bitişi: sonsuz modda kasa yarı yarıya ödenir, klasik seviyede eski sonuç.
func _finish_or_endless(delivered: bool) -> void:
	if _endless != null:
		_finish_endless(EndlessReward.REASON_BROKEN)
	else:
		_finish_run(delivered)


func _finish_run(delivered: bool) -> void:
	if _finished:
		return
	# DeliveryReward kırıkta da aynı sözleşmeyi verir: success=false, gold/scrap=0.
	var result: Dictionary = DeliveryReward.compute(_health.damage(), _profile)
	result["fee"] = int(result.get("gold", 0))
	result["cargo_id"] = _cargo_id
	result["level_id"] = _level_id
	result["time"] = _elapsed
	# Altın kutu yalnız başarılı teslimatta ödüle dönüşür (§5.5).
	result["golden_box"] = delivered and bool(result.get("success", false)) \
		and _golden_box_collected
	result["doubled"] = false
	_delivered = delivered
	if delivered and bool(result.get("success", false)):
		AudioService.play("delivery")
	_broken = _health.is_broken()
	_finished = true
	_revive_offered = false
	_recharge_available = false
	_refresh_hud()
	finished.emit(result)
	var manager: Node = get_node_or_null("/root/GameManager")
	if manager != null:
		manager.call("finish_run", result)


## Bataryayı hedef doluluğa getirir (0..1 kırpılır). Reklamlı hızlı şarj ve test
## içindir: HUD ile robotun hız faktörü aynı karede yeni seviyeyi gösterir.
## BatteryModel'de seviye setter'ı yok; doluya çekip fazlasını boşaltmak
## `refill_full()` + `drain()` sözleşmesini kullanır (core'a dokunmadan).
func set_battery_level(level: float) -> void:
	if _battery == null:
		return
	# NaN tüm karşılaştırmalardan sessizce geçer ve clampf onu kırpmaz; bu yüzden
	# açıkça 0'a düşürülür. Negatif değerleri clampf zaten 0'a çeker.
	var target: float = 0.0 if is_nan(level) else clampf(level, 0.0, 1.0)
	_battery.refill_full()
	_battery.drain(_battery_capacity * (1.0 - target))
	if _robot != null:
		_robot.set_speed_factor(_battery.speed_factor())
	_refresh_hud()


func state() -> Dictionary:
	return {
		"cargo_id": _cargo_id,
		"level_id": _level_id,
		"damage": _health.damage(),
		"integrity": _health.integrity(),
		"battery": _battery.level(),
		"checkpoint_id": _tracker.last_id(),
		"respawns": _respawns,
		"delivered": _delivered,
		"broken": _health.is_broken(),
		"finished": _finished,
		"elapsed": _elapsed,
		"mods": _mods.duplicate(),
		"jelly_left": _health.jelly_left(),
		"revive_offered": _revive_offered,
		"revive_used": _revive_used,
		"recharge_available": _recharge_available,
		"boost_active": _battery != null and _battery.boost_active(),
		"golden_box_collected": _golden_box_collected,
		"endless": _endless != null,
		"level_number": _level_number,
		"levels_delivered": _levels_delivered,
		"banked_gold": _banked_gold,
		"banked_scrap": _banked_scrap,
		"distance": _max_distance,
	}


func restart() -> void:
	_reset_ad_limits()
	if _level == null:
		return
	_load_balance()
	_load_mods()
	_battery_capacity = maxf(_battery_capacity + float(_mods.get(MOD_BATTERY_CAPACITY, 0.0)), 0.0)
	_apply_mods()
	_clear_trial()
	_health = CargoHealth.new(_profile, _jelly_charges())
	_battery = BatteryModel.new(_battery_capacity, _battery_params)
	_tracker.reset()
	_tracker.reach(0)
	_respawns = 0
	_elapsed = 0.0
	_delivered = false
	_broken = false
	_finished = false
	_revive_offered = false
	_revive_used = false
	_revive_pending = false
	_recharge_used = false
	_recharge_pending = false
	_recharge_available = false
	_golden_box_collected = false
	if _golden_box != null:
		_golden_box.show()
	_set_ad_wait(false)
	_place_robot(_robot_start.global_transform)
	_robot.set_speed_factor(_battery.speed_factor())
	_refresh_hud()
