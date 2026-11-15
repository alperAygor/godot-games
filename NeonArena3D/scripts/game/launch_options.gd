extends RefCounted
class_name LaunchOptions
## Oyun bayrakları (`--` sonrası komut satırı argümanları; araçlar ve hata ayıklama için). Saf, testli.
##   --demo  --wave=N  --hp=X  --die=T  --cards  --nova  --map=N  --give=a,b  --boss=tür  --ship=id  --screen=ad  --seed=N

var demo := false
var start_wave := 1
var debug_hp := 0.0
var debug_die := 0.0
var debug_map := 0
var debug_screen := ""
var debug_nova := false
var show_cards_demo := false
var debug_ship := ""
var debug_boss := ""
var debug_give: Array = []
## 0 = rastgele. Tohumlu koşu: bkz. RunFlow.reseed (+ `--fixed-fps` ile kare-kare belirlenimli).
var run_seed := 0

func parse(args: PackedStringArray) -> void:
	demo = "--demo" in args
	for arg in args:
		if arg.begins_with("--wave="):
			start_wave = maxi(1, int(arg.get_slice("=", 1)))
		elif arg.begins_with("--hp="):
			debug_hp = float(arg.get_slice("=", 1))
		elif arg.begins_with("--die="):
			debug_die = float(arg.get_slice("=", 1))
		elif arg == "--cards":
			show_cards_demo = true
		elif arg == "--nova":
			debug_nova = true
		elif arg.begins_with("--map="):
			debug_map = maxi(0, int(arg.get_slice("=", 1)))
		elif arg.begins_with("--give="):
			debug_give = Array(arg.get_slice("=", 1).split(","))
		elif arg.begins_with("--boss="):
			debug_boss = arg.get_slice("=", 1)
		elif arg.begins_with("--ship="):
			debug_ship = arg.get_slice("=", 1)
		elif arg.begins_with("--screen="):
			debug_screen = arg.get_slice("=", 1)
		elif arg.begins_with("--seed="):
			run_seed = int(arg.get_slice("=", 1))
