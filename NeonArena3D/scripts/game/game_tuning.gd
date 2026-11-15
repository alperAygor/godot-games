extends RefCounted
class_name GameTuning
## `data/balance/combat.json` → tipli alanlar. Oynanış modülleri bu sayıları her karede okur: sözlük yolu
## (`GameData.number("a.b")`) her çağrıda dize böler, burada ise açılışta bir kez okunup alan olarak saklanır
## (kare başına ayırma yok). Alan adı = `<grup>_<anahtar>`; JSON'da her alan zorunludur (bkz. `validate`).

const SCHEMA := {
	"nova": ["wave_scale", "clear_radius_mult", "invuln", "boss_kill_gain", "milestone_gain", "elite_kill_mult",
		"doom_radius_mult", "doom_aftershocks", "doom_delay", "doom_delay_step", "doom_damage", "doom_min", "doom_max",
		"aftershock_radius"],
	"revive": ["hp_ratio", "invuln", "blast_radius", "blast_damage"],
	"run": ["base_rerolls", "card_invuln", "pickup_radius", "magnet_pull", "harvest_shield_at", "wave_clear_heal",
		"map_clear_heal", "hunt_after", "hunt_every"],
	"hits": ["knockback", "heavy_knockback", "area_knockback", "chain_range", "chain_damage", "storm_jumps",
		"storm_chain_damage", "dash_reach", "dash_hit_cd", "dash_knockback", "blitz_mult", "touch_cd",
		"thorns_knockback", "fortress_thorns_mult", "boss_charge_contact", "bomber_area_damage"],
	"explosive": ["radius", "radius_per_level", "damage", "damage_per_level"],
	"tank_split": ["count", "offset", "delay"],
	"fortress": ["bullets", "damage", "speed", "life", "size", "pierce"],
	"drones": ["orbit", "spin", "range", "boss_range", "cooldown", "hive_cooldown", "bullet_speed", "damage", "life", "size"],
	"weapons": ["scatter_pellets_per_extra", "scatter_arc_per_extra", "scatter_recoil", "rail_offset", "rail_recoil",
		"rocket_offset", "blaster_offset", "blaster_recoil_mult"],
	"enemy_bullets": ["damage", "life", "sniper_size"],
	"boss_attacks": ["lap_hp", "bullet_life", "bullet_size", "radial_speed", "radial_damage", "aimed_shots",
		"aimed_spread", "aimed_speed", "aimed_damage", "spiral_speed", "spiral_damage", "zone_damage", "zone_burst_speed",
		"zone_burst_damage", "ring_damage", "fan_damage", "leap_damage", "leap_burst", "blink_bullets", "blink_speed",
		"blink_damage"],
	"auto_aim": ["retarget", "keep_bias", "priority_bias", "blocked_penalty", "boss_range_mult", "boss_bias"],
}

var nova_wave_scale := 0.0
var nova_clear_radius_mult := 0.0
var nova_invuln := 0.0
var nova_boss_kill_gain := 0.0
var nova_milestone_gain := 0.0
var nova_elite_kill_mult := 0.0
var nova_doom_radius_mult := 0.0
var nova_doom_aftershocks := 0
var nova_doom_delay := 0.0
var nova_doom_delay_step := 0.0
var nova_doom_damage := 0.0
var nova_doom_min := 0.0
var nova_doom_max := 0.0
var nova_aftershock_radius := 0.0

var revive_hp_ratio := 0.0
var revive_invuln := 0.0
var revive_blast_radius := 0.0
var revive_blast_damage := 0.0

var run_base_rerolls := 0
var run_card_invuln := 0.0
var run_pickup_radius := 0.0
var run_magnet_pull := 0.0
var run_harvest_shield_at := 0.0
var run_wave_clear_heal := 0.0
var run_map_clear_heal := 0.0
var run_hunt_after := 0.0
var run_hunt_every := 0.0

var hits_knockback := 0.0
var hits_heavy_knockback := 0.0
var hits_area_knockback := 0.0
var hits_chain_range := 0.0
var hits_chain_damage := 0.0
var hits_storm_jumps := 0
var hits_storm_chain_damage := 0.0
var hits_dash_reach := 0.0
var hits_dash_hit_cd := 0.0
var hits_dash_knockback := 0.0
var hits_blitz_mult := 0.0
var hits_touch_cd := 0.0
var hits_thorns_knockback := 0.0
var hits_fortress_thorns_mult := 0.0
var hits_boss_charge_contact := 0.0
var hits_bomber_area_damage := 0.0

var explosive_radius := 0.0
var explosive_radius_per_level := 0.0
var explosive_damage := 0.0
var explosive_damage_per_level := 0.0

var tank_split_count := 0
var tank_split_offset := 0.0
var tank_split_delay := 0.0

var fortress_bullets := 0
var fortress_damage := 0.0
var fortress_speed := 0.0
var fortress_life := 0.0
var fortress_size := 0.0
var fortress_pierce := 0

