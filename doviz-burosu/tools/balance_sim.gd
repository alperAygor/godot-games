extends SceneTree
## Denge simülasyonu: bir bot kariyer boyunca oynar, günlük gelir/gider tablosunu yazar.
## Kullanım: godot --headless --path . -s res://tools/balance_sim.gd -- [--days=15] [--bot=perfect|careless|cheater|ally|escaper|helper] [--seed=1] [--quiet] [--story]
## Denge sayıları data/balance.json ve data/household.json içindedir; burada sadece ölçülür.


func _init() -> void:
	var days := 15
	var bot_name := "perfect"
	var seed_key := "1"
	var quiet := false
	var story := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--days="):
			days = int(arg.trim_prefix("--days="))
		elif arg.begins_with("--bot="):
			bot_name = arg.trim_prefix("--bot=")
		elif arg.begins_with("--seed="):
			seed_key = arg.trim_prefix("--seed=")
		elif arg == "--quiet":
			quiet = true
		elif arg == "--story":
			story = true
	if not ClerkBot.PROFILES.has(bot_name):
		printerr("Bilinmeyen bot: %s (perfect, careless, cheater)" % bot_name)
		quit(2)
		return
	var career := Career.load_default("sim-%s" % seed_key)
	career.story_enabled = story
	var bot := ClerkBot.new(bot_name, seed_key)
	var reports := bot.play_career(career, days)
	if not quiet:
		print("Bot: %s  tohum: %s  gün: %d" % [bot_name, seed_key, days])
		print("gün | müşt. doğru hata ceza | maaş+prim+kesinti | gider ödenen/ödenmeyen |    nakit  ruh | durum")
		for report: Dictionary in reports:
			var s: Dictionary = report["shift"]
			var h: Dictionary = report["household"]
			print("%3d | %5d %5d %4d %4s | %6s %5s %5s | %-22s | %8s %4d | %s" % [
				report["day"], s["served"], s["correct"], s["mistake_transactions"], Money.format(s["fines_minor"]),
				Money.format(s["base_minor"]), Money.format(s["bonus_minor"]), Money.format(s["skim_minor"]),
				"%s / %s" % [",".join(h["paid"]), ",".join(h["unpaid"])], Money.format(h["cash_after"]),
				h["mood_after"], report["over"]])
	var last: Dictionary = reports[-1]
	var lowest := 1 << 60
	var fines := 0
	var mistakes := 0
	var unpaid := 0
	for report: Dictionary in reports:
		lowest = mini(lowest, int(report["household"]["cash_after"]))
		fines += int(report["shift"]["fines_minor"])
		mistakes += int(report["shift"]["mistake_transactions"])
		unpaid += (report["household"]["unpaid"] as Array).size()
	var ending := Endings.resolve(career)
	print("SONUÇ bot=%s gün=%d bitti=%s nakit=%s en_düşük=%s hata=%d ceza=%s ödenmeyen=%d ruh=%d fed=%s son=%s" % [bot_name, int(last["day"]),
		career.game_over if career.is_over() else "-", Money.format(career.household.cash_minor, "PL"), Money.format(lowest, "PL"),
		mistakes, Money.format(fines, "PL"), unpaid, career.household.mood, Money.format(int(career.household.savings.get("FED", 0)), "FED"),
		ending.get("id", "-") if career.day > 15 or career.is_over() else "(%d. gün)" % career.day])
	quit(0)

