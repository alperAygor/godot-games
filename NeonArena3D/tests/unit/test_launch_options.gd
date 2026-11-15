extends TestCase
## Oyun bayrakları (LaunchOptions) + oyun olay yolu (GameEvents) + bağlam varsayılanları.

func _parse(args: Array) -> LaunchOptions:
	var o := LaunchOptions.new()
	o.parse(PackedStringArray(args))
	return o

func test_defaults_are_player_mode() -> void:
	var o := _parse([])
	check(not o.demo, "bayraksız: demo değil")
	eq(o.start_wave, 1, "başlangıç dalgası 1")
	eq(o.run_seed, 0, "tohum yok = rastgele")
	eq(o.debug_give, [], "kart verilmez")

func test_all_flags() -> void:
	var o := _parse(["--demo", "--wave=7", "--hp=40", "--die=3.5", "--cards", "--nova", "--map=2", "--give=zincir,kritik", "--boss=titan", "--ship=sahin", "--screen=settings", "--seed=42"])
	check(o.demo, "--demo")
	eq(o.start_wave, 7, "--wave")
	near(o.debug_hp, 40.0, 0.0, "--hp")
	near(o.debug_die, 3.5, 0.0, "--die")
	check(o.show_cards_demo and o.debug_nova, "--cards, --nova")
	eq(o.debug_map, 2, "--map")
	eq(o.debug_give, ["zincir", "kritik"], "--give virgüllü liste")
	eq(o.debug_boss, "titan", "--boss")
	eq(o.debug_ship, "sahin", "--ship")
	eq(o.debug_screen, "settings", "--screen")
	eq(o.run_seed, 42, "--seed")

func test_clamps() -> void:
	var o := _parse(["--wave=0", "--map=-3"])
	eq(o.start_wave, 1, "dalga en az 1")
	eq(o.debug_map, 0, "harita negatif olamaz")

func test_unknown_flags_ignored() -> void:
	var o := _parse(["--no-save", "--quality=1", "--lang=en", "--seconds=20"])
	check(not o.demo and o.run_seed == 0, "başka araçların bayrakları yok sayılır")

func test_events_declare_seams() -> void:
	var ev := GameEvents.new()
	for sig in ["run_started", "enemy_killed", "player_hurt", "player_died", "player_revived", "boss_spawned", "boss_killed", "cards_shown", "card_picked", "reward_computed", "run_ended"]:
		check(ev.has_signal(sig), "GameEvents sinyali var: " + sig)

func test_context_defaults() -> void:
	var c := GameContext.new()
	eq(c.state, "menu", "bağlam menüde başlar")
	check(c.events != null and c.options != null, "olay yolu ve bayraklar hazır")
	eq(c.ARENA, Rect2(40.0, 40.0, 2560.0, 1600.0), "arena boyutu değişmedi")