var drones_orbit := 0.0
var drones_spin := 0.0
var drones_range := 0.0
var drones_boss_range := 0.0
var drones_cooldown := 0.0
var drones_hive_cooldown := 0.0
var drones_bullet_speed := 0.0
var drones_damage := 0.0
var drones_life := 0.0
var drones_size := 0.0

var weapons_scatter_pellets_per_extra := 0
var weapons_scatter_arc_per_extra := 0.0
var weapons_scatter_recoil := 0.0
var weapons_rail_offset := 0.0
var weapons_rail_recoil := 0.0
var weapons_rocket_offset := 0.0
var weapons_blaster_offset := 0.0
var weapons_blaster_recoil_mult := 0.0

var enemy_bullets_damage := 0.0
var enemy_bullets_life := 0.0
var enemy_bullets_sniper_size := 0.0

var boss_attacks_lap_hp := 0.0
var boss_attacks_bullet_life := 0.0
var boss_attacks_bullet_size := 0.0
var boss_attacks_radial_speed := 0.0
var boss_attacks_radial_damage := 0.0
var boss_attacks_aimed_shots := 0
var boss_attacks_aimed_spread := 0.0
var boss_attacks_aimed_speed := 0.0
var boss_attacks_aimed_damage := 0.0
var boss_attacks_spiral_speed := 0.0
var boss_attacks_spiral_damage := 0.0
var boss_attacks_zone_damage := 0.0
var boss_attacks_zone_burst_speed := 0.0
var boss_attacks_zone_burst_damage := 0.0
var boss_attacks_ring_damage := 0.0
var boss_attacks_fan_damage := 0.0
var boss_attacks_leap_damage := 0.0
var boss_attacks_leap_burst := 0
var boss_attacks_blink_bullets := 0
var boss_attacks_blink_speed := 0.0
var boss_attacks_blink_damage := 0.0

var auto_aim_retarget := 0.0
var auto_aim_keep_bias := 0.0
var auto_aim_priority_bias := 0.0
var auto_aim_blocked_penalty := 0.0
var auto_aim_boss_range_mult := 0.0
var auto_aim_boss_bias := 0.0

## `player` bölümünden önbelleğe alınan, her karede kullanılan değerler.
var nova_max := 100.0
var player_damage := 12.0
var player_bullet_speed := 980.0
var player_auto_aim_range := 760.0
var player_nova_per_kill := 4.5
var player_knockback := 90.0
var player_shield_regen_time := 18.0

static func from_balance(balance: Dictionary) -> GameTuning:
	## Doğrulanmış bir denge sözlüğünden (BalanceData) kurar. Eksik alan sıfır kalır: doğrulama hatası zaten basılmıştır.
	var t := GameTuning.new()
	var combat: Dictionary = balance.get("combat", {})
	for group in SCHEMA:
		var section: Dictionary = combat.get(group, {}) if typeof(combat.get(group, {})) == TYPE_DICTIONARY else {}
		for key in SCHEMA[group]:
			if section.has(key) and BalanceData._is_num(section[key]):
				var prop: String = "%s_%s" % [group, key]
				t.set(prop, int(section[key]) if typeof(t.get(prop)) == TYPE_INT else float(section[key]))
	var player: Dictionary = balance.get("player", {})
	t.nova_max = float(player.get("nova_cost", 100.0))
	t.player_damage = float(player.get("damage", 12.0))
	t.player_bullet_speed = float(player.get("bullet_speed", 980.0))
	t.player_auto_aim_range = float(player.get("auto_aim_range", 760.0))
	t.player_nova_per_kill = float(player.get("nova_per_kill", 4.5))
	t.player_knockback = float(player.get("knockback", 90.0))
	t.player_shield_regen_time = float(player.get("shield_regen_time", 18.0))
	return t

static func validate(combat: Variant) -> PackedStringArray:
	var errors := PackedStringArray()
	if typeof(combat) != TYPE_DICTIONARY:
		errors.append("combat bölümü sözlük değil")
		return errors
	var probe := GameTuning.new()
	for group in combat:
		if not SCHEMA.has(group) and not str(group).begins_with("_"):
			errors.append("combat.%s bilinmeyen grup (yazım hatası?)" % group)
	for group in SCHEMA:
		var section: Variant = (combat as Dictionary).get(group)
		if typeof(section) != TYPE_DICTIONARY:
			errors.append("combat.%s eksik ya da sözlük değil" % group)
			continue
		for key in SCHEMA[group]:
			var v: Variant = (section as Dictionary).get(key)
			if not BalanceData._is_num(v):
				errors.append("combat.%s.%s eksik ya da sayı değil" % [group, key])
			elif float(v) < 0.0:
				errors.append("combat.%s.%s negatif olamaz" % [group, key])
			elif typeof(probe.get("%s_%s" % [group, key])) == TYPE_INT and float(v) != floorf(float(v)):
				errors.append("combat.%s.%s tam sayı olmalı" % [group, key])
		for key in section:
			if not (key in SCHEMA[group]):
				errors.append("combat.%s.%s bilinmeyen alan (yazım hatası?)" % [group, key])
	return errors
