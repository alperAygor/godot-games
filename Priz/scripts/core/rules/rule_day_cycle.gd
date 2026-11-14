extends PrizRule
## Gün döngüsü: seviye "day" kipine geçer, sigorta hakkı verilir, cihazların çalışma
## dilimleri katalogdan seçilir. Çalışma zamanı kuralı yoktur; tahta kipi seviyeden okur.
## params: fuse_rights (varsayılan 3).
## gen: intro_simple (bool) tanıtımda tek seçenekli dilimler.


func default_order() -> int:
	return 5


func gen_stage() -> int:
	return STAGE_PRE_PLANT


func gen_apply(ctx: PrizGenContext) -> bool:
	ctx.level.mode = PrizLevel.MODE_DAY
	ctx.level.fuse_rights = param_int("fuse_rights", 3)
	for device: PrizDevice in ctx.level.devices:
		var options: Array[int] = ctx.catalog.slice_options(device.type)
		if ctx.intro and PrizJson.get_bool(gen, "intro_simple", true):
			device.slices = options[0]
		else:
			device.slices = options[ctx.pick_index(options.size())]
	return true
