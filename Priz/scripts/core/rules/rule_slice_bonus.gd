extends PrizRule
## Güneş paneli: props[prop] taşıyan hat, params.slices dilimlerinde o kadar blok fazla taşır.
## params: prop ("solar"), slices (["noon"]).
## gen: amount [min,max]. Gizli çözümde öğlen yükü en yüksek hat seçilir.


func default_order() -> int:
	return 50


func modify_capacity(_level: PrizLevel, line: PrizLine, slice: int, capacity: int) -> int:
	if not PrizSlice.has(param_slices("slices", 1 << PrizSlice.NOON), slice):
		return capacity
	return capacity + int(line.get_prop(param_str("prop", "solar"), 0))


func gen_stage() -> int:
	return STAGE_POST_PLANT


func gen_apply(ctx: PrizGenContext) -> bool:
	var mask: int = param_slices("slices", 1 << PrizSlice.NOON)
	var loads: PackedInt32Array = ctx.planted_loads()
	var best: int = -1
	var best_load: int = -1
	for l: int in ctx.level.lines.size():
		var total: int = 0
		for s: int in PrizSlice.COUNT:
			if PrizSlice.has(mask, s):
				total += loads[l * PrizSlice.COUNT + s]
		if total > best_load:
			best_load = total
			best = l
	if best < 0 or best_load <= 0:
		return false
	ctx.level.lines[best].props[param_str("prop", "solar")] = gen_range(ctx, "amount", 1, 2)
	return true
